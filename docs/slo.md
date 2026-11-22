# Service level objectives: model-server

## SLIs

| SLI | Definition | Source |
|---|---|---|
| Availability | Requests that do not return 5xx, divided by all requests | `run.googleapis.com/request_count` by `response_code_class` |
| Latency | p99 of request latency, measured at the Cloud Run front end | `run.googleapis.com/request_latencies` |

Both are measured by the platform, outside the container, so a crashed or frozen instance still
counts against the SLI.

## Objectives

| SLO | Target | Window |
|---|---|---|
| Availability | 99.5% | rolling 28 days (`google_monitoring_slo.availability`) |
| Latency | p99 below 500 ms | alert after 5 minutes above |

## Error budget

0.5% of requests over 28 days. At a steady 20 requests per second that is
20 x 86,400 x 28 x 0.005, about 242,000 failed requests.

A degraded canary at 20% weight that fails half of its requests burns about 10% of traffic for
one canary step (about 5 minutes): roughly 6,000 requests, about 2.5% of the budget. That
is the cost of a bad release being caught, and the reason the first step is small.

## How the SLOs are used

- **Releases:** `tools/canary.py` uses a stricter, per-revision version of the same SLIs:
  5xx ratio above 5% or p99 above 500 ms on the new revision fails the step.
- **Alerts:** `modules/observability` pages on the same thresholds over all revisions.
- **Budget policy:** if less than 25% of the budget is left, only fixes and rollbacks ship
  until the window recovers.
