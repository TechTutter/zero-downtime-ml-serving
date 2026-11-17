#!/usr/bin/env bash
# terraform fmt, validate (no backend) and, for modules, terraform test.
set -euo pipefail
cd "$(dirname "$0")/.."
terraform fmt -check -recursive
for dir in bootstrap modules/* envs/*; do
  echo "== $dir"
  terraform -chdir="$dir" init -backend=false -input=false >/dev/null
  terraform -chdir="$dir" validate -no-color
  if [[ -d $dir/tests ]]; then terraform -chdir="$dir" test -no-color; fi
done
