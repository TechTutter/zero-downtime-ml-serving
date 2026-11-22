#!/usr/bin/env python3
"""Progressive canary on Cloud Run with automatic rollback.

Shifts traffic to a new revision step by step (default 20% -> 100%). After each step it
waits, then reads the new revision's error rate and p99 latency from Cloud Monitoring. Any bad or
inconclusive step sends 100% of traffic back to the previous revision and exits 1.

Only the standard library is used; gcloud provides credentials and changes traffic.

Usage:
  canary.py --project P --region R --service S --revision S-v0-2-0-abc12
"""

import argparse
import json
import subprocess
import sys
import time
import urllib.parse
import urllib.request
from dataclasses import dataclass
from datetime import UTC, datetime

MONITORING_URL = "https://monitoring.googleapis.com/v3/projects/{project}/timeSeries"


@dataclass(frozen=True)
class Thresholds:
    max_error_rate: float = 0.05
    max_p99_ms: float = 500
    min_requests: int = 50


@dataclass(frozen=True)
class Sample:
    requests: int
    errors: int
    p99_ms: float | None


def evaluate(sample: Sample, t: Thresholds) -> tuple[bool, str]:
    """Decide one step. Too little traffic is a failure: no evidence, no promotion."""
    if sample.requests < t.min_requests:
        return False, f"inconclusive: {sample.requests} requests < {t.min_requests} required"
    rate = sample.errors / sample.requests
    if rate > t.max_error_rate:
        return False, f"error rate {rate:.2%} > {t.max_error_rate:.2%}"
    if sample.p99_ms is not None and sample.p99_ms > t.max_p99_ms:
        return False, f"p99 {sample.p99_ms:.0f}ms > {t.max_p99_ms:.0f}ms"
    p99 = "n/a" if sample.p99_ms is None else f"{sample.p99_ms:.0f}ms"
    return True, f"healthy: {sample.requests} requests, error rate {rate:.2%}, p99 {p99}"


def parse_steps(raw: str) -> list[int]:
    steps = [int(s) for s in raw.split(",")]
    if steps != sorted(set(steps)) or steps[-1] != 100 or steps[0] <= 0:
        raise ValueError(f"steps must be strictly increasing, positive and end at 100: {raw}")
    return steps


def traffic_split(new: str, previous: str, weight: int) -> str:
    return f"{new}=100" if weight >= 100 else f"{new}={weight},{previous}={100 - weight}"


def stable_revision(service: dict, new: str) -> str:
    """The revision serving the most traffic that is not the one being rolled out."""
    targets = [t for t in service["status"]["traffic"] if t.get("revisionName") != new]
    if not targets:
        raise RuntimeError("no previous revision serves traffic; nothing to roll back to")
    return max(targets, key=lambda t: t.get("percent", 0))["revisionName"]


def count_requests(series: list[dict]) -> tuple[int, int]:
    """(total, 5xx) from request_count series grouped by response_code_class."""
    total = errors = 0
    for s in series:
        n = sum(int(p["value"]["int64Value"]) for p in s.get("points", []))
        total += n
        if s["metric"]["labels"].get("response_code_class") == "5xx":
            errors += n
    return total, errors


def max_point(series: list[dict]) -> float | None:
    values = [p["value"]["doubleValue"] for s in series for p in s.get("points", [])]
    return max(values) if values else None


# ---- side effects -------------------------------------------------------------------------


def gcloud(*args: str) -> str:
    return subprocess.run(["gcloud", *args], check=True, capture_output=True, text=True).stdout


def query(
    project: str,
    metric_filter: str,
    aligner: str,
    reducer: str,
    group_by: list[str],
    start: datetime,
    end: datetime,
) -> list[dict]:
    params = [
        ("filter", metric_filter),
        ("interval.startTime", start.strftime("%Y-%m-%dT%H:%M:%SZ")),
        ("interval.endTime", end.strftime("%Y-%m-%dT%H:%M:%SZ")),
        ("aggregation.alignmentPeriod", "60s"),
        ("aggregation.perSeriesAligner", aligner),
        ("aggregation.crossSeriesReducer", reducer),
    ] + [("aggregation.groupByFields", g) for g in group_by]
    url = MONITORING_URL.format(project=project) + "?" + urllib.parse.urlencode(params)
    token = gcloud("auth", "print-access-token").strip()
    # Fixed https URL built above, never user supplied.
    req = urllib.request.Request(url, headers={"Authorization": f"Bearer {token}"})  # noqa: S310
    with urllib.request.urlopen(req, timeout=30) as resp:  # noqa: S310
        return json.load(resp).get("timeSeries", [])


def sample(project: str, service: str, revision: str, start: datetime) -> Sample:
    end = datetime.now(UTC)
    scope = (
        'resource.type = "cloud_run_revision" '
        f'AND resource.labels.service_name = "{service}" '
        f'AND resource.labels.revision_name = "{revision}"'
    )
    counts = query(
        project,
        f'{scope} AND metric.type = "run.googleapis.com/request_count"',
        "ALIGN_DELTA",
        "REDUCE_SUM",
        ["metric.labels.response_code_class"],
        start,
        end,
    )
    latency = query(
        project,
        f'{scope} AND metric.type = "run.googleapis.com/request_latencies"',
        "ALIGN_PERCENTILE_99",
        "REDUCE_MAX",
        [],
        start,
        end,
    )
    total, errors = count_requests(counts)
    return Sample(requests=total, errors=errors, p99_ms=max_point(latency))


def main() -> int:
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawTextHelpFormatter)
    ap.add_argument("--project", required=True)
    ap.add_argument("--region", required=True)
    ap.add_argument("--service", required=True)
    ap.add_argument("--revision", required=True, help="new revision, deployed with --no-traffic")
    ap.add_argument("--steps", default="20,100", help="traffic percentages, ending at 100")
    ap.add_argument(
        "--step-seconds",
        type=int,
        default=300,
        help="wait per step; Cloud Monitoring lags 1-3 minutes",
    )
    ap.add_argument("--max-error-rate", type=float, default=Thresholds.max_error_rate)
    ap.add_argument("--max-p99-ms", type=float, default=Thresholds.max_p99_ms)
    ap.add_argument("--min-requests", type=int, default=Thresholds.min_requests)
    a = ap.parse_args()

    thresholds = Thresholds(a.max_error_rate, a.max_p99_ms, a.min_requests)
    loc = ["--project", a.project, "--region", a.region]
    service = json.loads(gcloud("run", "services", "describe", a.service, *loc, "--format=json"))
    previous = stable_revision(service, a.revision)
    print(f"canary {a.revision}, rollback target {previous}", flush=True)

    for weight in parse_steps(a.steps):
        split = traffic_split(a.revision, previous, weight)
        gcloud(
            "run", "services", "update-traffic", a.service, *loc, "--to-revisions", split, "--quiet"
        )
        step_start = datetime.now(UTC)
        print(f"[{weight:>3}%] traffic {split}, observing for {a.step_seconds}s", flush=True)
        time.sleep(a.step_seconds)

        ok, reason = evaluate(sample(a.project, a.service, a.revision, step_start), thresholds)
        print(f"[{weight:>3}%] {reason}", flush=True)
        if not ok:
            gcloud(
                "run",
                "services",
                "update-traffic",
                a.service,
                *loc,
                "--to-revisions",
                f"{previous}=100",
                "--quiet",
            )
            print(f"ROLLED BACK: 100% traffic on {previous}", flush=True)
            return 1

    print(f"PROMOTED: 100% traffic on {a.revision}", flush=True)
    return 0


if __name__ == "__main__":
    sys.exit(main())
