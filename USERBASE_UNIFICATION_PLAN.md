# Userbase unification plan (recommendation #1)

**Status:** proposal — review before any code. Touches production auth, so staged
with a dual-auth shim and per-step rollback. Pairs with `API_ARCHITECTURE.md`.

## Problem

`userbase` is implemented on **both** backends over the **same** Supabase
project (`aaxh…`), with different session transports:

- `services/skatehive-api` (`api.skatehive.app`) — **Bearer** token. Mobile client.
- `apps/skatehive3.0` (`skatehive.app`) — **`userbase_refresh` cookie**. Web client.

Most routes are **unique** to one side; only a small **core is duplicated**, and
that's where drift happens.

| Capability | api | web | Duplicated? |
|---|---|---|---|
| Session validate | `getBearerUserId` (Bearer) | `resolveSessionUserId` (cookie) | **yes (the shim target)** |
| hive vote / comment / follow | ✅ | ✅ | **yes** |
| soft-posts / soft-votes record | ✅ | ✅ | **yes** |
| email login | OTP | magic-link | parallel (keep both) |
| identities (hive/evm/farcaster), keys, sponsorships, merge, newsletter, lookup, bootstrap | — | ✅ | web-only |
| account-update, notifications, report, check-username, upload-image, profile/instagram, instagram/post | ✅ | (profile/instagram, instagram/post also on web) | api-owned now |

So unification ≠ "collapse everything." It's: **one source of truth for the
duplicated core (session + hive-broadcast + soft-posts), reachable by both
clients**, leaving the browser-specific flows (EVM/Farcaster/magic-link/keys/
sponsorships/merge) on web where they belong.

## Target

`api.skatehive.app` owns the duplicated core. A single **dual-transport auth
helper** accepts **both** `Authorization: Bearer <token>` and
`Cookie: userbase_refresh=<token>` (both hash to the same `userbase_sessions`
row — already interchangeable). Web's duplicated routes stop re-implementing the
logic and instead **forward to api** (thin proxy, carrying the cookie). No shared
npm package needed (the repos aren't a workspace) — the "shared source" is the
api runtime, reached over HTTP.

## Stages (each independently deployable + reversible)

**Stage 0 — prep (no behavior change).**
- Add `resolveUserbaseUserId(req)` to api `lib/userbase/session.ts`: try
  `Authorization: Bearer`, then `Cookie: userbase_refresh`. Same hash→session
  lookup. Wire api's existing routes to use it (they keep working for Bearer).
- Verify: existing mobile Bearer calls unaffected (401/200 as before).

**Stage 1 — api accepts the web cookie.**
- Confirm `api.skatehive.app` is reachable from the web with credentials (CORS:
  the web calls server-to-server, so no browser CORS; if any browser-direct call
  is desired later, add an allowlist for `skatehive.app`).
- Verify: a request with a valid `userbase_refresh` cookie to
  `api.skatehive.app/api/userbase/hive/vote` succeeds.

**Stage 2 — proxy the web's duplicated routes to api (one at a time).**
For `hive/vote`, then `hive/comment`, then `hive/follow`, then `soft-posts*`:
- Replace the web route body with a forward to
  `api.skatehive.app/api/userbase/hive/<x>`, passing the incoming cookie + body,
  returning the api response verbatim.
- Deploy + verify on web after **each** route. Roll back = revert that one file.
- Net: the broadcast/soft-post logic now runs in exactly one place (api).

**Stage 3 — cleanup.**
- Delete the now-dead duplicated logic from web (the inlined posting/soft-post
  code), keeping only the thin proxies (or remove the web routes entirely and
  point the web client at api directly — decide per route based on caller).
- Collapse `getBearerUserId` + `resolveSessionUserId` usages onto
  `resolveUserbaseUserId` everywhere on api.

**Out of scope (stays on web):** identities (hive/evm/farcaster challenge+verify),
keys/*, sponsorships/*, merge/*, newsletter, magic-link, bootstrap, lookup. These
are browser-flow-specific; revisit only if mobile ever needs them.

## What the ops agent needs to provide
- Confirm/keep the Meta + Supabase env already on `api.skatehive.app` (done).
- No new secrets for Stages 0–3 (same shared userbase Supabase project).
- If we ever expose api directly to the browser: a CORS allowlist for
  `https://skatehive.app` on the api project (not needed for server-to-server proxy).

## Verification per stage
- Stage 0/1: curl api `hive/vote` with (a) Bearer and (b) `Cookie: userbase_refresh=…`
  → both resolve the same user; soft-vote row written once.
- Stage 2: from the web app, vote/comment/follow as an email user → still works;
  one `userbase_soft_*` row; no double-broadcast.
- Regression: mobile vote/comment/follow unaffected (still Bearer → api).

## Risks & mitigations
- **Auth regression on web** (cookie not honored by api) → Stage 1 gate verifies
  the cookie path before any web route is proxied.
- **Double-broadcast** during cutover → proxy (not dual-write); the web route
  delegates, never broadcasts itself.
- **api downtime now affects web writes** → acceptable (web already depends on
  api for reads; and these are the same Supabase tables). Add a clear 502
  passthrough so failures are visible.
- **Firewall:** api is not bot-challenged, so proxied traffic isn't blocked
  (unlike the reverse direction).

## Effort
Stage 0–1: small (one helper + verification). Stage 2: ~4 routes × (proxy +
deploy + verify). Stage 3: cleanup. No DB migration. Each stage reversible by
reverting one file.
