#!/usr/bin/env bash
set -euo pipefail

: "${DATABASE_URL:?DATABASE_URL is required}"
BACKUP_DIR="${BACKUP_DIR:-./backups}"
mkdir -p "$BACKUP_DIR"
STAMP="$(date -u +%Y%m%dT%H%M%SZ)"
OUT="$BACKUP_DIR/loss-defender-pro-$STAMP.dump"

pg_dump "$DATABASE_URL" --format=custom --no-owner --file="$OUT"
pg_restore --list "$OUT" >/dev/null
printf 'Backup verified: %s\n' "$OUT"

if [[ "${RESTORE_DRILL:-false}" == "true" ]]; then
  : "${RESTORE_DATABASE_URL:?RESTORE_DATABASE_URL is required for restore drill}"
  pg_restore --clean --if-exists --no-owner --dbname="$RESTORE_DATABASE_URL" "$OUT"
  psql "$RESTORE_DATABASE_URL" -tAc 'select 1' | grep -qx 1
  printf 'Restore drill verified successfully.\n'
fi
