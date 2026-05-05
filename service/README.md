# observatory-svc - instrumented sample service

The small FastAPI service that the observability stack observes. It emits the golden-signal Prometheus metrics and OpenTelemetry traces.

## Endpoints

| Method / path   | Purpose                                                    |
| --------------- | ---------------------------------------------------------- |
| GET /           | cheap OK root                                              |
| GET /health     | health probe                                               |
| GET /work?ms=   | sleeps "ms" milliseconds then returns (latency signal)     |
| GET /flaky      | fails ~20% of the time with HTTP 500 (error signal)        |
| GET /metrics    | Prometheus exposition                                      |

## Metrics (golden signals)

Provided by [prometheus-fastapi-instrumentator](https://github.com/trallnag/prometheus-fastapi-instrumentator):

- http_requests_total - request counter, labeled by method / handler / status.
- http_request_duration_seconds - latency histogram (_bucket/_sum/_count).

## Tracing

FastAPI is instrumented with OpenTelemetry and exports spans over OTLP/HTTP to the collector. Configured via env:

- OTEL_EXPORTER_OTLP_ENDPOINT (default http://otel-collector:4318)
- OTEL_SERVICE_NAME (default observatory-svc)

## Local development

```bash
uv sync --extra dev
uv run uvicorn svc.main:app --reload    # http://localhost:8000
uv run pytest                           # tests
uv run ruff check . && uv run mypy .    # lint + types
uv run python scripts/load.py --n 300   # generate telemetry
```

## Docker

```bash
docker build -t observatory-svc ./service
docker run -p 8000:8000 observatory-svc
```

## Maintainer

Yeshwanth Reddy Aleti is a Network Engineer with over 4 years of experience specializing in enterprise network infrastructure and performance monitoring. This project is maintained to demonstrate best practices in service instrumentation, telemetry, and resilient architecture.

Contact:
- Email: yeshwanth.ra61@gmail.com
- Skills: Python, PowerShell, Bash