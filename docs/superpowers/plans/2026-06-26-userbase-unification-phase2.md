# Userbase Unification — Phase 2 (Cutover) Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Make `api.skatehive.app` the single owner of the duplicated write-core (`hive/vote`, `hive/comment`, `hive/follow`): the web routes become server-side proxies that forward to api carrying the user's cookie.

**Architecture:** api first gains the one capability it lacks (comment `comment_options`/beneficiaries + app-tag passthrough). Then each web route is replaced — `vote` and `comment` with a thin shared proxy helper, `follow` with a "smart proxy" that keeps the read-only toggle detection on web but delegates the broadcast to api. One route at a time, deploy + verify in prod, rollback = revert one file.

**Tech Stack:** Next.js App Router route handlers (both repos), `@hiveio/dhive`, `vercel` CLI (deploys), `psql`/`curl` (prod verification).

**Spec:** [`docs/superpowers/specs/2026-06-26-userbase-unification-phase2-design.md`](../specs/2026-06-26-userbase-unification-phase2-design.md)

## Global Constraints

- **No DB change. No mobile change. No web client/UI change.** The ~15 web client callers keep hitting the same relative paths (`/api/userbase/hive/{vote,comment,follow}`).
- **Repos (authorized 2026-06-26):** edits land in `apps/skatehive3.0` (web routes) and `services/skatehive-api` (comment route + `posting.ts`). Both are nested repos with their own remotes.
- **Proxy contract:** forward only the `userbase_refresh` cookie; return api's status + body **verbatim** (incl. 401/403/4xx); return `502 {"error":"upstream unavailable"}` if the api fetch throws. The web route never signs/broadcasts.
- **api base URL:** `https://api.skatehive.app`.
- **Backward compatibility:** the api comment change must keep mobile identical — app tag defaults to `"skatehive-mobile"` when absent; beneficiaries are optional (absent → single comment op, as today).
- **Deploys:** `vercel --prod` from each project directory (agent runs them; `vercel` is logged in as `sktbrd`). Commit to the nested repo before deploying.
- **Each route deployed + verified in prod before the next.** Rollback = revert the one changed file + redeploy.
- **Keep the infra visual in sync:** `docs/skatehive-infra.html` is updated in the final task to show the proxy flow.

---

## Task 1: API gains comment `comment_options`/beneficiaries + app-tag passthrough

**Files:**
- Modify: `services/skatehive-api/src/lib/userbase/posting.ts` (the `broadcastComment` function)
- Modify: `services/skatehive-api/src/app/api/userbase/hive/comment/route.ts`

**Interfaces:**
- Produces: `broadcastComment(signer, { …, beneficiaries?: Array<{account:string; weight:number}> })` — when `beneficiaries` is non-empty it appends a `comment_options` op; otherwise behaves exactly as before. The comment route respects an incoming `json_metadata.app`.

- [ ] **Step 1: Extend `broadcastComment` to support beneficiaries**

Replace the existing `broadcastComment` in `services/skatehive-api/src/lib/userbase/posting.ts` with:

```ts
export async function broadcastComment(
  signer: Signer,
  opts: {
    parentAuthor: string;
    parentPermlink: string;
    permlink: string;
    title: string;
    body: string;
    jsonMetadata: Record<string, unknown>;
    beneficiaries?: Array<{ account: string; weight: number }>;
  }
): Promise<void> {
  const ops: any[] = [
    [
      "comment",
      {
        parent_author: opts.parentAuthor,
        parent_permlink: opts.parentPermlink,
        author: signer.author,
        permlink: opts.permlink,
        title: opts.title,
        body: opts.body,
        json_metadata: JSON.stringify(opts.jsonMetadata),
      },
    ],
  ];
  if (opts.beneficiaries && opts.beneficiaries.length > 0) {
    ops.push([
      "comment_options",
      {
        author: signer.author,
        permlink: opts.permlink,
        max_accepted_payout: "1000000.000 HBD",
        percent_hbd: 10000,
        allow_votes: true,
        allow_curation_rewards: true,
        extensions: [
          [0, { beneficiaries: opts.beneficiaries.map((b) => ({ account: b.account, weight: b.weight })) }],
        ],
      },
    ]);
  }
  await HiveClient.broadcast.sendOperations(ops, PrivateKey.fromString(signer.key));
}
```

