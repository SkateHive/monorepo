# Userbase unification — Phase 1: safety net + proof

**Status:** Approved design (2026-06-26). Ready to turn into an implementation plan.
**Scope owner:** this is the cautious first phase of `USERBASE_UNIFICATION_PLAN.md`
recommendation #1. It changes **nothing** in production — it only builds a backup,
verifies one risky assumption, and proves one capability. We regroup before any cutover.

Pairs with: [`API_ARCHITECTURE.md`](../../../API_ARCHITECTURE.md) ·
[`USERBASE_UNIFICATION_PLAN.md`](../../../USERBASE_UNIFICATION_PLAN.md)

---

## 1. Problem (one paragraph)

`userbase` is one shared Supabase database written to by **two** backends:
`api.skatehive.app` (`services/skatehive-api`, mobile, **Bearer** token) and
`skatehive.app` (`apps/skatehive3.0`, web, **`userbase_refresh` cookie**). The shared
DB is fine; the problem is that the **duplicated core** — session validation, hive
broadcast, soft-post/vote writes — exists as **parallel code** in both repos and has
drifted. The endgame is to make api the single owner and have web call it. Before any of
that, we need a reversible safety net and proof that two assumptions hold.

## 2. Scope of THIS phase

**In scope (all non-destructive):**
- **Stage A** — local `pg_dump` backup of all `userbase_*` + `spotmap_spots` tables.
- **Stage B** — verify the encryption/posting secrets are identical across both
  deployments (the one risk that could break real posting).
- **Stage C** — prove api resolves a web-style `userbase_refresh` **cookie** to the
  correct user, read-only.

**Explicit non-goals (deferred to a later phase):**
- No web route is changed or proxied to api.
- No duplicated web code is deleted.
- No schema migration. No change to mobile or web behavior.
- The soft-vote status drift (`queued→broadcasted` on web vs direct `broadcasted` on
  api) is **noted, not fixed**, this phase.

## 3. Findings the plan relies on (from code study, 2026-06-26)

These are verified facts, with sources:

1. **Session token hashing is identical on both sides** — plain `sha256(token)`, no salt,
   looked up against `userbase_sessions.refresh_token_hash`.
   - api: `services/skatehive-api/src/lib/userbase/session.ts:12` (`hashToken`), used by
     `userIdForToken` (`:54`), `getBearerUserId` (`:69`), `resolveUserbaseUserId` (`:80`).
   - web: `apps/skatehive3.0/app/api/userbase/auth/session/route.ts:47` (`hashToken`),
     replicated in `hive/vote/route.ts:23`, `hive/comment/route.ts:24`, etc.
   - **Consequence:** a session row created by either server is resolvable by the other.
     No forced re-login is needed to unify.
2. **api already has a dual-transport resolver** — `resolveUserbaseUserId(req)` tries
   `Authorization: Bearer`, then the `userbase_refresh` cookie
   (`services/skatehive-api/src/lib/userbase/session.ts:80`, cookie read at `:47`).
   Stage 0 of the old plan is effectively already implemented.
3. **api CORS is permissive** — `Access-Control-Allow-Origin: *` on `/api/*`
   (`services/skatehive-api/next.config.ts:10`). The intended web→api calls are
   server-to-server anyway, so browser CORS is not a blocker.
4. **THE RISK — posting depends on shared secrets being identical across deployments:**
   - Per-user posting keys are AES-256-GCM encrypted with a scrypt key derived from
     `USERBASE_KEY_ENCRYPTION_SECRET` + per-user salt `skatehive-hive-key-<userId>`
     (api `src/lib/userbase/encryption.ts`; web `app/api/userbase/.../encryption` with
     the same salts `skatehive-userbase` / `skatehive-hive-key-<userId>`).
   - Lite accounts fall back to `DEFAULT_HIVE_POSTING_ACCOUNT` / `DEFAULT_HIVE_POSTING_KEY`
     (api `src/lib/userbase/posting.ts:resolveSigner`; web `hive/vote` + `hive/comment`).
   - **If `USERBASE_KEY_ENCRYPTION_SECRET` or the default posting key differ between the
     two deployments, api decrypting a key that web stored (or vice-versa) FAILS.** This
     must be proven equal before any cutover is even planned.
5. **Behavioral drift to standardize later (not now):**
   - Soft-vote lifecycle: web inserts `status:"queued"` then updates to `broadcasted`
     (`hive/vote/route.ts:322`); api writes `status:"broadcasted"` directly
     (`src/lib/userbase/posting.ts:recordSoftVote`, upsert on
     `user_id,author,permlink`).
   - Lite-account guardrails match on both: `follow`, `account-update`, `report` return
     **403** when using the default account; only `vote`/`comment` are allowed for lite.
6. **Mobile depends on web's bootstrap** — `apps/skatehive3.0/app/api/userbase/auth/bootstrap/route.ts`
   returns the `refresh_token` in JSON when `x-client: mobile` / `return_token=true`.
   This is web-only-owned today and is **out of scope** this phase, but flagged for the
   cutover phase.
