#!/usr/bin/env bash
set -euo pipefail
# Stage C — prove api resolves BOTH a userbase_refresh cookie (web) and an
# Authorization: Bearer token (mobile) to the same session. Inserts a disposable
# user+session, tests, then deletes the rows (EXIT trap).
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
[ -n "$USER_ID" ] || { echo "insert failed (RLS?) — see REST fallback in plan" >&2; exit 1; }
echo "inserted disposable user: $USER_ID"

echo "--- control: NO auth (expect 401) ---"
curl -s -o /dev/null -w "HTTP %{http_code}\n" "$API_BASE$ENDPOINT"

echo "--- WEB transport: userbase_refresh cookie (expect NOT 401) ---"
ccode="$(curl -s -o /tmp/p1_resp_c.json -w "%{http_code}" -H "Cookie: userbase_refresh=$TOKEN" "$API_BASE$ENDPOINT")"
echo "HTTP $ccode"; echo "body: $(cat /tmp/p1_resp_c.json)"

echo "--- MOBILE transport: Authorization: Bearer (expect NOT 401, same user) ---"
bcode="$(curl -s -o /tmp/p1_resp_b.json -w "%{http_code}" -H "Authorization: Bearer $TOKEN" "$API_BASE$ENDPOINT")"
echo "HTTP $bcode"; echo "body: $(cat /tmp/p1_resp_b.json)"

echo "--- result ---"
{ [ "$ccode" != "401" ] && [ "$bcode" != "401" ]; } \
  && echo "PASS: both web cookie and mobile Bearer resolve the same session" \
  || echo "CHECK: a transport returned 401 — investigate before any cutover"