- [ ] **Step 2: Respect the incoming app tag + parse beneficiaries in the comment route**

In `services/skatehive-api/src/app/api/userbase/hive/comment/route.ts`, replace the `metadata` block (lines ~41-44) with:

```ts
  const incoming =
    body?.json_metadata && typeof body.json_metadata === "object"
      ? (body.json_metadata as Record<string, unknown>)
      : {};
  const metadata: Record<string, unknown> = {
    ...incoming,
    app: typeof incoming.app === "string" ? incoming.app : "skatehive-mobile",
  };
```

Then, immediately before the `broadcastComment` call, parse + validate beneficiaries (mirrors the web route's rules):

```ts
  const rawBenef = Array.isArray(body?.beneficiaries) ? body.beneficiaries : [];
  let beneficiaries: Array<{ account: string; weight: number }> = [];
  if (rawBenef.length > 0) {
    const total = rawBenef.reduce((s: number, b: any) => s + Number(b?.weight || 0), 0);
    if (total > 10000) {
      return NextResponse.json({ success: false, error: "Beneficiaries exceed 100%" }, { status: 400 });
    }
    beneficiaries = rawBenef
      .filter(
        (b: any) =>
          b?.account &&
          typeof b.account === "string" &&
          /^[a-z][a-z0-9.-]{2,15}$/.test(b.account) &&
          Number(b?.weight) > 0
      )
      .map((b: any) => ({ account: b.account, weight: Number(b.weight) }));
  }
```

- [ ] **Step 3: Pass beneficiaries into broadcast + soft-post metadata**

Update the `broadcastComment(...)` call to pass `beneficiaries`, and add them to the soft-post metadata so the overlay matches the web:

```ts
    await broadcastComment(signer, {
      parentAuthor,
      parentPermlink,
      permlink,
      title,
      body: content,
      jsonMetadata: metadata,
      beneficiaries,
    });
```
and in the `recordSoftPost(...)` metadata object add:
```ts
        beneficiaries: beneficiaries.length > 0 ? beneficiaries : undefined,
```

- [ ] **Step 4: Type-check the api project**

Run: `cd services/skatehive-api && npx tsc --noEmit`
Expected: no new type errors in `posting.ts` or `comment/route.ts`.

- [ ] **Step 5: Commit (api repo)**

```bash
cd services/skatehive-api
git add src/lib/userbase/posting.ts src/app/api/userbase/hive/comment/route.ts
git commit -m "feat(userbase): comment supports beneficiaries (comment_options) + respects incoming app tag"
```

- [ ] **Step 6: Deploy api to production**

Run: `cd services/skatehive-api && vercel --prod`
Expected: deploy succeeds; note the production URL.

- [ ] **Step 7: Verify mobile path unchanged + beneficiaries work (prod)**

Using a disposable userbase user + session (Phase 1 pattern) that has **no** stored key (lite → @skateuser), POST a comment **with** a Bearer token (mobile transport) and a `beneficiaries: [{account:"steemskate", weight:500}]` to `https://api.skatehive.app/api/userbase/hive/comment` (parent = a designated test post). Then:
- the api returns `200 {success:true, author:"skateuser", permlink:…}`;
- on-chain the new comment has a `comment_options` with that beneficiary (fetch via `HiveClient.database.call("get_content", ["skateuser", permlink])` or a Hive explorer);
- `json_metadata.app` defaults to `"skatehive-mobile"` (no app sent);
- exactly one `userbase_soft_posts` row.
Delete the disposable user afterward.

---

## Task 2: Shared proxy helper + `vote` route → proxy

**Files:**
- Create: `apps/skatehive3.0/lib/userbase/proxyToApi.ts`
- Modify: `apps/skatehive3.0/app/api/userbase/hive/vote/route.ts` (replace handler)

**Interfaces:**
- Produces: `proxyUserbaseHive(request: NextRequest, path: string, transformBody?: (body: any) => any): Promise<NextResponse>` — forwards the cookie + (optionally transformed) body to `api.skatehive.app${path}`, returns the upstream response verbatim, `502` on fetch failure.

- [ ] **Step 1: Create the proxy helper**

Create `apps/skatehive3.0/lib/userbase/proxyToApi.ts`:

```ts
import { NextRequest, NextResponse } from "next/server";

const API_BASE = "https://api.skatehive.app";

/**
 * Forward a userbase hive write to api.skatehive.app, carrying the caller's
 * userbase_refresh cookie. Returns the upstream response verbatim. The web no
 * longer signs/broadcasts these actions — api owns them.
 */
export async function proxyUserbaseHive(
  request: NextRequest,
  path: string,
  transformBody?: (body: any) => any
): Promise<NextResponse> {
  const refreshToken = request.cookies.get("userbase_refresh")?.value;
  if (!refreshToken) {
    return NextResponse.json({ error: "Unauthorized" }, { status: 401 });
  }
  let body: any = {};
  try {
    body = await request.json();
  } catch {
    body = {};
  }
  if (transformBody) body = transformBody(body);
  try {
    const upstream = await fetch(`${API_BASE}${path}`, {
      method: "POST",
      headers: {
        "Content-Type": "application/json",
        Cookie: `userbase_refresh=${refreshToken}`,
      },
      body: JSON.stringify(body),
    });
    const text = await upstream.text();
    return new NextResponse(text, {
      status: upstream.status,
      headers: { "Content-Type": upstream.headers.get("Content-Type") ?? "application/json" },
    });
  } catch {
    return NextResponse.json({ error: "upstream unavailable" }, { status: 502 });
  }
}
```

- [ ] **Step 2: Replace the web `vote` route with a proxy**

Replace the entire contents of `apps/skatehive3.0/app/api/userbase/hive/vote/route.ts` with:

```ts
import { NextRequest } from "next/server";
import { proxyUserbaseHive } from "@/lib/userbase/proxyToApi";

export const runtime = "nodejs";

// Proxied to api.skatehive.app (single owner of the vote broadcast + soft-vote).
export async function POST(request: NextRequest) {
  return proxyUserbaseHive(request, "/api/userbase/hive/vote");
}
```

- [ ] **Step 3: Type-check + commit (web repo)**

```bash
cd apps/skatehive3.0 && npx tsc --noEmit
git add lib/userbase/proxyToApi.ts app/api/userbase/hive/vote/route.ts
git commit -m "refactor(userbase): proxy hive/vote to api (single owner)"
```
Expected: no new type errors.

- [ ] **Step 4: Deploy web to production**

Run: `cd apps/skatehive3.0 && vercel --prod`
Expected: deploy succeeds.

- [ ] **Step 5: Verify vote in prod (both transports + single soft-vote)**

Insert a disposable userbase user + session (no stored key → lite). Then:
```bash
# WEB transport via the proxied web route (weight 1 = tiny, harmless)
curl -s -o /dev/null -w "web cookie: %{http_code}\n" -X POST \
  -H "Content-Type: application/json" -H "Cookie: userbase_refresh=$TOKEN" \
  -d '{"author":"<test_author>","permlink":"<test_permlink>","weight":1}' \
  https://skatehive.app/api/userbase/hive/vote
```
Expected: `200`. Then confirm **exactly one** `userbase_soft_votes` row for that user/(author,permlink), `status=broadcasted`, no duplicate. Control: same call with no cookie → `401`. Regression: the same vote via `https://api.skatehive.app/...` with `Authorization: Bearer $TOKEN` still `200` (mobile path). Delete the disposable user.

---

## Task 3: `follow` route → smart proxy (keep toggle on web, delegate broadcast)

**Files:**
- Modify: `apps/skatehive3.0/app/api/userbase/hive/follow/route.ts` (replace handler)

**Interfaces:**
- Consumes: `proxyUserbaseHive` (Task 2). The web route keeps resolving the follower handle + querying `get_relationship_between_accounts` (reads), computes `type`, and forwards `{ following, type }` to api.

- [ ] **Step 1: Replace the web `follow` handler with a smart proxy**

Replace the handler body in `apps/skatehive3.0/app/api/userbase/hive/follow/route.ts` so it keeps the toggle detection but delegates the broadcast. The new handler:

```ts
import { NextRequest, NextResponse } from "next/server";
import { proxyUserbaseHive } from "@/lib/userbase/proxyToApi";
import { HiveClient } from "@/lib/hive/hiveclient"; // existing client import in this file — keep whatever the file already uses
import { getHiveIdentity, resolveSessionUserId } from "@/lib/userbase/session"; // keep the file's existing session/identity helpers

export const runtime = "nodejs";

export async function POST(request: NextRequest) {
  // Resolve session (cookie) → follower handle, to decide follow vs unfollow.
  const userId = await resolveSessionUserId(request);
  if (!userId) return NextResponse.json({ error: "Unauthorized" }, { status: 401 });

  let body: any;
  try {
    body = await request.json();
  } catch {
    return NextResponse.json({ error: "Invalid JSON body" }, { status: 400 });
  }
  const following = typeof body?.following === "string" ? body.following.trim() : "";
  if (!following || !/^[a-z0-9.-]{3,16}$/.test(following)) {
    return NextResponse.json({ error: "Invalid account to follow" }, { status: 400 });
  }

  const hiveIdentity = await getHiveIdentity(userId);
  const follower = hiveIdentity?.handle || null;
  if (!follower) {
    return NextResponse.json(
      { error: "Hive identity not linked", code: "HIVE_IDENTITY_NOT_LINKED" },
      { status: 400 }
    );
  }
  if (follower === following) {
    return NextResponse.json({ error: "Cannot follow yourself" }, { status: 400 });
  }

  // Toggle detection stays on web (a read); the broadcast moves to api.
  let alreadyFollowing = false;
  try {
    const rel = await HiveClient.call("bridge", "get_relationship_between_accounts", {
      account1: follower,
      account2: following,
    });
    alreadyFollowing = Boolean(rel?.follows);
  } catch {
    alreadyFollowing = false;
  }
  const type = alreadyFollowing ? "" : "blog"; // "" = unfollow (api → what:[""]), "blog" = follow

  return proxyUserbaseHive(request, "/api/userbase/hive/follow", () => ({ following, type }));
}
```

> Note for the implementer: keep the file's **existing** import paths for `HiveClient`, `getHiveIdentity`, and the session resolver (they already exist in this route today — reuse them; do not invent new modules). The `proxyUserbaseHive` second `await request.json()` is harmless (the body was already read here, so pass the computed body via `transformBody` which ignores the re-read — if double-read causes an empty body, inline the fetch instead of the helper). If `request.json()` cannot be read twice in this runtime, replace the final line with a direct `fetch` to `https://api.skatehive.app/api/userbase/hive/follow` using the cookie + `JSON.stringify({ following, type })`, returning the response verbatim (same shape as the helper).

- [ ] **Step 2: Guarantee single body read (inline fetch in follow)**

Because the follow handler already calls `await request.json()`, do **not** reuse the helper's body re-read. Replace the final `return proxyUserbaseHive(...)` line with an inline forward:

```ts
  const refreshToken = request.cookies.get("userbase_refresh")?.value;
  if (!refreshToken) return NextResponse.json({ error: "Unauthorized" }, { status: 401 });
  try {
    const upstream = await fetch("https://api.skatehive.app/api/userbase/hive/follow", {
      method: "POST",
      headers: { "Content-Type": "application/json", Cookie: `userbase_refresh=${refreshToken}` },
      body: JSON.stringify({ following, type }),
    });
    const text = await upstream.text();
    return new NextResponse(text, {
      status: upstream.status,
      headers: { "Content-Type": upstream.headers.get("Content-Type") ?? "application/json" },
    });
  } catch {
    return NextResponse.json({ error: "upstream unavailable" }, { status: 502 });
  }
```
(Remove the `proxyUserbaseHive` import from this file; `vote`/`comment` still use it.)

- [ ] **Step 3: Type-check + commit (web repo)**

```bash
cd apps/skatehive3.0 && npx tsc --noEmit
git add app/api/userbase/hive/follow/route.ts
git commit -m "refactor(userbase): proxy hive/follow broadcast to api (toggle stays on web)"
```

- [ ] **Step 4: Deploy + verify follow in prod**

Run: `cd apps/skatehive3.0 && vercel --prod`. Then, as a logged-in web user **with a linked Hive account + stored key** (own-key path; follow is 403 for lite/default by design):
- follow a test account via the web UI/route → `200`; on-chain a `custom_json id=follow what:["blog"]` from the user;
- repeat → unfollow (`what:[""]`);
- a lite/default user (no own key) → `403 REQUIRES_OWN_HIVE_ACCOUNT` (guard preserved);
- no-cookie → `401`.

---

## Task 4: `comment` route → proxy

**Files:**
- Modify: `apps/skatehive3.0/app/api/userbase/hive/comment/route.ts` (replace handler)

**Interfaces:**
- Consumes: `proxyUserbaseHive` (Task 2) + the api comment feature (Task 1, already deployed).

- [ ] **Step 1: Replace the web `comment` route with a proxy**

Replace the entire contents of `apps/skatehive3.0/app/api/userbase/hive/comment/route.ts` with:

```ts
import { NextRequest } from "next/server";
import { proxyUserbaseHive } from "@/lib/userbase/proxyToApi";

export const runtime = "nodejs";

// Proxied to api.skatehive.app (single owner of comment broadcast + soft-post).
// The full body — parent_author/permlink, body, title, permlink, type,
// json_metadata (incl. the web app tag), beneficiaries — is forwarded as-is.
export async function POST(request: NextRequest) {
  return proxyUserbaseHive(request, "/api/userbase/hive/comment");
}
```

- [ ] **Step 2: Confirm the web client sends its app tag (so it's not labeled mobile)**

Check that the web client includes `app` in the `json_metadata` it posts to `/api/userbase/hive/comment` (grep the callers in `components/`/`hooks/`). If the client does **not** set `app`, add it in the proxy via `transformBody`:
```ts
  return proxyUserbaseHive(request, "/api/userbase/hive/comment", (b) => ({
    ...b,
    json_metadata: { ...(b?.json_metadata && typeof b.json_metadata === "object" ? b.json_metadata : {}), app: "skatehive-web" },
  }));
```
Run: `grep -rn "app:" apps/skatehive3.0/hooks/useComposeForm.ts apps/skatehive3.0/components/homepage/SnapComposer.tsx | grep -i metadata`
Expected: determines whether the client already tags `app`; pick the plain or `transformBody` variant accordingly.

- [ ] **Step 3: Type-check + commit (web repo)**

```bash
cd apps/skatehive3.0 && npx tsc --noEmit
git add app/api/userbase/hive/comment/route.ts
git commit -m "refactor(userbase): proxy hive/comment to api (beneficiaries preserved)"
```

- [ ] **Step 4: Deploy + verify comment in prod (beneficiaries + app tag)**

Run: `cd apps/skatehive3.0 && vercel --prod`. As a logged-in web user (cookie), post a comment/snap **with a beneficiary** via the web:
- `200`; on-chain the comment has the `comment_options` beneficiary (not dropped);
- `json_metadata.app` is the **web** tag (e.g. `skatehive-web`/`skatehive`), **not** `skatehive-mobile`;
- exactly one `userbase_soft_posts` row (for a lite user) with `beneficiaries` in metadata;
- no double-broadcast (one on-chain comment).

---

## Task 5: Cleanup dead code + sync the docs/visual

**Files:**
- Modify: `apps/skatehive3.0/app/api/userbase/hive/{vote,comment}/route.ts` (already minimal — confirm no dead imports)
- Modify: `apps/skatehive3.0/app/api/userbase/hive/follow/route.ts` (remove now-unused key/broadcast imports)
- Modify: `docs/skatehive-infra.html` (web→api proxy flow)
- Modify: `API_ARCHITECTURE.md`, `USERBASE_UNIFICATION_PLAN.md` (status)

- [ ] **Step 1: Remove dead imports/helpers from the 3 web routes**

For `follow/route.ts`, delete now-unused imports (`PrivateKey`, `getPostingKey`, broadcast helpers) and any helper functions only they used. Run:
`cd apps/skatehive3.0 && npx tsc --noEmit && npx eslint app/api/userbase/hive/follow/route.ts`
Expected: no unused-import errors.

- [ ] **Step 2: Update the infra visual**

In `docs/skatehive-infra.html`, update the "Who calls what" / data-flow section so web `hive/{vote,comment,follow}` show as **proxied to api** (api is the single owner of the write-core). Keep the lime/blue/magenta DB color-coding. Reuse the existing `<style>`; only edit the relevant copy/diagram nodes.

- [ ] **Step 3: Update architecture docs status**

In `API_ARCHITECTURE.md` §6 recommendation #1 and `USERBASE_UNIFICATION_PLAN.md`, mark the vote/comment/follow cutover **done**, note comment now carries beneficiaries on api, and that account-update/report + bootstrap remain.

- [ ] **Step 4: Commit (web repo + monorepo)**

```bash
cd apps/skatehive3.0 && git add app/api/userbase/hive/ && git commit -m "chore(userbase): drop dead broadcast code from proxied routes"
cd ~/Code/skatehive/monorepo && git add docs/skatehive-infra.html API_ARCHITECTURE.md USERBASE_UNIFICATION_PLAN.md && git commit -m "docs: reflect phase 2 userbase cutover (web proxies vote/comment/follow to api)"
```

- [ ] **Step 5: Final regression sweep (prod)**

Re-run the disposable-user checks from Tasks 2-4 once more end-to-end (vote, comment-with-beneficiary, follow toggle), confirm mobile Bearer still resolves, then update `docs/userbase-phase1-findings.md` (or a new `phase2-findings.md`) with the outcome.

---

## Self-review

- **Spec coverage:** §4 proxy contract → Task 2 helper; §5.1 vote → Task 2; §5.2 comment app-tag **+ beneficiaries** (scope decision: all-in-one) → Task 1 (api feature) + Task 4 (proxy); §5.3 follow 403 + toggle → Task 3; §6 staging order (api comment feature → vote → follow → comment → cleanup) → Tasks 1-5; §7 verification → each task's verify step; §8 risks (502, body-shape, double-broadcast) → proxy contract + per-route checks. Covered.
- **Placeholder scan:** `<test_author>`/`<test_permlink>`/`$TOKEN` are runtime test values (disposable-user pattern from Phase 1), not unspecified logic. The follow note flags the single-body-read gotcha and resolves it in Step 2 (inline fetch).
- **Type consistency:** `proxyUserbaseHive(request, path, transformBody?)` used identically in Tasks 2/4; follow uses an inline fetch (Step 2) to avoid the double body-read. `broadcastComment` beneficiaries param matches between `posting.ts` (Task 1) and the comment route call.
- **Ordering invariant:** Task 1 (api comment feature) deploys **before** Task 4 (web comment proxy), so proxied comments never hit an api that drops beneficiaries.
