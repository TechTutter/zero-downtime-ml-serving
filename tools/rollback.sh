#!/usr/bin/env bash
# Manual rollback: send 100% of traffic to a revision. Without one, list the candidates.
# Usage: tools/rollback.sh <project> <region> <service> [revision]
set -euo pipefail
PROJECT=${1:?project}
REGION=${2:?region}
SERVICE=${3:?service}
LOC=(--project "$PROJECT" --region "$REGION")
if [[ -z ${4:-} ]]; then
  gcloud run revisions list --service "$SERVICE" "${LOC[@]}" \
    --format 'table(metadata.name, metadata.creationTimestamp, status.conditions[0].status)'
  exit 0
fi
gcloud run services update-traffic "$SERVICE" "${LOC[@]}" --to-revisions "$4=100" --quiet
gcloud run services describe "$SERVICE" "${LOC[@]}" --format 'yaml(status.traffic)'
