# 0002. One GCP project per environment

- Status: accepted
- Date: 2026-11-19

## Context

dev and prod need different access rules, budgets and blast radius. A mistake in dev must not
be able to touch prod.

## Decision

`bootstrap/` creates one project per environment (`<prefix>-dev`, `<prefix>-prod`), each with
its own state bucket, WIF pool, CI identities and budget.

## Alternatives considered

- One project with name prefixes: cheaper to set up, but IAM, quotas and billing are shared and
  every binding has to be scoped by hand.
- A folder hierarchy under an organization: the right next step for a company, not available
  on a personal free-trial account.

## Consequences

- IAM is simple: a role on the dev project cannot reach prod.
- Cost and quota are visible per environment.
- Cross-environment access is explicit (the prod deployer reads the dev registry, see 0004).

## Interview notes

"The project is the strongest isolation boundary GCP gives you for IAM, quota and billing.
One per environment means a dev credential simply has no path to prod."
