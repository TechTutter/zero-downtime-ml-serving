#!/usr/bin/env bash
# Run the model server container on localhost:8080, read-only and non-root like on Cloud Run.
# Usage: tools/run-local.sh <image> [extra docker run args...]
set -euo pipefail
IMAGE=${1:?image}
shift
docker rm -f model-server >/dev/null 2>&1 || true
docker run -d --name model-server --read-only --cap-drop ALL -p 8080:8080 "$@" "$IMAGE" >/dev/null
for _ in $(seq 30); do
  curl -fsS localhost:8080/readyz >/dev/null 2>&1 && { echo "model-server ready on http://localhost:8080"; exit 0; }
  sleep 1
done
docker logs model-server >&2
exit 1
