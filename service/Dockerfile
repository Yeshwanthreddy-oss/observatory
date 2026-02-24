# syntax=docker/dockerfile:1

# Pinned base image tag (contract: python:3.12-slim + uv).
FROM python:3.12.8-slim-bookworm

# Pinned uv binary copied from the official Astral image.
COPY --from=ghcr.io/astral-sh/uv:0.5.11 /uv /uvx /usr/local/bin/

ENV UV_COMPILE_BYTECODE=1 \
    UV_LINK_MODE=copy \
    UV_PROJECT_ENVIRONMENT=/app/.venv \
    PATH="/app/.venv/bin:$PATH" \
    PYTHONUNBUFFERED=1

WORKDIR /app

# Install dependencies first (better layer caching), then the project.
COPY pyproject.toml README.md ./
COPY src ./src
RUN uv sync --no-dev --frozen || uv sync --no-dev

# OTLP export target inside the compose network (overridable at runtime).
ENV OTEL_EXPORTER_OTLP_ENDPOINT=http://otel-collector:4318 \
    OTEL_SERVICE_NAME=observatory-svc

EXPOSE 8000

CMD ["uvicorn", "svc.main:app", "--host", "0.0.0.0", "--port", "8000"]
