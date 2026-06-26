# Userbase unification — Phase 2: cutover the duplicated write-core to api

**Status:** Approved design (2026-06-26). Ready to turn into an implementation plan.
**Depends on:** Phase 1 (done) — secrets proven identical across deployments; api proven
to resolve both the web `userbase_refresh` cookie and the mobile `Bearer` token.
Pairs with [`USERBASE_UNIFICATION_PLAN.md`](../../../USERBASE_UNIFICATION_PLAN.md),
[`API_ARCHITECTURE.md`](../../../API_ARCHITECTURE.md), and the Phase 1 docs.

## 1. Goal

Make `api.skatehive.app` the single owner of the duplicated write-core
(`hive/vote`, `hive/comment`, `hive/follow`). The web's three routes stop
re-implementing broadcast/sign/soft-record and become **thin server-side proxies**
that forward to api carrying the caller's cookie. Kills the drift; the logic runs in
exactly one place.

## 2. Scope

**In scope (the duplicated broadcast core):** `apps/skatehive3.0/app/api/userbase/hive/{vote,comment,follow}/route.ts`
become proxies; one small api edit (§5.2).

**Explicit non-goals:**
- Soft-posts / soft-votes **GET** overlays (`/api/userbase/soft-posts`, `/soft-votes`)
  stay on web — they are reads, not duplicated broadcast logic.
- `account-update`, `report` — also duplicated, but deferred to a later increment.
- `bootstrap`, identities, keys, sponsorships, merge, magic-link, newsletter, lookup —
  stay on web (browser-flow-specific).
- **No DB change. No mobile change. No web client/UI change** (the ~15 callers keep
  hitting the same relative paths).

## 3. Repos touched (authorized 2026-06-26)

- `apps/skatehive3.0` — 3 route files become proxies (+ delete their now-dead inlined logic).
- `services/skatehive-api` — 1 route file edit (comment app-tag).

Both are nested repos with their own remotes; editing them for THIS work is authorized
(overrides the general "monorepo only" scope note for this task).

## 4. Architecture — the proxy contract

Each web route handler is replaced by:

1. Read the incoming `userbase_refresh` cookie (httpOnly, attached automatically by the
   same-origin client).
2. `fetch` `https://api.skatehive.app/api/userbase/hive/<route>` with:
   - method `POST`, `Content-Type: application/json`,
   - header `Cookie: userbase_refresh=<value>` (forward only this cookie),
   - the **request body forwarded** (after the per-route body-shape check in §5).
3. Return api's response **verbatim** — same status code and JSON body (including `401`,
   `403`, `4xx`). The web route does **not** broadcast or sign anything itself.
4. If the api fetch itself fails (network/unreachable), return a clear `502` with a JSON
   `{ error: "upstream unavailable" }` so failures are visible, not silent.

No CORS needed (server-to-server). No double-broadcast (web delegates, never broadcasts).
api validates the cookie (proven in Phase 1) and owns the soft-row write.

## 5. Per-route specifics

For each route, the plan must first **diff the web route's expected request body against
api's** and, if field names differ, map them inside the proxy (keep the client contract
unchanged). Known specifics:

### 5.1 vote
Simplest: body is `{ author, permlink, weight }`, no metadata. Proxy forwards as-is.
api records the `userbase_soft_votes` row when using the default account.

### 5.2 comment  (+ the one api edit)
- The web client sends `json_metadata` (carrying the web app tag). api's comment route
  currently **hardcodes** `app: "skatehive-mobile"`
  ([api comment route:43](../../../services/skatehive-api/src/app/api/userbase/hive/comment/route.ts)),
  which would mislabel web comments after cutover.
- **api edit:** change line 43 from `app: "skatehive-mobile"` to
  `app: (typeof body?.json_metadata?.app === "string" ? body.json_metadata.app : "skatehive-mobile")`
  — respect an incoming app tag, default to mobile when absent. This keeps mobile behavior
  identical and lets the web proxy pass `app: "<web tag>"` through `json_metadata`.
- The proxy forwards the web client's body (incl. `json_metadata` with the web app tag).
  Confirm the web client already sets its app tag; if not, the proxy sets it.

### 5.3 follow
Custom-json `follow` (no app-tag issue). api **403s** when the signer is the default
account ("requires your own Hive account"); the proxy must pass that 403 through so the
web UX is unchanged.

## 6. Staging (one route at a time, each independently deployable + reversible)

`vote` → deploy web → verify in prod → `comment` (+ deploy the api edit first) → deploy
web → verify → `follow` → deploy web → verify. Then **cleanup**: delete the dead inlined
broadcast/decrypt/soft-record code inside the 3 web routes, keeping only the thin proxy.

Order rationale: `vote` first (least harmful if wrong, simplest body); `comment` needs
the api edit deployed **before** the web comment proxy; `follow` last (has the 403 guard
to verify).

**Rollback:** revert the single changed route file (web) — instant. The api comment edit
is backward-compatible (defaults to the old `skatehive-mobile` when no tag), so it can
ship independently and stay.

## 7. Verification per route (production)

As an **email/cookie user on web** (the proxied path):
- action succeeds; the post/vote/follow lands on Hive once;
- exactly **one** `userbase_soft_post`/`_vote` row (no duplicate, no double-broadcast);
- for `comment`: the on-chain `json_metadata.app` is the **web** tag, not `skatehive-mobile`;
- for `follow`: a default-account (no own key) user still gets the **403** (guard intact).

Regression (must stay green):
- **Mobile** vote/comment/follow (Bearer → api directly) unaffected;
- a logged-out / no-cookie web request gets `401` passed through.

## 8. Risks & mitigations

- **api downtime now affects web writes** for these 3 actions → acceptable (web already
  depends on api for reads, same DB); surfaced as an explicit `502` so it's visible.
- **Body-shape mismatch** between web client and api route → caught by the §5 per-route
  diff before deploy; mapped in the proxy.
- **Firewall:** api is not bot-challenged, so server-to-server proxy traffic isn't blocked
  (the challenge only affects the reverse direction).
- **Double-broadcast during cutover** → impossible by construction: the proxy delegates and
  the web route's own broadcast path is removed in the same change.

## 9. Out-of-scope follow-ups (track for later)
- Proxy/port `account-update` + `report` the same way.
- Standardize the soft-vote lifecycle (web's `queued→broadcasted` vs api's direct
  `broadcasted`) — once web no longer writes them, api's is the only one, so this resolves
  naturally after cutover.
- Decide `bootstrap`'s long-term home (mobile depends on the web one).
