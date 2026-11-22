# 0006. Terraform owns infrastructure, CI owns revisions

- Status: accepted
- Date: 2026-11-20

## Context

Both Terraform and the release pipeline touch the Cloud Run service. If both manage the image
and traffic, every `terraform apply` would undo a release or fight a canary in progress.

## Decision

Terraform creates the service shape: identity, scaling, probes, resources, IAM. It deploys a
placeholder image once and then ignores `image`, `env`, `traffic` and revision fields
(`lifecycle.ignore_changes`). Releases are done only by the pipeline (`tools/deploy.sh`,
`tools/canary.py`).

## Alternatives considered

- Terraform deploys releases (image digest as a variable): one tool, but a canary is a process
  over time, not a desired state, and an apply during a rollout would reset the split.
- No Terraform for the service: fast, but then IAM and scaling drift without review.

## Consequences

- `terraform plan` stays clean between releases.
- Changing probes or resources is a Terraform change that the next revision inherits.
- The current image is visible in Cloud Run and in the deploy summary, not in Terraform state.

## Interview notes

"State belongs in Terraform, process belongs in the pipeline. A canary changes traffic every
few minutes, so I draw the line at the revision and make Terraform ignore what it does not own."
