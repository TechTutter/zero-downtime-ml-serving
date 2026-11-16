#!/usr/bin/env bash
# Prove graceful shutdown: requests in flight when SIGTERM arrives must still succeed.
# Starts the image with 2s of injected latency, fires concurrent requests, stops the container
# mid-flight and fails if any request did not return 200.
# Usage: tools/drain-test.sh <image> [concurrency]
set -euo pipefail
IMAGE=${1:?image}
N=${2:-20}
DIR=$(cd "$(dirname "$0")" && pwd)
OUT=$(mktemp -d)
trap 'docker rm -f model-server >/dev/null 2>&1; rm -rf "$OUT"' EXIT

"$DIR/run-local.sh" "$IMAGE" -e FAULT_LATENCY_MS=2000 >/dev/null
for i in $(seq "$N"); do
  curl -s -o /dev/null -w '%{http_code}\n' -XPOST localhost:8080/predict \
    -H 'content-type: application/json' -d '{"instances":[[5.1,3.5,1.4,0.2]]}' >"$OUT/$i" &
done
sleep 0.5
docker stop -t 30 model-server >/dev/null # SIGTERM, then up to 30s to drain
wait

ok=$(cat "$OUT"/* | grep -c '^200$' || true)
echo "in-flight requests completed: $ok/$N"
[[ $ok -eq $N ]]
