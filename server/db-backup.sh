#!/usr/bin/env bash
# Hourly application-consistent backup of the website's SQLite database to Cloud Storage.
set -euo pipefail

DB=/var/lib/legion/legion.db
BUCKET=project-aee592e9-ccea-48e5-bb0-db-backups
STAMP=$(date -u +%Y%m%dT%H%M%SZ)
TMP=$(mktemp -d)
trap 'rm -rf "$TMP"' EXIT

# 1. Clean copy while the site keeps running (SQLite online backup)
sqlite3 "$DB" ".backup '$TMP/legion.db'"

# 2. Never upload a broken copy
CHECK=$(sqlite3 "$TMP/legion.db" "PRAGMA integrity_check;")
if [ "$CHECK" != "ok" ]; then
  echo "integrity check failed: $CHECK" >&2
  exit 1
fi

# 3. Compress and upload with a timestamped name.
# The VM's own identity comes from the metadata server, so no gcloud is needed.
gzip "$TMP/legion.db"
TOKEN=$(curl -sS --fail-with-body -H "Metadata-Flavor: Google" \
  "http://metadata.google.internal/computeMetadata/v1/instance/service-accounts/default/token" \
  | python3 -c 'import json, sys; print(json.load(sys.stdin)["access_token"])')
curl -sS --fail-with-body -o /dev/null -X POST \
  -H "Authorization: Bearer $TOKEN" -H "Content-Type: application/gzip" \
  --data-binary @"$TMP/legion.db.gz" \
  "https://storage.googleapis.com/upload/storage/v1/b/$BUCKET/o?uploadType=media&name=legion%2F$STAMP.db.gz"
echo "backup ok: legion/$STAMP.db.gz"