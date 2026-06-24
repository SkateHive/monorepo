# SkateHive API Architecture

How the SkateHive apps provide and consume API services across the monorepo, the
shared backend structure, and an evaluation of the current split.

> Scope: the **API / backend** surface only. Each app below is its own git repo,
> gitignored by the monorepo and deployed as its **own Vercel project**.

---

## 1. The pieces

| Repo (in monorepo) | Role | Domain | Deploy |
|---|---|---|---|
| `apps/skatehive3.0` | Web app **+ a backend** (Next.js API routes) | `skatehive.app` | Vercel project A |
| `services/skatehive-api` | Backend only (Next.js API routes) | `api.skatehive.app` | Vercel project B |
| `apps/mobileapp` | Expo/React Native client (no backend) | — | TestFlight / Play |
| transcode / IG-scraper / leaderboard | Heavy jobs **off Vercel** | Mac Mini + Oracle + Pi (Tailscale) | self-hosted |

**Databases (3 distinct — do not conflate):**
1. **HAFSQL** (Hive HAF Postgres, `HAFSQL_*`) — read-only Hive chain data (feeds,
   accounts, balances, follows). **api only.** External; never migrate it.
2. **Supabase "userbase"** (project `aaxhnehcjyvtgrlnyhcp`) — `userbase_*`,
   `spotmap_spots`, soft-posts/votes, sponsorships, `userbase_instagram_posts`.
   **Shared by api + web** (api `SUPABASE_USERBASE_URL`, web `SUPABASE_URL`).
   Migrations: `apps/skatehive3.0/sql/migrations/*` (canonical, 27 files) +
   `services/skatehive-api/src/lib/userbase/migrations/userbase_email_otps.sql`
   (1 file — schema source is split; consolidate later).
3. **Supabase "leaderboard"** (project `akjnjktnghfutbfeijug`) — rankings only.
   **api only** (`NEXT_PUBLIC_SUPABASE_URL` + `SUPABASE_LEADERBOARD_SERVICE_ROLE_KEY`).

