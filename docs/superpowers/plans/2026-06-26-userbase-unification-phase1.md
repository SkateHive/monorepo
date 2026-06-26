# Userbase Unification — Phase 1 (Safety Net + Proof) Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build a reversible backup of the `userbase` database and prove two facts — that the encryption/posting secrets are identical across both deployments, and that the api resolves a web `userbase_refresh` cookie — without changing anything in production.

**Architecture:** This is an **operational** plan, not a code feature. Three independent, non-destructive tasks: (A) local `pg_dump` backup, (B) verify shared secrets via fingerprint compare + a functional decrypt-only test, (C) prove cookie auth on a live api read endpoint using a disposable test user. No api/web source is modified; no schema migration.

**Tech Stack:** `pg_dump`/`psql` 17.5, `curl`, Node 18+ (built-in `crypto` only — no npm deps), `vercel` CLI, Supabase Postgres.

**Spec:** [`docs/superpowers/specs/2026-06-26-userbase-unification-phase1-design.md`](../specs/2026-06-26-userbase-unification-phase1-design.md)

## Global Constraints

- **No production change.** Do not modify any source in `services/skatehive-api` or `apps/skatehive3.0`. No schema migration. No route edits.
- **Secrets never printed.** Only `sha256` fingerprints or plaintext *lengths* may be shown. Never echo a secret value or a decrypted key.
- **Backups and pulled env files are NEVER committed.** They live under `~/skatehive-backups/` (backups) and `scripts/userbase-phase1/.env-*` (env pulls), both outside git or gitignored.
- **All helper scripts live in the monorepo** at `scripts/userbase-phase1/` — not inside the nested `skatehive-api` / `skatehive3.0` repos.
- **Token hashing is `sha256(token)` with no salt** ([api session.ts:12], [web session route:47]) — both transports hash to the same `userbase_sessions.refresh_token_hash`.
- **Posting-key encryption:** `aes-256-gcm` with key = `scrypt(USERBASE_KEY_ENCRYPTION_SECRET, salt, 32)`. Per-user salt = `skatehive-hive-key-<userId>`; legacy salt = `skatehive-userbase`. `iv` / `authTag` / ciphertext are base64.
- **Disposable test rows** are marked `display_name = 'ZZZ_TEST_PHASE1_DELETE_ME'` and deleted in the same run.
- **⚠️ ACCESS steps** (marked below) require the operator's credentials: the web `.env.local` (`DATABASE_URL`), `vercel` login + project links, and the api deployment's `USERBASE_KEY_ENCRYPTION_SECRET`. The agent prepares the commands; the operator runs or authorizes those steps.

---

## Task 1: Local backup (the parachute)

**Files:**
- Create: `scripts/userbase-phase1/backup-userbase.sh`
- Output (uncommitted): `~/skatehive-backups/userbase_full_<UTC>.sql`, `~/skatehive-backups/userbase_manifest_<UTC>.txt`

