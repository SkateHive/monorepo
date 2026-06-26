# Userbase Unification — Phase 1 findings (2026-06-26)

Non-destructive "safety net + proof" phase. Nothing in production was changed.
Plan: [`docs/superpowers/plans/2026-06-26-userbase-unification-phase1.md`](superpowers/plans/2026-06-26-userbase-unification-phase1.md) ·
Spec: [`docs/superpowers/specs/2026-06-26-userbase-unification-phase1-design.md`](superpowers/specs/2026-06-26-userbase-unification-phase1-design.md)

## Result: ✅ all checks passed — clear to plan the cutover

### Stage A — Backup (the parachute)
- File: `~/skatehive-backups/userbase_full_20260626T164605Z.sql` (2.2 MB, **uncommitted**, contains PII + ciphertext).
- 13 `CREATE TABLE` + 13 `COPY` blocks; `userbase_users` COPY block verified at exactly 2019 rows (matches manifest).
- Row counts: users 2019 · auth_methods 230 · sessions 761 · identities 2208 · identity_challenges 89 · magic_links 128 · email_otps 11 · hive_keys 222 · soft_posts 38 · soft_votes 105 · sponsorships 15 · instagram_posts 92 · spotmap_spots 598.

### Stage B — Secrets match across deployments (the risk) → **identical**
Direct byte-for-byte comparison (sha256 fingerprints; values never printed). API secrets are
**Sensitive (write-only) on Vercel** — `vercel env pull` returns them blank, so the operator
supplied the API values for comparison.

| Variable | api fp | web fp | Match |
|---|---|---|---|
| `USERBASE_KEY_ENCRYPTION_SECRET` | `bdbc47c1b461` | `bdbc47c1b461` | ✅ |
| `DEFAULT_HIVE_POSTING_ACCOUNT` (= `skateuser`) | `21ea1c7633a8` | `21ea1c7633a8` | ✅ |
| `DEFAULT_HIVE_POSTING_KEY` | `781efe2e04f4` | `781efe2e04f4` | ✅ |

- **Supabase project:** same on both sides (`db.aaxhnehcjyvtgrlnyhcp.supabase.co`). ✅
- **Functional decrypt (GCM):** a real `userbase_hive_keys` row decrypts cleanly with **both** the web
  and the API `USERBASE_KEY_ENCRYPTION_SECRET` (plaintext length 51 — a Hive WIF). GCM auth-tag
  verification means this is cryptographic proof, not a coincidence. ✅
- **Posting key provenance:** the `@skateuser` backup key derives (Hive `fromLogin`) a posting key
  whose public key **matches `@skateuser`'s on-chain posting authority**
  (`STM7NSGTddzixsFw412qK4fR8U4tBBESjFu1Kqoi6cFvqURCFudXE`), and that derived key equals the
  configured `DEFAULT_HIVE_POSTING_KEY` (fp `781efe2e04f4`) on both deployments. ✅

→ **Risk #4 (api decrypting web-stored keys / shared-key posting) is eliminated.**

### Stage C — api resolves both transports (the bridge + mobile regression) → **yes**
Disposable test user + session (marked `ZZZ_TEST_PHASE1_DELETE_ME`, auto-deleted via EXIT trap),
against the live `GET https://api.skatehive.app/api/userbase/profile/instagram` (uses
`resolveUserbaseUserId`):

| Request | Result |
|---|---|
| No auth (control) | **HTTP 401** ✅ |
| `Cookie: userbase_refresh=<token>` (web transport) | **HTTP 200**, resolved the test user ✅ |
| `Authorization: Bearer <token>` (mobile transport) | **HTTP 200**, same user ✅ |

- Cleanup verified: 0 leftover test users / sessions.
- **Mobile regression:** Bearer path resolves unchanged — mobile is unaffected by a future web→api cutover.

## Methodology notes for next time
- `vercel env pull` blanks **Sensitive** variables — fingerprint comparison from pulled files is
  invalid for those; the operator must supply the value out-of-band.
- `printf '%s'` (no trailing newline) when fingerprinting env values — piping `cut` output directly
  into `shasum` hashes a trailing `\n` and produces a false mismatch.

## Decision: **proceed to cutover planning — YES, no blockers.**
The duplicated-core unification (Phase 2) can be planned: api already accepts both transports and
the shared secrets are confirmed identical. Open items to carry into Phase 2 (from spec §8):
mobile's dependency on web `bootstrap`; standardizing the soft-vote `queued→broadcasted` lifecycle;
proxy-vs-direct per route.

## Cleanup still owed
- The Stage A dump (`~/skatehive-backups/…sql`) holds real emails + encrypted keys — keep it
  somewhere safe or delete it when this phase is closed. It is outside the repo and not committed.