7. **Backup is feasible locally** — `DATABASE_URL` exists in
   `apps/skatehive3.0/.env.local`; `pg_dump`/`psql` 17.5 and the `supabase` CLI 2.33.9 are
   installed; `pg` 8.14.1 is a dependency; an existing
   `apps/skatehive3.0/scripts/database/snapshot-userbase.js` already connects with it.

## 4. Decisions

- **Backup location:** `~/skatehive-backups/` — outside the repo, never committed
  (contains real emails, sessions, encrypted keys).
- **Stage C test identity:** a **disposable test user + session row**, deleted after the
  test, so no real account is touched.
- **Secret verification:** do **both** a deployed-env fingerprint compare *and* a
  functional decrypt-only test (belt and suspenders).

## 5. The three stages

### Stage A — Local backup (the parachute)
**Goal:** a complete, restorable local copy of the userbase data.

Steps:
1. Read `DATABASE_URL` from `apps/skatehive3.0/.env.local` (do not print it).
2. `mkdir -p ~/skatehive-backups`.
3. `pg_dump "$DATABASE_URL" --no-owner --no-privileges --format=plain
   --table='public.userbase_*' --table='public.spotmap_spots'
   --file=~/skatehive-backups/userbase_full_<UTC-timestamp>.sql`
   (timestamp passed in, since scripts can't call `Date.now()`).
4. Write a manifest: `SELECT count(*)` per table → `…_manifest.txt`.

**Proof / exit:** dump file exists with sensible size; the `INSERT`/`COPY` row counts
match the live `count(*)` manifest for every table.

**Gotchas:** client `pg_dump` 17.5 vs the Supabase server version — `--no-owner
--no-privileges` plain format is robust across minor version gaps; if a hard version
error appears, fall back to the `supabase` CLI or a `pg`-based JSON export. Encrypted key
columns dump as opaque text (expected). The dump is sensitive — store with care, delete
when this phase closes.

**ELI15:** Photocopy every page in the filing cabinet, lock the copy in a drawer at home,
and write down how many pages each folder had so we can prove nothing's missing.

### Stage B — Verify the master secrets match (the risk)
**Goal:** prove both deployments share identical encryption + default-posting secrets and
point at the same DB — without exposing the secrets.

Steps:
1. Pull the **deployed** env for each Vercel project (`vercel env pull` for the api
   project and the web project) — local `.env.local` may not match production.
2. For each of `USERBASE_KEY_ENCRYPTION_SECRET`, `DEFAULT_HIVE_POSTING_ACCOUNT`,
   `DEFAULT_HIVE_POSTING_KEY`, and the resolved Supabase project host, compute
   `sha256(value)` on each side and compare **fingerprints only**.
3. Functional check: run a tiny **decrypt-only** routine on the api side against one real
   `userbase_hive_keys` row (no broadcast, no write) and confirm it returns a plausible
   WIF-shaped string.

**Proof / exit:** all fingerprints equal across deployments **and** the real key decrypts
on api. If any differ → **STOP**; document the mismatch and do not plan a cutover until
resolved.

**ELI15:** Both desks have a master key to people's lockboxes. Compare the keys'
fingerprints (never show the actual keys), then actually open one box to be sure the
fingerprints weren't lying.

### Stage C — Prove api accepts the web cookie (the bridge)
**Goal:** confirm api resolves a `userbase_refresh` cookie to the right user, read-only.

Steps:
1. Insert a disposable `userbase_users` row + a `userbase_sessions` row with a known raw
   token (store only its `sha256` hash, 30-day expiry, `revoked_at` null).
2. Call an api **read** endpoint (one that uses `resolveUserbaseUserId`) sending
   `Cookie: userbase_refresh=<raw token>` and **no** Bearer header.
3. Confirm it resolves to the disposable user's id.
4. Delete the disposable session + user rows.

**Proof / exit:** the cookie-only request returns the test user's identity; cleanup leaves
no trace (re-query returns nothing).

**ELI15:** Walk up to the api desk holding the web library card and ask only to read your
own file. If it knows who you are, the bridge works. We used a fake guest pass so no real
person was involved.

## 6. Safety & rollback

Nothing in production changes. Stage A is a read-only dump; Stage B is a read-only compare
plus a decrypt that neither writes nor broadcasts; Stage C adds exactly one user+session
row and deletes them. Rollback for Stage C = delete the temp rows (and they carry a clear
test marker in `display_name`). The Stage A backup is the parachute for the *later*
cutover phase, not for this phase.

## 7. Deliverable

A short findings note (committed under `docs/`), recording:
- backup file path + per-table row counts,
- "secrets match across deployments: yes/no" (+ which, if any, differ),
- "api resolves the web cookie: yes/no".

That note is the input to deciding the cutover phase (proxying web's
`hive/vote|comment|follow` + `soft-posts*` to api, then deleting the dead web code).

## 8. Open questions for the cutover phase (not this phase)

- Where does `bootstrap` live after unification (mobile depends on the web one)?
- Standardize the soft-vote `queued→broadcasted` lifecycle on one implementation.
- Proxy vs. point-web-client-directly-at-api, decided per route by caller.
