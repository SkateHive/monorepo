# Mobile Spot Submission — Design

**Date:** 2026-06-13
**Scope:** `apps/mobileapp` (UI + submit) and `apps/skatehive3.0` (targeted ingestion + cron backstop)

## Goal

Let mobile users add a skate spot from the field: tap `+` → **Spot**, capture/pick
media, auto-detect location (confirm with a draggable pin), name it, submit. The
spot appears on the map for the poster instantly and for everyone within seconds —
without depending on the manual admin sync.

## Background / constraints

- A "spot" is a Hive **snap** (comment under `peak.snaps`'s latest container) tagged
  `["hive-173115", "skatespot"]`, with a canonical body:
  ```
  Spot Name: <name>
  🌐 <lat>, <lng> (<address>)

  <description>

  ![caption](image-url)
  ```
- `parseSpotBody()` extracts name/lat/lng/address/description/images from that body.
- The map reads cached rows from Supabase `spotmap_spots` via `GET /api/spotmap`
  (edge-cached ~5 min). Rows are populated by `syncHiveSpots()` in
  `lib/spotmap/syncHive.ts`.
- **Problem:** `syncHiveSpots()` is only ever run by a manual admin click
  (`POST /api/admin/spotmap/sync`, gated by web `userbase` session + admin
  allow-list). No cron runs it. Mobile cannot call it (no admin creds). So a newly
  posted spot is invisible until a human syncs.

## Decision: targeted ingestion + cron backstop

1. **`syncSingleHiveSpot(author, permlink)`** (new, in `lib/spotmap/syncHive.ts`):
   fetch that one post from Hive, verify it carries the `skatespot` tag, run
   `parseSpotBody()`, upsert one `spotmap_spots` row. Reuses the existing parse +
   upsert shape. Returns `{ upserted, skippedReason? }`.
2. **`POST /api/spotmap/sync-one`** (new public route): body `{ author, permlink }`
   → calls `syncSingleHiveSpot`. Safe because the row's data is taken from the
   verified on-chain post, not the request body. Light rate-limiting / basic input
   validation. Returns the upserted spot (or a reason it was skipped).
3. **Cron backstop:** register `syncHiveSpots()` on a schedule (add to the existing
   `/api/cron` daily job and/or a more frequent entry) so spots from any client,
   plus edits, reconcile automatically. Retires the manual-admin dependency.

Rejected: cron-only (≤15 min lag), local-pin-only (invisible to others), mobile
calling the admin endpoint (would require admin creds in the app).

## Mobile UX

### Entry point
The center `+` tab stops navigating straight to `create`. Tapping `+` opens a
**drop-up popover anchored directly above the `+` button** with two choices:
- **Post** → existing `create` screen (unchanged).
- **Spot** → new Add Spot screen.

Implemented by intercepting the create tab's `tabPress` (preventDefault) and
toggling a popover rendered above the tab bar, pointing at the button. Dark theme,
green accent, haptic on open.

### Add Spot screen (single progressive screen)
1. **Media:** "Camera" (device camera) or "Library" (picker); photos + videos.
   Reuses `uploadImageToHive` (images) and `uploadVideoToWorker` (video).
2. **Location:** auto-resolve GPS on open (`expo-location`), drop a **draggable pin**
   on a `react-native-maps` mini-map, reverse-geocode to an address line. Drag to
   fine-tune. If permission denied, user drags the pin manually.
3. **Name** (required) + **Description** (optional).
4. **Submit** enabled when name present AND (≥1 media OR confirmed location).

### Submit pipeline
1. Upload media (existing pipeline).
2. Compose canonical spot body; `getLastSnapsContainer()` for the parent; broadcast
   via `createHiveComment()` with tags including `skatespot`.
3. **Optimistic local pin:** inject the new spot into the `useAllSpots` query cache
   so it shows on the map immediately.
4. Call `POST /api/spotmap/sync-one { author, permlink }`; on success refetch
   `/api/spotmap` and re-run `syncSpotWidget()`.
5. Toast success; navigate to the map centered on the new pin.

### Deferred to v1.1
- EXIF-GPS-from-photo as an alternative location source.

## Out of scope
- Editing/deleting spots from mobile.
- Wiring `sync-one` into the web composer (works the same if added later).