The two backends **couple through the shared userbase DB**, not over HTTP (one
minor exception: `skatehive-api`'s `dataManager` self-calls `/api/v2/activity/*`).

```
                 ┌──────────── Supabase "userbase" (project aaxh…) ───────────┐
                 │  userbase_users / _sessions / _identities / _hive_keys /    │
                 │  _soft_posts / _soft_votes / _sponsorships /                │
                 │  userbase_instagram_posts / spotmap_spots / ...             │
                 │  (HAFSQL + a separate "leaderboard" Supabase = api-only)    │
                 └───────▲───────────────────────────────────────────▲────────┘
                         │ writes/reads                  writes/reads │
           ┌─────────────┴─────────────┐            ┌────────────────┴─────────────┐
           │   api.skatehive.app       │            │      skatehive.app            │
           │  (services/skatehive-api) │            │     (apps/skatehive3.0)       │
           │  ~76 route files          │            │     ~89 route files           │
           │  Auth: Bearer token       │            │  Auth: userbase_refresh cookie│
           └──────▲─────────▲──────────┘            └─────▲──────────────▲──────────┘
                  │         │                              │              │
        feed/profile/    userbase auth +           web app's own     Instagram + bootstrap +
        spotmap/         hive vote/comment/         pages & client    profile/instagram +
        transcode        follow/report (mobile)                       identities/keys/sponsorship
                  │         │                              │              │
                  └─────────┴───────────── apps/mobileapp ─┴──────────────┘
                         (mobile now talks to BOTH backends)
```

---

## 2. What each backend owns

### `api.skatehive.app` (services/skatehive-api) — ~76 routes
The **read/data + mobile-custody** backend.

- **Feed & discovery** (`/api/v1/*`, `/api/v2/*`): feed, trending, comments, profile,
  followers/following, balances, rewards, search, market, videos, highest-paid,
  leaderboard, magazine, skatespots. (v1 is legacy; v2 is the current version — **the
  two overlap heavily and v1 should be retired.**)
- **Userbase (mobile)**: `auth/otp/{request,verify}`, `auth/signup/complete`,
  `auth/session`, `auth/logout`, `hive/{vote,comment,follow,account-update,report,
  notifications,check-username,upload-image}`, `soft-posts`. **Auth = Bearer token.**
- **Posting/IPFS**: `v2/postFeed*`, `v2/createpost`, `v2/ipfs/upload` (API-key + rate-limited).
- **Spotmap (read)**, **transcode proxy/status**, **status/logs**, **1 hourly cron**
  (`/api/cron/highest-paid`). Heavy recompute (leaderboard) runs **off Vercel**.

### `skatehive.app` (apps/skatehive3.0) — ~89 routes
The **web app + identity/feature** backend.

- **Userbase (web)**: `auth/{bootstrap,magic-link,session,sign-up,lookup,logout}`,
  `identities/{hive,evm,farcaster}/{challenge,verify}`, `keys/*` (encrypted posting
  keys), `merge/*`, `sponsorships/*`, `profile`, `profile/instagram`,
  `hive/{vote,comment,follow}`, `soft-posts/* + soft-votes/*`. **Auth = `userbase_refresh` cookie.**
- **Instagram**: `instagram/{post,force-post}` (Meta Graph — holds the Meta tokens),
  plus `instagram-download/health` (the scraper proxy).
- **Farcaster** (Neynar), **Pinata/IPFS** (incl. edge-runtime `pinata-mobile` for 135 MB),
  **bounties/poidh**, **DEX/portfolio** (0x, CoinGecko, Alchemy, Zora), **media proxies**
  (heic, opengraph, video-proxy 300 s), **spotmap sync**, **1 daily cron**.

---

## 3. Who calls what

### apps/mobileapp → **both** backends
- **`api.skatehive.app`** (most of the app): feed/videos/balance/profile/leaderboard
  (`lib/api.ts`, `lib/constants.ts API_BASE_URL`), all userbase auth + server-custody
  hive actions (`lib/userbase/api.ts`, `lib/posting.ts`), spotmap, transcode.
- **`skatehive.app`**: mobile makes no API calls there anymore (only the caption
  **permalink text** points at it). See the Instagram status below.

> **Instagram cross-posting — status (2026-06):**
> - **One implementation on `api.skatehive.app`**: `/api/instagram/post` +
>   `/api/userbase/profile/instagram`. **Dual auth**: a posting-key **signature**
>   (mobile key accounts) **or** a userbase **session** — Bearer (mobile email
>   accounts) / `userbase_refresh` cookie (web).
> - **Mobile → api only.** **Web `/api/instagram/post` proxies to api** (unified,
>   live). The web **force-post** (moderator carousel) still runs on the web with
>   its own token — transitional duplication; both write the shared
>   `userbase_instagram_posts` table so dedupe/limits stay consistent.
> - **Eligibility:** classic key accounts, OR email accounts with a **linked,
>   eligible (≥100 HP) Hive account** — not all email users.
> - **Resilience:** ordered token-fallback (auth-error failover), a fail-open
>   pre-flight media-fetchability check (turns Meta's opaque 2207077 into a clear
>   retryable error), and the force-post carousel **skips items Meta rejects** +
>   lets the moderator **select** which items to post.
> - **Known open item (upstream, not code):** some **video CIDs never pin/serve**
>   on `ipfs.skatehive.app` (return 400 to everyone incl. Meta) → those Reels can't
>   cross-post **and don't play in the feed**. Fix belongs in the transcoder/pinning.
> - The temp skatehive.app firewall bypass stays until old mobile builds age out.

### apps/skatehive3.0 → mostly itself, plus api.skatehive.app from the **client**
The web **server** routes call Supabase / Hive RPC / external services directly. The web
**client** fetches read data (`feed`, `leaderboard`) from `api.skatehive.app`. It does
not route mobile-userbase calls through api.skatehive.app.

### services/skatehive-api → Hive RPC + Supabase (+ self for activity)
No outbound calls to skatehive.app.

---

## 4. The core issue: a split-brain `userbase`

`userbase` is implemented **twice**, once per backend, over the **same tables**:

| Concern | api.skatehive.app | skatehive.app | Same Supabase tables |
|---|---|---|---|
| Email login | OTP (`auth/otp/*`) | magic-link (`auth/magic-link`) | `userbase_auth_methods`, sessions |
| Session transport | **Bearer token** | **httpOnly cookie** | `userbase_sessions` (interchangeable rows) |
| Hive vote/comment/follow | server-signs (Bearer) | server-signs (cookie) | `userbase_soft_posts/_votes` |
| Profile / identities / keys / sponsorship / IG | — | ✅ | `userbase_*` |
| Bootstrap (Hive→userbase) | — | ✅ (mobile now depends on it) | `userbase_users/_identities` |

Consequences observed in practice:
- **Double implementation, drift risk.** Session creation, hive broadcast, signup
  conflict checks, etc. exist as **parallel code** in both repos. A fix in one (e.g.
  the recent signup handle-conflict fix and the bootstrap token-return) does **not**
  carry to the other.
- **Mobile now spans both deployments.** Core actions need `api.skatehive.app`;
  Instagram + bootstrap need `skatehive.app`. If either is down/challenged, part of the
  app breaks. (See the Vercel "Security Checkpoint" note in §6.)
- **No transaction/schema boundary** between the two writers of the shared tables.

---

## 5. Is the split smart? — evaluation

**What's good:**
- Separating the **data/read API** (`api.skatehive.app`) from the **web app** is
  reasonable — the mobile app and web client both consume the same read API, and it can
  scale/cache independently.
- **Heavy jobs are correctly off Vercel** (leaderboard recompute, video transcode, IG
  scraping on Mac Mini/Oracle/Pi). This is the single most important Vercel-limit win.
- Caching is used widely (`s-maxage`/SWR), and large uploads use **edge runtime**
  (`pinata-mobile` 135 MB) to dodge the 4.5 MB serverless body limit.

**What strains Vercel limits / is not smart:**
1. **~165 route files across two projects**, with large internal duplication:
   - `v1` vs `v2` in api.skatehive.app (feed/comments/profile/balance/market all doubled).
   - `userbase/*` duplicated **across** the two projects (different auth transport, same DB).
   Every route is a serverless function → more cold starts, bigger deploys, more surface
   to keep under per-project function/duration limits.
2. **Meta tokens + Instagram live only on skatehive.app**, so the mobile app is forced to
   call the web deployment for IG — creating cross-deployment coupling and the bootstrap
   workaround (sending a session token as a `Cookie` header from RN).
3. **Two auth models** (Bearer vs cookie) for the same sessions means every shared feature
   gets built twice or bridged awkwardly.

---

## 6. Recommendations (status)

1. **Unify `userbase` into one backend** (recommended: `api.skatehive.app`) accepting
   **both** transports — `Authorization: Bearer` (mobile) **and** `userbase_refresh`
   cookie (web) — so web calls one implementation instead of re-hosting `userbase/*`.
   Kills the split-brain and the drift. ⏳ **Open — biggest item; needs a plan** (the
   two are separate git repos, so a shared package isn't trivial; likely api becomes the
   single userbase backend and web proxies/calls it).
2. **Move Instagram (+ Meta tokens) to `api.skatehive.app`.** ✅ **Done (2026-06)** —
   dual-auth (signature or userbase session), web user cross-post proxies to api,
   token-fallback + pre-flight media check + carousel select/skip. Web force-post
   (moderator carousel) still on web — port later to fully retire web's IG libs.
3. **Retire `/api/v1/*`.** 🔸 **In progress** — confirmed zero internal consumers + full
   v2 parity. Now emitting `Deprecation`/`Sunset` headers + usage logging via
   `middleware.ts`; delete the 15 route files (and the `v1/auth.ts` util the middleware
   imports — extract it first) after a no-traffic observation window.
4. **Keep heavy/long work off Vercel** (already done) and prefer **edge runtime** for
   pure proxy/streaming routes. ✅
5. **Vercel firewall** on skatehive.app challenges programmatic `/api/*` calls (managed
   bot rules: `bot_filter`=challenge, `ai_bots`=deny, JA3/JA4 on — NOT Attack Challenge
   Mode). Handled via a targeted WAF bypass for the 3 mobile paths; made largely moot by
   #2 (api.skatehive.app isn't challenged). ✅

---

## 7. Quick reference — endpoint groups

**api.skatehive.app** (`services/skatehive-api/src/app/api`): `v1/*` (legacy),
`v2/*` (feed, profile, balance, search, market, videos, leaderboard, highest-paid,
postFeed, ipfs), `userbase/auth/*`, `userbase/hive/*`, `userbase/soft-posts`,
`spotmap/*`, `transcode*`, `status`, `logs`, `cron/highest-paid`.

**skatehive.app** (`apps/skatehive3.0/app/api`): `userbase/auth/*`,
`userbase/identities/*`, `userbase/keys/*`, `userbase/hive/*`, `userbase/soft-*`,
`userbase/sponsorships/*`, `userbase/profile{,/instagram}`, `instagram/*`,
`instagram-download|health`, `farcaster/*`, `pinata*`, `hive`, `bounty/*`, `poidh/*`,
`0x/*`, `prices`, `portfolio/*`, `dao/*`, `spotmap/*`, media proxies, `cron`.

_Last updated: 2026-06-23. Counts are route-file approximations (api ≈ 76, web ≈ 89)._
