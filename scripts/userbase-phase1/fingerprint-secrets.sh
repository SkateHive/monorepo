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
  m="NO"; { [ "$fa" = "$fw" ] && [ "$fa" != "(missing)" ]; } && m="YES" || allmatch=0
  printf "%-34s %-14s %-14s %s\n" "$v" "$fa" "$fw" "$m"
done
# Same Supabase DB? compare the project host of each side's Supabase URL.
host(){ grep -E "^($2)=" "$1" | head -1 | cut -d= -f2- | tr -d '"' | sed -E 's#https?://##; s#/.*##'; }
ha="$(host "$API_ENV" 'SUPABASE_USERBASE_URL|SUPABASE_URL')"; hw="$(host "$WEB_ENV" 'SUPABASE_URL|NEXT_PUBLIC_SUPABASE_URL')"
echo "---"; echo "Supabase host  api=$ha  web=$hw  MATCH=$([ "$ha" = "$hw" ] && echo YES || echo NO)"
{ [ "$allmatch" = 1 ] && [ "$ha" = "$hw" ]; } && echo "RESULT: secrets+DB MATCH" || { echo "RESULT: MISMATCH — STOP, do not plan a cutover"; exit 2; }
