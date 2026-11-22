# 0007. Workload Identity Federation, no service account keys

- Status: accepted
- Date: 2026-11-19

## Context

GitHub Actions needs to plan, apply and deploy on GCP. Service account JSON keys are long-lived
secrets that leak through logs, forks and laptops.

## Decision

Each project trusts GitHub's OIDC issuer through a WIF provider that only accepts tokens from
this repository. Three identities per environment:

- `tf-plan`: read-only, usable by any workflow of the repo (pull requests).
- `tf-apply`: manages the stack, usable only by jobs in the matching GitHub environment.
- `deployer`: ships revisions and reads metrics, also bound to the GitHub environment.

The prod environment requires a reviewer, so prod credentials only exist after an approval.

## Alternatives considered

- JSON keys in GitHub secrets: simple, but long-lived and copyable.
- One identity for everything: fewer bindings, but a pull request plan could apply to prod.

## Consequences

- No secret to rotate or leak; tokens live for minutes.
- Approval rules are enforced by GCP IAM, not only by the workflow file.
- Bootstrap is one manual apply with a human account.

## Interview notes

"CI gets short-lived tokens, scoped to this repository and, for anything that writes, to a
GitHub environment. A pull request can read the plan; only an approved prod job can change prod."
