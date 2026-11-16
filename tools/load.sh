#!/usr/bin/env bash
# Constant-rate k6 load. MAX_ERROR_RATE=0 (default) fails on the first failed request.
# Usage: tools/load.sh <base_url> [rate_per_s] [duration]
set -euo pipefail
cd "$(dirname "$0")/.."
mkdir -p k6-results
k6 run --quiet \
  -e BASE_URL="${1:?base url}" -e RATE="${2:-20}" -e DURATION="${3:-1m}" \
  -e MAX_ERROR_RATE="${MAX_ERROR_RATE:-0}" \
  --summary-export k6-results/summary.json \
  tests/load/constant.js
