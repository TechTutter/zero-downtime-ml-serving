import sys
from pathlib import Path

import pytest

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))
import canary  # noqa: E402
from canary import Sample, Thresholds  # noqa: E402

T = Thresholds(max_error_rate=0.05, max_p99_ms=500, min_requests=50)


@pytest.mark.parametrize(
    ("sample", "ok", "reason"),
    [
        (Sample(requests=1000, errors=3, p99_ms=120), True, "healthy"),
        (Sample(requests=1000, errors=0, p99_ms=None), True, "healthy"),
        (Sample(requests=1000, errors=60, p99_ms=120), False, "error rate"),
        (Sample(requests=1000, errors=0, p99_ms=900), False, "p99"),
        (Sample(requests=10, errors=0, p99_ms=50), False, "inconclusive"),
    ],
)
def test_evaluate(sample, ok, reason):
    got_ok, got_reason = canary.evaluate(sample, T)
    assert got_ok is ok
    assert reason in got_reason


def test_error_rate_at_threshold_passes():
    assert canary.evaluate(Sample(requests=100, errors=5, p99_ms=10), T)[0]


@pytest.mark.parametrize("raw", ["50,10,100", "10,50", "0,100", "10,10,100"])
def test_parse_steps_rejects_bad_plans(raw):
    with pytest.raises(ValueError):
        canary.parse_steps(raw)


def test_parse_steps():
    assert canary.parse_steps("10,50,100") == [10, 50, 100]


def test_traffic_split():
    assert canary.traffic_split("new", "old", 10) == "new=10,old=90"
    assert canary.traffic_split("new", "old", 100) == "new=100"


def test_stable_revision_ignores_the_canary():
    service = {
        "status": {
            "traffic": [
                {"revisionName": "svc-new", "percent": 10},
                {"revisionName": "svc-old", "percent": 90},
            ]
        }
    }
    assert canary.stable_revision(service, "svc-new") == "svc-old"


def test_stable_revision_requires_a_previous_revision():
    service = {"status": {"traffic": [{"revisionName": "svc-new", "percent": 100}]}}
    with pytest.raises(RuntimeError):
        canary.stable_revision(service, "svc-new")


def _series(code_class, *values):
    return {
        "metric": {"labels": {"response_code_class": code_class}},
        "points": [{"value": {"int64Value": str(v)}} for v in values],
    }


def test_count_requests():
    series = [_series("2xx", 100, 80), _series("5xx", 7, 3), _series("4xx", 5)]
    assert canary.count_requests(series) == (195, 10)


def test_count_requests_empty():
    assert canary.count_requests([]) == (0, 0)


def test_max_point():
    series = [{"points": [{"value": {"doubleValue": 120.5}}, {"value": {"doubleValue": 300.0}}]}]
    assert canary.max_point(series) == 300.0
    assert canary.max_point([]) is None
