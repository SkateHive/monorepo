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
