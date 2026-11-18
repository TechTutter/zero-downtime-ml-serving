#!/usr/bin/env bash
# Promote by digest: copy an image and every cosign artifact that refers to it
# (signature / attestation tags named sha256-<hex>*), then prove the digest did not change.
# Usage: tools/copy-signed.sh <src_repo@sha256:...> <dst_repo> [tag]
set -euo pipefail
SRC=${1:?source image by digest}
DST_REPO=${2:?destination repository}
TAG=${3:-}
SRC_REPO=${SRC%@*}
DIGEST=${SRC#*@}
[[ $DIGEST == sha256:* ]] || { echo "source must be pinned by digest: $SRC" >&2; exit 1; }

crane copy "$SRC" "$DST_REPO@$DIGEST"
[[ -n $TAG ]] && crane tag "$DST_REPO@$DIGEST" "$TAG"

# crane copies one manifest; cosign stores signatures as separate artifacts next to it.
for t in $(crane ls "$SRC_REPO" | grep "^sha256-${DIGEST#sha256:}" || true); do
  crane copy "$SRC_REPO:$t" "$DST_REPO:$t"
done

got=$(crane digest "$DST_REPO@$DIGEST")
[[ $got == "$DIGEST" ]] || { echo "digest changed: $DIGEST -> $got" >&2; exit 1; }
echo "$DST_REPO@$DIGEST"
