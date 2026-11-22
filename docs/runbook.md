# Runbook: model-server

All commands assume `GCP_PROJECT` and `GCP_REGION` are exported (defaults in the justfile:
`zdml-demo-dev`, `europe-west1`). Dashboard: Cloud Monitoring > Dashboards > "model-server rollout".

## High error rate

Alert: `model-server: 5xx ratio above 5%`.

1. Open the dashboard and look at "5xx per second by revision".
2. If one revision is new and carries the errors, a canary should already be rolling it back.
   Check the running `deploy` workflow. If none is running, roll back manually (below).
3. If all revisions error at once, the cause is shared (dependency, quota, bad config):
   `gcloud run services logs read model-server --region $GCP_REGION --limit 100`.

## High latency

Alert: `model-server: p99 latency above 500ms`.

1. Check "p99 latency by revision". A single new revision: roll it back.
2. All revisions: look at instance count against `max_instances` (requests queue when capped)
   and at cold starts after scale to zero. Raise `max_instances` or `min_instances` in
   `envs/<env>/terraform.tfvars` through a pull request.

## Manual rollback

```bash
just rollback                       # list revisions, newest first
just rollback model-server-v0-2-0-12345   # 100% of traffic to that revision
```

This only moves traffic; nothing is redeployed, so it takes effect in seconds. Then find out
why the release was bad before tagging a fixed version (for example v0.2.1).

## Canary stuck or interrupted

A cancelled `deploy` workflow can leave traffic split (for example 20% new / 80% old).

1. `gcloud run services describe model-server --region $GCP_REGION --format 'yaml(status.traffic)'`
2. Move everything to the revision you trust: `just rollback <revision>`.
3. Re-run the release: re-run the `deploy` job, or dispatch `deploy.yml` with the same image.

If the canary failed as "inconclusive", the service did not get enough traffic in the step.
That is a rollback by design. In dev, keep `load: true`; in prod, release during traffic.

## Bad release reached 100%

The canary promoted it, so the thresholds did not catch the problem.

1. Roll back manually (above).
2. Add the missing signal to `tools/canary.py` and to the alerts in `modules/observability`, so
   the two keep using the same definition of "bad".

## Platform upgrades

Cloud Run has no cluster or node versions to upgrade. What does need upgrades:

- Base images: bump the pinned digests in `app/Dockerfile`, tag a release, let the canary judge.
- Terraform provider: bump `versions.tf`, run `just tf-check`, review the plan on the PR.
- GitHub Actions: bump the pinned commit SHAs.

## CI cannot authenticate to GCP

`google-github-actions/auth` failing with `permission denied on resource` usually means:

- The job is not running in the GitHub environment the identity is bound to (`dev` / `prod`).
- The repository was renamed: the WIF provider only accepts `TechTutter/zero-downtime-ml-serving`.
- Repository variables are stale: run `just gh-vars` again after `just bootstrap`.
