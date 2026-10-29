#!/usr/bin/env bash
# Deploy a website image on the server: pull it, swap the running container,
# health-check it, and roll back automatically if it does not come up.
# Usage (on the server): sudo legion-deploy <image-tag>
set -euo pipefail

TAG="${1:?usage: legion-deploy <image-tag>}"
REGISTRY=us-central1-docker.pkg.dev
IMAGE="$REGISTRY/project-aee592e9-ccea-48e5-bb0/web/legion-web:$TAG"

run_container() {
  docker run -d --name legion --restart unless-stopped \
    --env-file /etc/legion.env -e DATA_DIR=/data \
    --user "$(id -u legion):$(id -g legion)" \
    -v /var/lib/legion:/data \
    -p 127.0.0.1:3000:3000 \
    "$1" >/dev/null
}

# Log in with the VM's own identity (short-lived token from the metadata server)
curl -s -H "Metadata-Flavor: Google" \
  http://metadata.google.internal/computeMetadata/v1/instance/service-accounts/default/token \
  | python3 -c 'import json, sys; print(json.load(sys.stdin)["access_token"])' \
  | docker login -u oauth2accesstoken --password-stdin "https://$REGISTRY" >/dev/null
docker pull -q "$IMAGE" >/dev/null

PREVIOUS=$(docker inspect --format '{{.Config.Image}}' legion 2>/dev/null || true)

systemctl stop legion 2>/dev/null || true   # the old non-container service (first switch only)
docker rm -f legion >/dev/null 2>&1 || true
run_container "$IMAGE"

for _ in $(seq 1 20); do
  if curl -fs -o /dev/null http://127.0.0.1:3000/; then
    systemctl disable legion 2>/dev/null || true   # the container now owns port 3000, also after reboots
    echo "deployed $IMAGE"
    exit 0
  fi
  sleep 3
done

echo "health check failed, rolling back" >&2
docker logs --tail 20 legion >&2 || true
docker rm -f legion >/dev/null
if [ -n "$PREVIOUS" ]; then
  run_container "$PREVIOUS"
  echo "rolled back to $PREVIOUS" >&2
else
  systemctl start legion
  echo "rolled back to the systemd service" >&2
fi
exit 1
