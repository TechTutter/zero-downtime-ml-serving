# 0003. Progressive canary with Cloud Run traffic splitting

- Status: accepted
- Date: 2026-11-21

## Context

A model version can be healthy at startup and still be worse in production: more errors or
slower predictions. Health checks do not catch that; real traffic does.

## Decision

Deploy every release as a revision with no traffic, then move 10% -> 50% -> 100% of traffic to
it. After each step `tools/canary.py` reads the new revision's 5xx ratio and p99 latency from
Cloud Monitoring. A bad or inconclusive step sends 100% back to the previous revision.

## Alternatives considered

- Blue-green (0% -> 100%): simple and instant rollback, but every user hits a bad version at
  once, and the decision is made with no production evidence.
- Rolling update with health checks only: catches crashes, not degraded behavior.

## Consequences

- Blast radius of a bad release is about the first step's weight (10%) for one step.
- A release takes about 15 minutes because Cloud Monitoring metrics lag 1-3 minutes.
- Low traffic means no evidence; the script treats that as a failure on purpose.
- Old revisions keep running until traffic leaves them, so no request is dropped in the switch.

## Interview notes

"Blue-green tells you whether the new version starts. A canary tells you whether it behaves.
I limit exposure to 10%, judge on the same SLIs that page on-call, and fail safe when there is
not enough traffic to decide."
