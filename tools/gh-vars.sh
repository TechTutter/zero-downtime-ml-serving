#!/usr/bin/env bash
# Copy the bootstrap outputs into GitHub repository variables (needs gh auth).
set -euo pipefail
cd "$(dirname "$0")/../bootstrap"
terraform output -json github_variables | jq -r 'to_entries[] | "\(.key)\t\(.value)"' |
  while IFS=$'\t' read -r name value; do gh variable set "$name" --body "$value"; done
