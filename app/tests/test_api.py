import pytest
from fastapi.testclient import TestClient

import train
from model_server import main

SETOSA = [5.1, 3.5, 1.4, 0.2]


@pytest.fixture(scope="session")
def model_dir(tmp_path_factory):
    out = tmp_path_factory.mktemp("model")
    train.train(out)
    return out


@pytest.fixture
def client(model_dir, monkeypatch):
    monkeypatch.setattr(main, "MODEL_DIR", model_dir)
    with TestClient(main.app) as c:
        yield c


def test_predict(client):
    r = client.post("/predict", json={"instances": [SETOSA]})
    assert r.status_code == 200
    assert r.json()["predictions"] == ["setosa"]


@pytest.mark.parametrize(
    "body",
    [{"instances": []}, {"instances": [[1.0, 2.0]]}, {"wrong": 1}],
)
def test_predict_rejects_bad_input(client, body):
    assert client.post("/predict", json=body).status_code == 422


def test_probes_and_version(client, model_dir):
    assert client.get("/healthz").status_code == 200
    assert client.get("/readyz").json() == {"ready": True}
    v = client.get("/version").json()
    assert v["version"] == "dev"
    assert len(v["model_sha256"]) == 64


def test_not_ready_after_shutdown(model_dir, monkeypatch):
    monkeypatch.setattr(main, "MODEL_DIR", model_dir)
    with TestClient(main.app):
        pass
    # After shutdown the lifespan flips readiness off.
    assert main.state["ready"] is False


def test_metrics_count_predictions(client):
    client.post("/predict", json={"instances": [SETOSA]})
    body = client.get("/metrics").text
    assert 'http_requests_total{code="200",handler="/predict",method="POST"}' in body
    assert "http_request_duration_seconds_bucket" in body
    assert 'handler="/metrics"' not in body


def test_fault_injection_errors(client, monkeypatch):
    monkeypatch.setattr(main, "FAULT_ERROR_RATE", 1.0)
    r = client.post("/predict", json={"instances": [SETOSA]})
    assert r.status_code == 500
    assert 'code="500",handler="/predict"' in client.get("/metrics").text


def test_fault_injection_latency(client, monkeypatch):
    monkeypatch.setattr(main, "FAULT_LATENCY_MS", 50)
    r = client.post("/predict", json={"instances": [SETOSA]})
    assert r.status_code == 200
    assert r.elapsed.total_seconds() >= 0.05
