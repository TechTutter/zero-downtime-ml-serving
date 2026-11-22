# Task runner. Each recipe is a thin wrapper around a script in tools/.
# Run `just` to list recipes by group.

set shell := ["bash", "-euo", "pipefail", "-c"]

project := env("GCP_PROJECT", "zdml-demo-dev")
region := env("GCP_REGION", "europe-west1")
service := "model-server"

# List all recipes
default:
    @just --list --unsorted

# Build the image and run it on localhost:8080 (tools/build.sh + tools/run-local.sh)
[group('local')]
up version="dev":
    tools/run-local.sh "$(tools/build.sh {{version}})"

# Stop and remove the local container (docker)
[group('local')]
down:
    docker rm -f model-server >/dev/null

# Call /version and /predict (tools/smoke.sh)
[group('local')]
smoke url="http://localhost:8080":
    tools/smoke.sh {{url}}

# Graceful shutdown test: SIGTERM must not drop in-flight requests (tools/drain-test.sh)
[group('local')]
drain-test:
    tools/drain-test.sh "$(tools/build.sh)"

# Constant k6 load against a URL, fails on any error (tools/load.sh)
[group('local')]
load url="http://localhost:8080" rate="20" duration="1m":
    tools/load.sh {{url}} {{rate}} {{duration}}

# Lint and test the model server and the canary logic (ruff + pytest)
[group('app')]
test:
    cd app && uv run ruff check . ../tools && uv run ruff format --check . ../tools && uv run pytest -q && uv run pytest -q ../tools/tests

# terraform fmt, validate and module tests (tools/tf-check.sh)
[group('infra')]
tf-check:
    tools/tf-check.sh

# tflint across all Terraform roots with the google ruleset
[group('infra')]
tf-lint:
    tflint --init && tflint --recursive --config "$PWD/.tflint.hcl"

# One-time bootstrap: projects, WIF, CI service accounts (terraform, local state)
[group('infra')]
bootstrap:
    terraform -chdir=bootstrap init && terraform -chdir=bootstrap apply

# Copy bootstrap outputs into GitHub repository variables (tools/gh-vars.sh)
[group('infra')]
gh-vars:
    tools/gh-vars.sh

# Plan an environment against its remote state (terraform)
[group('infra')]
plan env="dev":
    terraform -chdir=envs/{{env}} init -backend-config="bucket=zdml-demo-{{env}}-tfstate" && terraform -chdir=envs/{{env}} plan

# Deploy an image by digest as a no-traffic revision on Cloud Run (tools/deploy.sh)
[group('release')]
deploy image version error_rate="0" latency_ms="0":
    tools/deploy.sh {{project}} {{region}} {{service}} {{image}} {{version}} {{error_rate}} {{latency_ms}}

# Progressive canary 20% then 100% with automatic rollback (tools/canary.py)
[group('release')]
canary revision:
    tools/canary.py --project {{project}} --region {{region}} --service {{service}} --revision {{revision}}

# List revisions, or send 100% traffic to one (tools/rollback.sh)
[group('release')]
rollback revision="":
    tools/rollback.sh {{project}} {{region}} {{service}} {{revision}}

# Verify the cosign signature of an image (tools/verify-signature.sh)
[group('release')]
verify image:
    tools/verify-signature.sh {{image}}
