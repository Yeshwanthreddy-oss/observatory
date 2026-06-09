"""OpenTelemetry tracing setup.

Configures a global tracer provider that exports spans over OTLP/HTTP to the
collector. The endpoint is read from ``OTEL_EXPORTER_OTLP_ENDPOINT`` (default
``http://otel-collector:4318``) and the service name from ``OTEL_SERVICE_NAME``
(default ``observatory-svc``).

Export failures (e.g. the collector being unreachable during local unit tests)
are handled by the SDK's background batch processor and never crash the app, so
the same code path is safe in CI and in the full docker-compose stack.
"""

from __future__ import annotations

import os

from fastapi import FastAPI
from opentelemetry import trace
from opentelemetry.exporter.otlp.proto.http.trace_exporter import OTLPSpanExporter
from opentelemetry.instrumentation.fastapi import FastAPIInstrumentor
from opentelemetry.sdk.resources import SERVICE_NAME, Resource
from opentelemetry.sdk.trace import TracerProvider
from opentelemetry.sdk.trace.export import BatchSpanProcessor

DEFAULT_OTLP_ENDPOINT = "http://otel-collector:4318"
DEFAULT_SERVICE_NAME = "observatory-svc"

_configured = False


def _sdk_disabled() -> bool:
    """Honor the standard ``OTEL_SDK_DISABLED`` flag (used by tests/CI)."""
    return os.getenv("OTEL_SDK_DISABLED", "").strip().lower() in {"1", "true", "yes"}


def setup_tracing(app: FastAPI) -> None:
    """Install a global OTLP tracer provider and instrument the FastAPI app.

    Idempotent: repeated calls (e.g. across test app factories) are no-ops.
    If ``OTEL_SDK_DISABLED`` is set, no exporter is installed (spans fall through
    to the no-op default provider) so unit tests never touch the network.
    """
    global _configured

    if _sdk_disabled():
        FastAPIInstrumentor.instrument_app(app)
        return

    if not _configured:
        service_name = os.getenv("OTEL_SERVICE_NAME", DEFAULT_SERVICE_NAME)
        endpoint = os.getenv("OTEL_EXPORTER_OTLP_ENDPOINT", DEFAULT_OTLP_ENDPOINT)

        resource = Resource.create({SERVICE_NAME: service_name})
        provider = TracerProvider(resource=resource)
        # OTLP/HTTP traces are posted to the ``/v1/traces`` path under the base endpoint.
        exporter = OTLPSpanExporter(endpoint=f"{endpoint.rstrip('/')}/v1/traces")
        provider.add_span_processor(BatchSpanProcessor(exporter))
        trace.set_tracer_provider(provider)
        _configured = True

    # FastAPIInstrumentor is safe to call once per app instance.
    FastAPIInstrumentor.instrument_app(app)
