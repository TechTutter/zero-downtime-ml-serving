"""Model server: predictions, health probes, version and Prometheus metrics."""

import json
import os
import random
import time
from contextlib import asynccontextmanager
from pathlib import Path

import joblib
from fastapi import FastAPI, HTTPException, Request, Response
from prometheus_client import CONTENT_TYPE_LATEST, Counter, Histogram, generate_latest
from pydantic import BaseModel, Field

MODEL_DIR = Path(os.environ.get("MODEL_DIR", "model"))
APP_VERSION = os.environ.get("APP_VERSION", "dev")
GIT_SHA = os.environ.get("GIT_SHA", "unknown")
# Fault injection for rollback demos. Applied to /predict only.
FAULT_ERROR_RATE = float(os.environ.get("FAULT_ERROR_RATE", "0"))
FAULT_LATENCY_MS = int(os.environ.get("FAULT_LATENCY_MS", "0"))

REQUESTS = Counter("http_requests_total", "HTTP requests", ["handler", "method", "code"])
LATENCY = Histogram(
    "http_request_duration_seconds",
    "HTTP request latency",
    ["handler", "method"],
    buckets=(0.005, 0.01, 0.025, 0.05, 0.1, 0.25, 0.5, 1, 2.5, 5),
)

state: dict = {"ready": False}


@asynccontextmanager
async def lifespan(_: FastAPI):
    state["model"] = joblib.load(MODEL_DIR / "model.joblib")
    state["metadata"] = json.loads((MODEL_DIR / "metadata.json").read_text())
    state["ready"] = True
    yield
    # Uvicorn stops accepting connections on SIGTERM and drains in-flight requests;
    # Kubernetes has already removed the pod from endpoints during preStop.
    state["ready"] = False


app = FastAPI(title="model-server", lifespan=lifespan)


@app.middleware("http")
async def observe(request: Request, call_next):
    start = time.perf_counter()
    code = 500
    try:
        response = await call_next(request)
        code = response.status_code
        return response
    finally:
        route = request.scope.get("route")
        handler = route.path if route else "unmatched"
        if handler != "/metrics":
            REQUESTS.labels(handler, request.method, str(code)).inc()
            LATENCY.labels(handler, request.method).observe(time.perf_counter() - start)


class PredictRequest(BaseModel):
    instances: list[list[float]] = Field(min_length=1, max_length=256)


class PredictResponse(BaseModel):
    predictions: list[str]
    version: str


@app.post("/predict", response_model=PredictResponse)
def predict(body: PredictRequest) -> PredictResponse:
    # Sync handler: runs in the threadpool so CPU-bound predict does not block the event loop.
    if any(len(row) != 4 for row in body.instances):
        raise HTTPException(422, "each instance needs 4 features")
    if FAULT_LATENCY_MS:
        time.sleep(FAULT_LATENCY_MS / 1000)
    if FAULT_ERROR_RATE and random.random() < FAULT_ERROR_RATE:
        raise HTTPException(500, "injected fault")
    classes = state["metadata"]["classes"]
    labels = state["model"].predict(body.instances)
    return PredictResponse(predictions=[classes[i] for i in labels], version=APP_VERSION)


@app.get("/healthz")
def healthz() -> dict:
    return {"status": "ok"}


@app.get("/readyz")
def readyz(response: Response) -> dict:
    if not state["ready"]:
        response.status_code = 503
    return {"ready": state["ready"]}


@app.get("/version")
def version() -> dict:
    return {
        "version": APP_VERSION,
        "git_sha": GIT_SHA,
        "model_sha256": state["metadata"]["sha256"],
        "model_accuracy": state["metadata"]["accuracy"],
    }


@app.get("/metrics")
def metrics() -> Response:
    return Response(generate_latest(), media_type=CONTENT_TYPE_LATEST)
