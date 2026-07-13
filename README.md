# observatory

**One command stands up cloud infrastructure that's monitored and self-documenting.**

Reproducible Infrastructure-as-Code (Terraform against [LocalStack](https://localstack.cloud/),
so it runs with **no cloud account and no keys**) plus a full **observability stack**
— Prometheus + Grafana + Jaeger + OpenTelemetry — over an instrumented sample
service, with golden-signal dashboards. Everything runs locally with Docker only.

---

## What it is

Two halves that share one story — *provision it, then watch it*:

1. **IaC (Terraform / LocalStack).** Modular Terraform provisions an AWS-shaped
   environment against LocalStack — a local AWS emulator, no cloud spend, fully
   reproducible. The default `terraform apply` creates the **Community-supported**
   resources: a VPC + subnets + security group, an IAM role, a CloudWatch log
   group, and an S3 artifacts bucket. **ECR and a sample Lambda** are included but
   gated behind `enable_pro_features` (default off) because ECR needs LocalStack
   Pro and Lambda needs Docker-in-Docker — flip the flag on real AWS or Pro. ECS/
   Fargate is the documented next step. (This honesty about what emulates locally
   vs. what needs real AWS is deliberate.)
2. **Observability.** An instrumented FastAPI service emits **Prometheus metrics**
   (RED / golden signals) and **OpenTelemetry traces**. Traces are exported over
   OTLP straight to **Jaeger**'s built-in receiver; metrics are scraped by
   **Prometheus** and visualised in **Grafana** on a golden-signals dashboard.
   (A standalone OpenTelemetry Collector — for sampling/fan-out/processors — is
   the documented scale-out step; the lean stack sends OTLP directly to Jaeger.)

## Architecture

```
                          ┌──────────────────────────────────────────────┐
                          │                observability                 │
                          │                                              │
  HTTP  ┌─────────────┐   │  /metrics scrape    ┌────────────┐            │
 ─────▶ │  service    │───┼────────────────────▶│ prometheus │──┐        │
        │ FastAPI     │   │      :9090           └────────────┘  │        │
        │ :8000       │   │                                      ▼        │
        │             │   │  OTLP :4318                       ┌─────────┐ │
        │ OTel traces │───┼──────────────────┐               │ grafana │ │
        │ Prom metrics│   │                   ▼               │ :3000   │ │
        └─────────────┘   │             ┌──────────┐          └─────────┘ │
                          │             │ jaeger   │               ▲      │
                          │             │ :16686   │◀── datasources ┘      │
                          │             │ (OTLP rx)│    (Prom + Jaeger)    │
                          │             └──────────┘                       │
                          └──────────────────────────────────────────────┘

   ┌──────────────────────────────────────────────────────────────────┐
   │  IaC (separate lane)                                              │
   │  terraform apply ─▶ LocalStack :4566  (VPC/subnets/SG, IAM,       │
   │                     CloudWatch logs, S3;  ECR+Lambda = Pro-gated) │
   └──────────────────────────────────────────────────────────────────┘
```

## Quickstart

Prerequisites: **Docker** (with Compose v2), **Terraform**, and **uv** on your PATH.

```bash
# 1. Bring up the whole observability stack (build + start)
make up

# 2. Generate telemetry — fire a burst of requests across the endpoints
make load            # or: make load N=1000

# 3. Open the UIs
#    Grafana     -> http://localhost:3000   (anonymous viewer; golden-signals dashboard)
#    Jaeger      -> http://localhost:16686  (traces for observatory-svc)
#    Prometheus  -> http://localhost:9090   (raw metrics + targets)

# 4. Provision the IaC against LocalStack (separate lane, optional)
make tf-up           # starts LocalStack + terraform init/apply
make tf-down         # terraform destroy + stop LocalStack

# Tear the stack down
make down
```

### Make targets

| Target      | Does |
|-------------|------|
| `make up`   | `docker compose up -d --build` — start the full stack |
| `make down` | Stop and remove the stack + volumes |
| `make load` | Fire `N` requests (default 300) across the service endpoints |
| `make tf-up`   | Start LocalStack, then `terraform init` + `apply` against it |
| `make tf-down` | `terraform destroy` + stop LocalStack |
| `make test` | Run the service test suite (`pytest`) |
| `make lint` | `ruff` + `mypy` on the service; `terraform fmt -check` + `validate` |
| `make config` | Validate `docker-compose.yml` (`docker compose config`) |

## Golden signals

The dashboard is built around the **four golden signals** (Google SRE) — the
minimum set of metrics that tell you whether a service is healthy, derived here
from the `prometheus-fastapi-instrumentator` output:

| Signal        | What it answers | How it's computed |
|---------------|-----------------|-------------------|
| **Latency**   | How long do requests take? | `histogram_quantile(0.50/0.95/0.99, sum by (le) (rate(http_request_duration_seconds_bucket[5m])))` — p50 / p95 / p99 |
| **Traffic**   | How much demand? | `sum(rate(http_requests_total[1m]))` — requests/sec |
| **Errors**    | How often do requests fail? | 5xx ratio: `sum(rate(http_requests_total{status=~"5.."}[5m])) / sum(rate(http_requests_total[5m]))` (the `/flaky` endpoint fails ~20% on purpose) |
| **Saturation**| How full is the service? | In-flight / throughput per endpoint |

Traces in Jaeger let you drill from a slow/errored data point down to the exact
request span — the observability loop: *metric spikes → find the trace → find the
cause.*

## Screenshots

Captured from a live run (`make up && make load`) — the golden-signal metrics in
Prometheus (request rate by status with the injected 5xx errors, and p95 latency)
and the distributed traces landing in Jaeger for `observatory-svc`:

![Prometheus golden signals and Jaeger traces from a live run](docs/img/observability.gif)

The Grafana golden-signals dashboard (`observability/grafana/dashboards/golden-signals.json`)
is provisioned automatically and reads the same Prometheus datasource; open it at
`http://localhost:3000` after `make up`.

## LocalStack scoping (honest boundaries)

This project provisions against **LocalStack Community**, which emulates AWS APIs
locally. The Terraform is deliberately scoped to what Community supports and what
`terraform apply` can create with **no cloud account and no keys**:

- **Provisioned & applyable on Community (the default `apply`):** VPC + subnets +
  security group, IAM role, CloudWatch log group, and an S3 artifacts bucket.
  Verified — a real `apply` creates all of these in a running LocalStack container.
- **Gated behind `enable_pro_features = true` (needs LocalStack Pro / real AWS):**
  the **ECR repository** (ECR isn't in Community) and the sample **Lambda** (its
  runtime needs Docker-in-Docker). The config is present and `validate`-clean but
  off by default, so the default `apply` never breaks on Community.
- **Documented upgrade path, not coded:** ECS/Fargate runtime for the container.

CI does **not** run `apply` — it runs `fmt -check`, `init -backend=false`, and
`validate`. A real `apply` is exercised locally via `make tf-up` against a running
LocalStack container. See [`terraform/README.md`](terraform/README.md) for the
module layout and the real-AWS migration notes.

## Continuous integration

[`.github/workflows/ci.yml`](.github/workflows/ci.yml) runs three independent jobs:

- **service** — `uv sync`, `ruff check`, `ruff format --check`, `mypy`, `pytest`.
- **terraform** — `setup-terraform`, `fmt -check`, `init -backend=false`, `validate`.
- **compose** — `docker compose config` to validate the stack wiring.

## Repository layout

```
.
├── Makefile                 # up / down / load / tf-up / tf-down / test / lint
├── docker-compose.yml       # the observability stack (service + jaeger + prometheus + grafana)
├── service/                 # instrumented FastAPI sample service (metrics + traces)
├── observability/           # prometheus, grafana provisioning + dashboards
├── terraform/               # modular IaC against LocalStack (network + platform modules)
├── docs/                    # CONTRACT.md + img/ (screenshots)
└── .github/workflows/ci.yml # service / terraform / compose CI jobs
```

## What I'd build next

- **Alerting**: Prometheus alert rules + Alertmanager on the golden signals (error
  budget burn, p99 latency SLO), wired to a local receiver.
- **Trace ↔ metric exemplars**: link Grafana latency panels to the exact Jaeger
  trace via OpenTelemetry exemplars for one-click drill-down.
- **Logs**: add Loki + Promtail so the stack covers all three pillars
  (metrics, traces, logs) and correlate by trace ID.
- **Real deploy target**: promote the ECS/Fargate path from "documented" to a
  `terraform workspace` that targets real AWS behind a feature flag.
- **kind/k8s variant**: swap docker-compose for a local Kubernetes deployment with
  the Prometheus Operator and OpenTelemetry Operator to mirror production topology.
- **Load profiles**: replace the simple burst loader with a `k6`/`locust` scenario
  library (steady state, spike, soak) to exercise saturation panels meaningfully.
```
