# 0001. Cloud Run instead of GKE

- Status: accepted
- Date: 2026-11-19

## Context

The service is one stateless HTTP container. The goal is safe releases (no lost requests,
automatic rollback), not running a cluster. The team is small and the budget is a free trial.

## Decision

Run the model server on Cloud Run. Use its revisions and traffic splitting for the canary.

## Alternatives considered

- GKE Standard with Argo CD and Argo Rollouts: full control and the usual Kubernetes canary
  tooling, but a cluster, an ingress controller, a metrics stack and a GitOps controller to
  operate and upgrade. That is most of the work and none of it is the product.
- GKE Autopilot: less node work, same Kubernetes surface.

## Consequences

- No nodes, no cluster upgrades, scale to zero in dev. Rollout primitives come from the platform.
- The canary cannot be reproduced locally or in CI; it is proven live on dev.
- Fewer knobs: no sidecars, no custom traffic rules beyond percentages and tags.
- Revisit when there are many services that share platform concerns, or when GPU serving,
  long-lived connections or custom networking are needed.

## Interview notes

"One stateless container does not justify a cluster. Cloud Run gives me revisions and weighted
traffic out of the box, so I spent the effort on the release process instead of on operating
Kubernetes. If we grew to many services or needed GPUs, I would revisit GKE."
