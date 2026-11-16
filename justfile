# Task runner. Each recipe is a thin wrapper around a script in tools/.
# Run `just` to list recipes by group.

set shell := ["bash", "-euo", "pipefail", "-c"]

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

# Lint and test the model server (ruff + pytest)
[group('app')]
test:
    cd app && uv run ruff check . && uv run ruff format --check . && uv run pytest -q
