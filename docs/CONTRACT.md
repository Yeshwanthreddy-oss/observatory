# observatory — build contract (source of truth for the swarm)

"One command stands up cloud infrastructure that's monitored and self-documenting."
Reproducible IaC (Terraform against **LocalStack**, so it runs with no cloud
account) + a full **observability stack** (Prometheus + Grafana + Jaeger +
OpenTelemetry) over an instrumented sample service, with golden-signal dashboards.

Everything must run **locally with Docker only** — no cloud account, no keys.
Honest scoping: LocalStack Community emulates AWS locally; the Terraform provisions
what Community supports (VPC/subnets/SG, IAM, ECR, CloudWatch log groups, S3, and a
**Lambda** as the deployable sample resource). ECS/Fargate config may be included
but must be gated/documented as requiring LocalStack Pro or real AWS — never let it
break `terraform apply` against Community.

Conventions: keep each component self-contained. Pin image tags. No secrets.

## Agent S — instrumented sample service  (dir: service/)

A small Python (uv) FastAPI service that is the thing being observed.
- Endpoints: `GET /` (ok), `GET /health`, `GET /work?ms=` (sleeps a variable time
  then returns — for latency), `GET /flaky` (fails ~20% with 500 — for errors),
  and `GET /metrics` (Prometheus exposition).
- **Prometheus metrics** (the golden signals): a request counter labeled by
  method/path/status and a latency **histogram** — use
  `prometheus-fastapi-instrumentator` (exposes `http_request_duration_seconds` +
  `http_requests_total`). Confirm `/metrics` returns them.
- **OpenTelemetry tracing**: instrument FastAPI with OTel, export OTLP to the
  collector at `http://otel-collector:4318` (endpoint from env
  `OTEL_EXPORTER_OTLP_ENDPOINT`, default that). Service name `observatory-svc`
  via `OTEL_SERVICE_NAME`.
- `Dockerfile` (python:3.12-slim + uv) running uvicorn on :8000.
- pyproject with deps (fastapi, uvicorn, prometheus-fastapi-instrumentator,
  opentelemetry-distro/sdk/exporter-otlp-proto-http, opentelemetry-instrumentation-fastapi),
  dev (pytest, httpx, ruff, mypy). Tests: endpoints return expected codes,
  `/metrics` exposes the histogram + counter, `/flaky` can 500. ruff+mypy clean.
- `scripts/load.py` (or a Make target): fire N requests across the endpoints to
  generate telemetry for the dashboards.
Files: everything under `service/` + `service/Dockerfile`.

## Agent O — observability stack  (dir: observability/ + root docker-compose.yml)

`docker-compose.yml` at the repo ROOT wiring, with pinned tags:
- `service` (build ./service), env `OTEL_EXPORTER_OTLP_ENDPOINT=http://otel-collector:4318`,
  `OTEL_SERVICE_NAME=observatory-svc`. port 8000.
- `otel-collector` (otel/opentelemetry-collector-contrib) with
  `observability/otel-collector.yaml`: receive OTLP (4317/4318), export traces to
  Jaeger (OTLP), expose collector metrics. 
- `jaeger` (jaegertracing/all-in-one) UI on 16686, OTLP enabled.
- `prometheus` (prom/prometheus) with `observability/prometheus/prometheus.yml`
  scraping the service `/metrics` (target `service:8000`) and the collector. UI 9090.
- `grafana` (grafana/grafana) on 3000, anonymous admin viewer enabled, with
  **provisioning**: `observability/grafana/provisioning/datasources/*.yml`
  (Prometheus + Jaeger datasources) and
  `observability/grafana/provisioning/dashboards/*.yml` loading dashboard JSON
  from `observability/grafana/dashboards/`.
- A **golden-signals dashboard** JSON (`observability/grafana/dashboards/golden-signals.json`):
  panels for Request rate (req/s from `rate(http_requests_total[1m])`), Error rate
  (5xx ratio), Latency p50/p95/p99 (`histogram_quantile` over
  `http_request_duration_seconds_bucket`), and in-flight/throughput. Must load
  cleanly and reference the Prometheus datasource by name.
`depends_on` wired so `docker compose up` brings the whole stack up.

## Agent T — Terraform / IaC  (dir: terraform/)

Modular Terraform that `terraform apply`s against **LocalStack** (endpoint
`http://localhost:4566`, dummy creds, the skip_* flags, `s3_use_path_style=true`).
- `terraform/providers.tf`: aws provider pointed at LocalStack endpoints for the
  services used (s3, ec2, iam, ecr, logs, lambda, sts).
- `modules/network`: a VPC + 2 subnets + a security group, with outputs.
- `modules/platform`: an ECR repository, a CloudWatch log group, an S3 artifacts
  bucket, an IAM role for the Lambda, and a minimal **Lambda function** (inline/zip
  a trivial handler) as the deployable sample workload. Outputs the names/arns.
- `terraform/main.tf` wires the modules; `variables.tf`, `outputs.tf`.
- Must pass `terraform init` + `terraform validate` + `terraform fmt -check`.
  (The integrator will run a real `apply` against a running LocalStack.)
- A `terraform/README.md` note: emulated AWS via LocalStack; ECS/Fargate is the
  documented real-AWS upgrade path.

## Agent G — glue: scripts, CI, README skeleton

- `Makefile`: `up` (docker compose up -d --build), `down`, `load` (run the load
  script against localhost:8000), `tf-up` (start localstack container + terraform
  init/apply with the localstack env), `tf-down`, `test` (service tests),
  `lint` (ruff+mypy on service, terraform fmt/validate).
- `.github/workflows/ci.yml`: (1) service job — uv sync, ruff, mypy, pytest;
  (2) terraform job — setup terraform, `fmt -check`, `init -backend=false`,
  `validate`; (3) compose job — `docker compose config` to validate the stack.
- `README.md` skeleton with: what it is, the architecture (IaC + observability),
  quickstart (`make up`, `make load`, open Grafana :3000 / Jaeger :16686 / Prometheus
  :9090), a `docs/img/` slot for the Grafana + Jaeger screenshots (the INTEGRATOR
  adds real screenshots), the golden-signals explanation, the LocalStack scoping
  note, and "what I'd build next". `.gitignore` (terraform: .terraform/, *.tfstate*,
  .terraform.lock.hcl kept; python caches).

## Boundaries
- Agent S: service/. Agent O: observability/ + root docker-compose.yml. Agent T:
  terraform/. Agent G: Makefile, .github/, README.md, .gitignore, scripts/load
  belongs to S (service loadgen) — G's Make `load` target just invokes it.
- Pin all docker image tags. Nothing needs a cloud account or secret.
