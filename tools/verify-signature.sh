#!/usr/bin/env bash
# Verify a keyless cosign signature made by this repository's GitHub Actions workflows.
# Usage: tools/verify-signature.sh <image@digest> [extra cosign args...]
set -euo pipefail
REF=${1:?image by digest}
shift
REPO=${GITHUB_REPOSITORY:-TechTutter/zero-downtime-ml-serving}
cosign verify "$@" \
  --certificate-identity-regexp "^https://github.com/${REPO}/\.github/workflows/" \
  --certificate-oidc-issuer https://token.actions.githubusercontent.com \
  "$REF" >/dev/null
echo "signature ok: $REF"
