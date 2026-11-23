#!/usr/bin/env bash
# Pull-based continuous deployment: if CI has pushed a newer image than the one
# running, deploy it with legion-deploy (health check + automatic rollback).
# A tag that failed to deploy is remembered and not retried, so a bad image
# cannot restart the site every few minutes.
set -euo pipefail

PROJECT=project-aee592e9-ccea-48e5-bb0
API="https://artifactregistry.googleapis.com/v1/projects/$PROJECT/locations/us-central1/repositories/web/dockerImages"
FAILED=/var/lib/legion-autodeploy/failed

# HB-206: report "autodeploy is alive" plus the site version actually running.
# Best effort: a failed heartbeat must never fail or block a deploy.
heartbeat() {
  local hb_token version
  hb_token=$(grep -m1 '^HB_TOKEN=' /etc/legion.env 2>/dev/null | cut -d= -f2- || true)
  [ -n "$hb_token" ] || return 0
  version=$(docker inspect --format '{{.Config.Image}}' legion 2>/dev/null | sed 's/.*://' || true)
  [ -n "$version" ] || return 0
  curl -s -o /dev/null --max-time 5 -X POST http://127.0.0.1:3000/api/hb \
    -H "Authorization: Bearer $hb_token" -H "Content-Type: application/json" \
    -d "{\"service\":\"autodeploy\",\"version\":\"${version:-none}\",\"intervalSec\":120}" || true
}
trap 'heartbeat' EXIT

TOKEN=$(curl -s -H "Metadata-Flavor: Google" \
  http://metadata.google.internal/computeMetadata/v1/instance/service-accounts/default/token \
  | python3 -c 'import json, sys; print(json.load(sys.stdin)["access_token"])')

# Newest first: the registry holds more than one page of images (each build also
# stores untagged attestation manifests), so an unsorted first page can miss the newest tag.
LATEST=$(curl -fs -H "Authorization: Bearer $TOKEN" "$API?pageSize=50&orderBy=update_time%20desc" | python3 -c '
import json, sys
images = [i for i in json.load(sys.stdin).get("dockerImages", []) if i.get("tags")]
print(max(images, key=lambda i: i["updateTime"])["tags"][0] if images else "")')

RUNNING=$(docker inspect --format '{{.Config.Image}}' legion 2>/dev/null | sed 's/.*://' || true)

[ -n "$LATEST" ] || exit 0                                    # registry empty
[ "$LATEST" != "$RUNNING" ] || exit 0                         # already running
[ "$LATEST" != "$(cat "$FAILED" 2>/dev/null)" ] || exit 0     # failed before, wait for a new one

echo "new image $LATEST (running: ${RUNNING:-none}), deploying"
if /usr/local/bin/legion-deploy "$LATEST"; then
  rm -f "$FAILED"
else
  echo "$LATEST" > "$FAILED"
  exit 1
fi