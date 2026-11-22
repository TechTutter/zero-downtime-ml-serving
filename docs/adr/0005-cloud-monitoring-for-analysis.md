# 0005. Cloud Monitoring built-in metrics for canary analysis

- Status: accepted
- Date: 2026-11-21

## Context

The canary needs error rate and p99 latency per revision. The app also exposes Prometheus
metrics on `/metrics`.

## Decision

Use Cloud Run's built-in metrics in Cloud Monitoring (`run.googleapis.com/request_count` and
`request_latencies`, labelled by revision). Alerts, the SLO and the dashboard use the same
metrics, so the canary and on-call agree on what "bad" means.

## Alternatives considered

- Self-hosted Prometheus: there is no cluster to host it, and scraping Cloud Run instances that
  scale to zero is awkward.
- Google Managed Prometheus with a sidecar: works, but adds a collector per revision to get
  numbers the platform already records.

## Consequences

- No metrics infrastructure to run or pay for; the data is measured at the load balancer, so it
  includes requests the container never saw.
- 1-3 minutes of ingestion delay, which sets the length of each canary step.
- `/metrics` stays for local debugging and for a future move to Prometheus.

## Interview notes

"I measure the canary at the edge, with the same signals that page on-call. Running my own
Prometheus would only duplicate what the platform already counts, with more moving parts."
