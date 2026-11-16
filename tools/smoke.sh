#!/usr/bin/env bash
# Call /version and /predict on a running server.
# Usage: tools/smoke.sh [base_url]   (default: http://localhost:8080)
set -euo pipefail
URL=${1:-http://localhost:8080}
curl -fsS "$URL/version"; echo
curl -fsS -XPOST "$URL/predict" -H 'content-type: application/json' \
  -d '{"instances":[[5.1,3.5,1.4,0.2],[6.7,3.0,5.2,2.3]]}'; echo
