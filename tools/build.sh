#!/usr/bin/env bash
# Build the model server image once and print its local tag.
# Usage: tools/build.sh [version]   (default: dev)
set -euo pipefail
cd "$(dirname "$0")/.."

VERSION=${1:-dev}
GIT_SHA=$(git rev-parse --short=12 HEAD)
TAG="model-server:${VERSION}"
docker build -q --build-arg GIT_SHA="$GIT_SHA" --build-arg APP_VERSION="$VERSION" -t "$TAG" app >/dev/null
echo "$TAG"
