#!/usr/bin/env bash
# Pull-based continuous deployment: if CI has pushed a newer image than the one
# running, deploy it with legion-deploy (health check + automatic rollback).
# A tag that failed to deploy is remembered and not retried, so a bad image
# cannot restart the site every few minutes.
set -euo pipefail

PROJECT=project-aee592e9-ccea-48e5-bb0
API="https://artifactregistry.googleapis.com/v1/projects/$PROJECT/locations/us-central1/repositories/web/dockerImages"
FAILED=/var/lib/legion-autodeploy/failed

TOKEN=$(curl -s -H "Metadata-Flavor: Google" \
  http://metadata.google.internal/computeMetadata/v1/instance/service-accounts/default/token \
  | python3 -c 'import json, sys; print(json.load(sys.stdin)["access_token"])')

LATEST=$(curl -fs -H "Authorization: Bearer $TOKEN" "$API?pageSize=50" | python3 -c '
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