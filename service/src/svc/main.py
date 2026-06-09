"""FastAPI application: the instrumented sample service being observed.

Endpoints
---------
- ``GET /``        liveness-ish "ok" root
- ``GET /health``  health probe
- ``GET /work``    sleeps ``ms`` milliseconds then returns (latency signal)
- ``GET /flaky``   fails ~20%% of the time with HTTP 500 (error signal)
- ``GET /metrics`` Prometheus exposition (added by the instrumentator)

Golden-signal metrics are provided by ``prometheus-fastapi-instrumentator``,
which exposes ``http_requests_total`` (counter, labeled by method/handler/status)
and ``http_request_duration_seconds`` (histogram). Distributed tracing is wired
in :mod:`svc.telemetry`.
"""

from __future__ import annotations

import asyncio
import random

from fastapi import FastAPI, HTTPException, Query
from prometheus_fastapi_instrumentator import Instrumentator

from svc.telemetry import setup_tracing

FLAKY_FAILURE_RATE = 0.2
MAX_WORK_MS = 10_000


def create_app() -> FastAPI:
    """Build and configure the FastAPI application."""
    app = FastAPI(
        title="observatory-svc",
        version="0.1.0",
        description="Instrumented sample service for the observatory stack.",
    )

    @app.get("/")
    async def root() -> dict[str, str]:
        """Root endpoint — cheap OK response."""
        return {"status": "ok", "service": "observatory-svc"}

    @app.get("/health")
    async def health() -> dict[str, str]:
        """Health probe."""
        return {"status": "healthy"}

    @app.get("/work")
    async def work(
        ms: int = Query(default=100, ge=0, le=MAX_WORK_MS, description="sleep time in ms"),
    ) -> dict[str, int | str]:
        """Sleep ``ms`` milliseconds then return — generates latency for the histogram."""
        await asyncio.sleep(ms / 1000)
        return {"status": "done", "slept_ms": ms}

    @app.get("/flaky")
    async def flaky() -> dict[str, str]:
        """Fail ~20%% of the time with HTTP 500 — generates errors for the error rate."""
        if random.random() < FLAKY_FAILURE_RATE:
            raise HTTPException(status_code=500, detail="unlucky")
        return {"status": "ok"}

    # Prometheus: exposes /metrics with http_requests_total + http_request_duration_seconds.
    Instrumentator().instrument(app).expose(app, endpoint="/metrics", include_in_schema=False)

    # OpenTelemetry: OTLP/HTTP trace export + FastAPI instrumentation.
    setup_tracing(app)

    return app


app = create_app()
