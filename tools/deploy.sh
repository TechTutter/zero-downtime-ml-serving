#!/usr/bin/env bash
# Deploy an image (by digest) as a new Cloud Run revision with no traffic; print its name.
# Fault knobs are always set explicitly so a bad revision's settings never leak into the next.
# Usage: tools/deploy.sh <project> <region> <service> <image@digest> <version> [error_rate] [latency_ms]
set -euo pipefail
PROJECT=${1:?project}
REGION=${2:?region}
SERVICE=${3:?service}
IMAGE=${4:?image@digest}
VERSION=${5:?version}
ERROR_RATE=${6:-0}
LATENCY_MS=${7:-0}
[[ $IMAGE == *@sha256:* ]] || { echo "deploy by digest only: $IMAGE" >&2; exit 1; }

# Revision names: lowercase, digits, dashes. v0.2.0 -> v0-2-0-<unique>
SUFFIX="$(tr '.' '-' <<<"$VERSION" | tr -cd 'a-z0-9-')-$(date +%s | tail -c 6)"
gcloud run deploy "$SERVICE" --project "$PROJECT" --region "$REGION" --quiet \
  --image "$IMAGE" --no-traffic --revision-suffix "$SUFFIX" \
  --update-env-vars "APP_VERSION=$VERSION,FAULT_ERROR_RATE=$ERROR_RATE,FAULT_LATENCY_MS=$LATENCY_MS" \
  >&2
echo "$SERVICE-$SUFFIX"