**Interfaces:**
- Consumes: `DATABASE_URL` from `apps/skatehive3.0/.env.local`.
- Produces: a restorable `.sql` dump + a per-table row-count manifest. No later task depends on its output (it's the safety net for a *future* cutover).

- [ ] **Step 1: Create the backup script**

Create `scripts/userbase-phase1/backup-userbase.sh`:

```bash
#!/usr/bin/env bash
set -euo pipefail
# Stage A — local, restorable backup of the userbase tables.
# Reads DATABASE_URL from the web app's .env.local; never prints it.

ENV_FILE="${ENV_FILE:-$HOME/Code/skatehive/monorepo/apps/skatehive3.0/.env.local}"
OUT_DIR="${OUT_DIR:-$HOME/skatehive-backups}"
TABLES=(userbase_users userbase_auth_methods userbase_sessions userbase_identities \
  userbase_identity_challenges userbase_magic_links userbase_email_otps \
  userbase_hive_keys userbase_soft_posts userbase_soft_votes \
  userbase_sponsorships userbase_instagram_posts spotmap_spots)

DATABASE_URL="$(grep -E '^DATABASE_URL=' "$ENV_FILE" | head -1 | cut -d= -f2- | tr -d '"')"
[ -n "$DATABASE_URL" ] || { echo "DATABASE_URL not found in $ENV_FILE" >&2; exit 1; }

mkdir -p "$OUT_DIR"
TS="$(date -u +%Y%m%dT%H%M%SZ)"
DUMP="$OUT_DIR/userbase_full_${TS}.sql"
MANIFEST="$OUT_DIR/userbase_manifest_${TS}.txt"

args=(); for t in "${TABLES[@]}"; do args+=(--table="public.$t"); done
pg_dump "$DATABASE_URL" --no-owner --no-privileges --format=plain "${args[@]}" --file="$DUMP"

{ echo "Backup file : $DUMP"; echo "Taken (UTC) : $TS"; echo "--- exact row counts ---";
  for t in "${TABLES[@]}"; do
    c="$(psql "$DATABASE_URL" -At -c "SELECT count(*) FROM public.$t;" 2>/dev/null || echo ERR)"
    printf "%-34s %s\n" "$t" "$c"
  done; } | tee "$MANIFEST"

echo "Dump size       : $(du -h "$DUMP" | cut -f1)"
echo "COPY/INSERT rows : $(grep -cE '^(INSERT INTO|COPY )' "$DUMP" || true)"
```

- [ ] **Step 2: Make it executable and commit the script (not the output)**

```bash
cd ~/Code/skatehive/monorepo
chmod +x scripts/userbase-phase1/backup-userbase.sh
printf '%s\n' '/skatehive-backups/' >> .gitignore   # belt-and-suspenders; output is in $HOME anyway
git add scripts/userbase-phase1/backup-userbase.sh
git commit -m "chore(userbase-p1): add local backup script (Stage A)"
```

- [ ] **Step 3: ⚠️ ACCESS — run the backup**

```bash
~/Code/skatehive/monorepo/scripts/userbase-phase1/backup-userbase.sh
```
Expected: a manifest printed with non-zero counts for `userbase_users` and `userbase_sessions`, a `Dump size` in KB–MB, and a `COPY/INSERT rows` total roughly equal to the sum of the manifest counts.

- [ ] **Step 4: Verify the backup is real and complete**

```bash
ls -lh ~/skatehive-backups/
head -40 ~/skatehive-backups/userbase_full_*.sql | grep -E "CREATE TABLE|COPY public.userbase_users"
```
Expected: the dump exists, is non-empty, and contains `CREATE TABLE`/`COPY` statements for the userbase tables. **Do not commit these files.** If the dump is empty or `pg_dump` errored on a server-version mismatch, fall back to `supabase db dump --db-url "$DATABASE_URL" -f ~/skatehive-backups/userbase_full_<UTC>.sql` and re-verify.

---

## Task 2: Verify the master secrets match (the risk)

**Files:**
- Create: `scripts/userbase-phase1/fingerprint-secrets.sh`
- Create: `scripts/userbase-phase1/verify-decrypt.mjs`
- Input (uncommitted): `scripts/userbase-phase1/.env-api`, `scripts/userbase-phase1/.env-web` (from `vercel env pull`)

**Interfaces:**
- Consumes: the **deployed** env of both Vercel projects; `DATABASE_URL` (to read one ciphertext row).
- Produces: a yes/no on "secrets identical" — the gate that decides whether a cutover is even plannable.

- [ ] **Step 1: ⚠️ ACCESS — pull the deployed env for both projects**

Local `.env.local` can disagree with production, so pull the live values. These files are secret — keep them in `scripts/userbase-phase1/` and gitignore them.

```bash
cd ~/Code/skatehive/monorepo
printf '%s\n' 'scripts/userbase-phase1/.env-*' >> .gitignore
( cd services/skatehive-api && vercel env pull ../../scripts/userbase-phase1/.env-api --environment=production )
( cd apps/skatehive3.0     && vercel env pull ../../scripts/userbase-phase1/.env-web --environment=production )
```
Expected: two files written. (If a project isn't linked yet, run `vercel link` in that directory first.)

- [ ] **Step 2: Create the fingerprint compare script**

Create `scripts/userbase-phase1/fingerprint-secrets.sh`:

```bash
#!/usr/bin/env bash
set -euo pipefail
# Stage B-1 — compare secret FINGERPRINTS across two env files. Prints sha256 only, never values.
# Usage: fingerprint-secrets.sh <env_api> <env_web>
API_ENV="$1"; WEB_ENV="$2"
VARS=(USERBASE_KEY_ENCRYPTION_SECRET DEFAULT_HIVE_POSTING_ACCOUNT DEFAULT_HIVE_POSTING_KEY)
getval(){ grep -E "^$2=" "$1" | head -1 | cut -d= -f2- | tr -d '"'; }
fp(){ local v="$1"; [ -z "$v" ] && { echo "(missing)"; return; }; printf '%s' "$v" | shasum -a 256 | cut -c1-12; }
printf "%-34s %-14s %-14s %s\n" "VAR" "API" "WEB" "MATCH"
allmatch=1
for v in "${VARS[@]}"; do
  fa="$(fp "$(getval "$API_ENV" "$v")")"; fw="$(fp "$(getval "$WEB_ENV" "$v")")"
  m="NO"; [ "$fa" = "$fw" ] && [ "$fa" != "(missing)" ] && m="YES" || allmatch=0
  printf "%-34s %-14s %-14s %s\n" "$v" "$fa" "$fw" "$m"
done
# Same Supabase DB? compare the project host of each side's Supabase URL.
host(){ grep -E "^($2)=" "$1" | head -1 | cut -d= -f2- | tr -d '"' | sed -E 's#https?://##; s#/.*##'; }
ha="$(host "$API_ENV" 'SUPABASE_USERBASE_URL|SUPABASE_URL')"; hw="$(host "$WEB_ENV" 'SUPABASE_URL|NEXT_PUBLIC_SUPABASE_URL')"
echo "---"; echo "Supabase host  api=$ha  web=$hw  MATCH=$([ "$ha" = "$hw" ] && echo YES || echo NO)"
[ "$allmatch" = 1 ] && [ "$ha" = "$hw" ] && echo "RESULT: secrets+DB MATCH" || { echo "RESULT: MISMATCH — STOP, do not plan a cutover"; exit 2; }
```

- [ ] **Step 3: Run the fingerprint compare**

```bash
cd ~/Code/skatehive/monorepo
chmod +x scripts/userbase-phase1/fingerprint-secrets.sh
scripts/userbase-phase1/fingerprint-secrets.sh scripts/userbase-phase1/.env-api scripts/userbase-phase1/.env-web
```
Expected: every row shows `MATCH = YES`, the Supabase host matches, and the final line is `RESULT: secrets+DB MATCH`. If any row is `NO`, **STOP** — record which var differs in the findings note and do not proceed to a cutover plan.

- [ ] **Step 4: Create the functional decrypt-only test**

Create `scripts/userbase-phase1/verify-decrypt.mjs` (built-in `crypto` only; never prints the key):

```javascript
import crypto from "node:crypto";
import { execSync } from "node:child_process";

const dbUrl = process.env.DATABASE_URL;
const secret = process.env.USERBASE_KEY_ENCRYPTION_SECRET;
if (!dbUrl || !secret) {
  console.error("Need DATABASE_URL and USERBASE_KEY_ENCRYPTION_SECRET in env"); process.exit(1);
}
// Pull ONE key row. All fields are ciphertext/metadata — no plaintext leaves the DB.
const sql =
  "SELECT user_id||'|'||encrypted_posting_key||'|'||encryption_iv||'|'||encryption_auth_tag " +
  "FROM public.userbase_hive_keys LIMIT 1;";
const row = execSync(`psql "${dbUrl}" -At -c "${sql}"`, { encoding: "utf8" }).trim();
if (!row) { console.log("No userbase_hive_keys rows yet — nothing to decrypt (acceptable)."); process.exit(0); }

const [userId, enc, iv, tag] = row.split("|");
function tryDecrypt(salt) {
  const key = crypto.scryptSync(secret, salt, 32);
  const d = crypto.createDecipheriv("aes-256-gcm", key, Buffer.from(iv, "base64"));
  d.setAuthTag(Buffer.from(tag, "base64"));
  return Buffer.concat([d.update(Buffer.from(enc, "base64")), d.final()]).toString("utf8");
}
let out;
for (const salt of [`skatehive-hive-key-${userId}`, "skatehive-userbase"]) {
  try { out = tryDecrypt(salt); break; } catch { /* try next salt */ }
}
if (out) {
  console.log(`DECRYPT OK for user ${userId.slice(0,8)}… (plaintext length ${out.length})`);
  console.log("=> The API secret matches the secret that ENCRYPTED this stored key.");
} else {
  console.error("DECRYPT FAILED with both salts.");
  console.error("=> API USERBASE_KEY_ENCRYPTION_SECRET does NOT match. STOP — do not plan a cutover.");
  process.exit(2);
}
```

- [ ] **Step 5: ⚠️ ACCESS — run the decrypt test with the API's secret**

Feed the **api** deployment's secret (from `.env-api`) plus `DATABASE_URL`:

```bash
cd ~/Code/skatehive/monorepo
DATABASE_URL="$(grep -E '^DATABASE_URL=' apps/skatehive3.0/.env.local | head -1 | cut -d= -f2- | tr -d '"')" \
USERBASE_KEY_ENCRYPTION_SECRET="$(grep -E '^USERBASE_KEY_ENCRYPTION_SECRET=' scripts/userbase-phase1/.env-api | head -1 | cut -d= -f2- | tr -d '"')" \
node scripts/userbase-phase1/verify-decrypt.mjs
```
Expected: `DECRYPT OK …` and the match confirmation. (If there are no key rows yet, the "nothing to decrypt" message is an acceptable pass — the fingerprint compare in Step 3 already covers the secret equality.)

- [ ] **Step 6: Commit the scripts (not the env files)**

```bash
cd ~/Code/skatehive/monorepo
git status --short scripts/userbase-phase1/   # confirm .env-api/.env-web are NOT listed
git add scripts/userbase-phase1/fingerprint-secrets.sh scripts/userbase-phase1/verify-decrypt.mjs .gitignore
git commit -m "chore(userbase-p1): add secret fingerprint + decrypt verification (Stage B)"
```
Expected: only the two scripts and `.gitignore` are committed; `.env-api`/`.env-web` are ignored.

---

## Task 3: Prove api accepts the web cookie (the bridge)

**Files:**
- Create: `scripts/userbase-phase1/stage-c-cookie-test.sh`

**Interfaces:**
- Consumes: `DATABASE_URL` (to insert/delete the disposable rows); the live `https://api.skatehive.app`.
- Produces: yes/no on "api resolves **both** a `userbase_refresh` cookie (web) **and** an `Authorization: Bearer` token (mobile) to the same user." This is the final fact the findings note needs, and the mobile regression check.

- [ ] **Step 1: Create the cookie + bearer test script**

`GET /api/userbase/profile/instagram` uses `resolveUserbaseUserId` (dual transport). The same disposable token must resolve via **the cookie (web)** and via **`Authorization: Bearer` (mobile)** — both hash to the same `userbase_sessions` row — while a request with **neither** must be 401. Create `scripts/userbase-phase1/stage-c-cookie-test.sh`:

```bash
#!/usr/bin/env bash
set -euo pipefail
# Stage C — prove api resolves a userbase_refresh COOKIE. Inserts a disposable
# user+session, hits a read endpoint with the cookie, then deletes the rows.
API_BASE="${API_BASE:-https://api.skatehive.app}"
ENDPOINT="/api/userbase/profile/instagram"
ENV_FILE="${ENV_FILE:-$HOME/Code/skatehive/monorepo/apps/skatehive3.0/.env.local}"
DATABASE_URL="$(grep -E '^DATABASE_URL=' "$ENV_FILE" | head -1 | cut -d= -f2- | tr -d '"')"
[ -n "$DATABASE_URL" ] || { echo "no DATABASE_URL" >&2; exit 1; }

TOKEN="phase1-test-$(uuidgen)"
TOKEN_HASH="$(printf '%s' "$TOKEN" | shasum -a 256 | cut -d' ' -f1)"
MARK="ZZZ_TEST_PHASE1_DELETE_ME"

cleanup(){ psql "$DATABASE_URL" -At -c \
  "DELETE FROM public.userbase_sessions WHERE refresh_token_hash='$TOKEN_HASH';
   DELETE FROM public.userbase_users WHERE display_name='$MARK';" >/dev/null 2>&1 || true; }
trap cleanup EXIT

USER_ID="$(psql "$DATABASE_URL" -At <<SQL
WITH u AS (INSERT INTO public.userbase_users (display_name, status)
           VALUES ('$MARK','active') RETURNING id)
INSERT INTO public.userbase_sessions (user_id, refresh_token_hash, expires_at)
SELECT id, '$TOKEN_HASH', now() + interval '1 day' FROM u
RETURNING user_id;
SQL
)"
[ -n "$USER_ID" ] || { echo "insert failed (see RLS note in plan)" >&2; exit 1; }
echo "inserted disposable user: $USER_ID"

echo "--- control: NO cookie (expect 401) ---"
curl -s -o /dev/null -w "HTTP %{http_code}\n" "$API_BASE$ENDPOINT"

echo "--- WEB transport: userbase_refresh cookie (expect NOT 401) ---"
ccode="$(curl -s -o /tmp/p1_resp_c.json -w "%{http_code}" -H "Cookie: userbase_refresh=$TOKEN" "$API_BASE$ENDPOINT")"
echo "HTTP $ccode"; echo "body: $(cat /tmp/p1_resp_c.json)"

echo "--- MOBILE transport: Authorization: Bearer (expect NOT 401, same user) ---"
bcode="$(curl -s -o /tmp/p1_resp_b.json -w "%{http_code}" -H "Authorization: Bearer $TOKEN" "$API_BASE$ENDPOINT")"
echo "HTTP $bcode"; echo "body: $(cat /tmp/p1_resp_b.json)"

echo "--- result ---"
[ "$ccode" != "401" ] && [ "$bcode" != "401" ] \
  && echo "PASS: both web cookie and mobile Bearer resolve the same session" \
  || echo "CHECK: one transport returned 401 — investigate before any cutover"
# cleanup runs on EXIT; confirm the rows are gone next
```

- [ ] **Step 2: ⚠️ ACCESS — run the cookie test**

```bash
cd ~/Code/skatehive/monorepo
chmod +x scripts/userbase-phase1/stage-c-cookie-test.sh
scripts/userbase-phase1/stage-c-cookie-test.sh
```
Expected: control (no auth) → `HTTP 401`; **both** the cookie request and the Bearer request → **not 401** (a `200`, or a post-auth business error like a "no linked hive account" 400 — both prove auth resolved), ending in `PASS: both web cookie and mobile Bearer resolve the same session`. If the `psql` insert is rejected by `FORCE ROW LEVEL SECURITY`, use the service-role REST fallback in Step 3 instead, then re-run.

- [ ] **Step 3: (Only if Step 2's insert was RLS-blocked) service-role REST fallback**

Insert/delete via PostgREST with the service-role key (bypasses RLS the same way the app does). Pull `SUPABASE_URL` + `SUPABASE_SERVICE_ROLE_KEY` from `scripts/userbase-phase1/.env-api`, then:

```bash
SB_URL="$(grep -E '^SUPABASE_USERBASE_URL=|^SUPABASE_URL=' scripts/userbase-phase1/.env-api | head -1 | cut -d= -f2- | tr -d '"')"
SRK="$(grep -E '^SUPABASE_SERVICE_ROLE_KEY=' scripts/userbase-phase1/.env-api | head -1 | cut -d= -f2- | tr -d '"')"
# create user
UID_JSON=$(curl -s -X POST "$SB_URL/rest/v1/userbase_users" -H "apikey: $SRK" -H "Authorization: Bearer $SRK" \
  -H "Content-Type: application/json" -H "Prefer: return=representation" \
  -d '{"display_name":"ZZZ_TEST_PHASE1_DELETE_ME","status":"active"}')
echo "$UID_JSON"   # grab "id"
# then POST a userbase_sessions row with {user_id, refresh_token_hash, expires_at}, run the curl test,
# then DELETE both rows: curl -X DELETE "$SB_URL/rest/v1/userbase_users?display_name=eq.ZZZ_TEST_PHASE1_DELETE_ME" -H "apikey:$SRK" -H "Authorization: Bearer $SRK"
```
Expected: same pass criteria as Step 2. Always finish by deleting the `ZZZ_TEST_PHASE1_DELETE_ME` rows.

- [ ] **Step 4: Confirm no test rows remain, then commit the script**

```bash
cd ~/Code/skatehive/monorepo
DATABASE_URL="$(grep -E '^DATABASE_URL=' apps/skatehive3.0/.env.local | head -1 | cut -d= -f2- | tr -d '"')"
psql "$DATABASE_URL" -At -c "SELECT count(*) FROM public.userbase_users WHERE display_name='ZZZ_TEST_PHASE1_DELETE_ME';"
# Expected: 0
git add scripts/userbase-phase1/stage-c-cookie-test.sh
git commit -m "chore(userbase-p1): add cookie-resolution proof on api (Stage C)"
```
Expected: count is `0`; the script is committed.

---

## Task 4: Findings note (the deliverable)

**Files:**
- Create: `docs/userbase-phase1-findings.md`

- [ ] **Step 1: Write the findings note**

Record the three facts so the cutover phase can be decided:

```markdown
# Userbase Phase 1 — findings (<UTC date>)

- **Backup:** `~/skatehive-backups/userbase_full_<UTC>.sql` — row counts: <paste manifest>.
- **Secrets match across deployments:** YES / NO  (vars checked: USERBASE_KEY_ENCRYPTION_SECRET,
  DEFAULT_HIVE_POSTING_ACCOUNT, DEFAULT_HIVE_POSTING_KEY; Supabase host match: YES/NO).
- **Functional decrypt on api:** OK / FAILED / no-rows.
- **api resolves both transports:** web cookie = YES/NO, mobile Bearer = YES/NO (control with neither = 401). Mobile regression: Bearer path unaffected.
- **Decision:** proceed to cutover planning? YES/NO + any blockers.
```

- [ ] **Step 2: Commit the findings**

```bash
cd ~/Code/skatehive/monorepo
git add docs/userbase-phase1-findings.md
git commit -m "docs(userbase-p1): record Phase 1 findings"
```

---

## Self-review

- **Spec coverage:** Stage A → Task 1; Stage B (fingerprint + functional decrypt) → Task 2; Stage C (disposable test user, read endpoint, cleanup) → Task 3; deliverable findings note → Task 4. All spec sections covered.
- **Placeholders:** none — every script is complete. The REST fallback (Task 3 Step 3) intentionally abbreviates the session-insert/delete as inline comments because it is a contingency only used if `psql` is RLS-blocked.
- **Type/name consistency:** `userbase_refresh` cookie, `refresh_token_hash = sha256(token)`, salts `skatehive-hive-key-<userId>` / `skatehive-userbase`, and endpoint `/api/userbase/profile/instagram` are used identically across tasks and match the codebase.
- **Non-destructive check:** Tasks 1–2 are read-only; Task 3 adds exactly one user+session row marked `ZZZ_TEST_PHASE1_DELETE_ME` and deletes them via an `EXIT` trap. No api/web source changes.
