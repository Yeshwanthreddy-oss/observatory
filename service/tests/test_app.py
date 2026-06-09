"""Endpoint and metrics tests for the sample service."""

from __future__ import annotations

import pytest
from fastapi.testclient import TestClient

from svc.main import app


@pytest.fixture(scope="module")
def client() -> TestClient:
    return TestClient(app)


def test_root_ok(client: TestClient) -> None:
    resp = client.get("/")
    assert resp.status_code == 200
    assert resp.json()["status"] == "ok"


def test_health_ok(client: TestClient) -> None:
    resp = client.get("/health")
    assert resp.status_code == 200
    assert resp.json() == {"status": "healthy"}


def test_work_sleeps_and_returns(client: TestClient) -> None:
    resp = client.get("/work", params={"ms": 5})
    assert resp.status_code == 200
    body = resp.json()
    assert body["status"] == "done"
    assert body["slept_ms"] == 5


def test_work_rejects_out_of_range(client: TestClient) -> None:
    resp = client.get("/work", params={"ms": -1})
    assert resp.status_code == 422


def test_flaky_can_succeed(client: TestClient, monkeypatch: pytest.MonkeyPatch) -> None:
    monkeypatch.setattr("svc.main.random.random", lambda: 0.99)
    resp = client.get("/flaky")
    assert resp.status_code == 200
    assert resp.json()["status"] == "ok"


def test_flaky_can_fail_500(client: TestClient, monkeypatch: pytest.MonkeyPatch) -> None:
    monkeypatch.setattr("svc.main.random.random", lambda: 0.0)
    resp = client.get("/flaky")
    assert resp.status_code == 500


def test_metrics_exposes_counter_and_histogram(client: TestClient) -> None:
    # Generate at least one request so the metrics have samples.
    client.get("/")
    client.get("/work", params={"ms": 1})

    resp = client.get("/metrics")
    assert resp.status_code == 200
    body = resp.text

    # The golden-signal request counter (labeled by method/handler/status).
    assert "http_requests_total" in body
    # The latency histogram exposes _bucket / _count / _sum series.
    assert "http_request_duration_seconds_bucket" in body
    assert "http_request_duration_seconds_count" in body
