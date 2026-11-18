#!/usr/bin/env bash
# CI proof of "build once, promote by digest" between two local registries:
# push to registry A, sign keyless, copy to registry B, verify digest and signature on B.
# Needs GitHub OIDC (id-token: write) for keyless signing.
# Usage: tools/promotion-check.sh <local_image> [registry_a] [registry_b]
set -euo pipefail
IMAGE=${1:?local image}
A=${2:-localhost:5001}/model-server
B=${3:-localhost:5002}/model-server
DIR=$(cd "$(dirname "$0")" && pwd)

docker tag "$IMAGE" "$A:candidate"
docker push -q "$A:candidate" >/dev/null
DIGEST=$(crane digest "$A:candidate")

cosign sign --yes --allow-insecure-registry "$A@$DIGEST"
"$DIR/copy-signed.sh" "$A@$DIGEST" "$B" promoted
"$DIR/verify-signature.sh" "$B@$DIGEST" --allow-insecure-registry
echo "promotion ok: $B@$DIGEST keeps digest and valid signature"
