# observatory — glue Makefile
# One command stands up cloud infra (Terraform/LocalStack) + a full
# observability stack (Prometheus + Grafana + Jaeger + OpenTelemetry).
#
# Requires: docker (with compose v2), terraform, uv on PATH.
# If uv is not found, prepend Homebrew:  export PATH="/opt/homebrew/bin:$PATH"

SHELL := /bin/bash

# --- config (override on the CLI, e.g. `make load N=500`) ---------------------
COMPOSE          ?= docker compose
SERVICE_DIR      := service
TF_DIR           := terraform
LOCALSTACK_IMAGE := localstack/localstack:3.8.1
LOCALSTACK_NAME  := observatory-localstack
BASE_URL         ?= http://localhost:8000
N                ?= 300

# LocalStack dummy creds (no real cloud account / no keys).
LOCALSTACK_ENV := \
	AWS_ACCESS_KEY_ID=test \
	AWS_SECRET_ACCESS_KEY=test \
	AWS_DEFAULT_REGION=us-east-1 \
	AWS_REGION=us-east-1

.DEFAULT_GOAL := help
.PHONY: help up down load logs ps test lint fmt tf-up tf-down config

help: ## Show this help
	@grep -hE '^[a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) \
		| awk 'BEGIN{FS=":.*?## "}{printf "  \033[36m%-10s\033[0m %s\n", $$1, $$2}'

# --- observability stack ------------------------------------------------------
up: ## Build + start the full stack (service, otel-collector, jaeger, prometheus, grafana)
	$(COMPOSE) up -d --build
	@echo ""
	@echo "  Grafana     -> http://localhost:3000  (anonymous viewer)"
	@echo "  Jaeger      -> http://localhost:16686"
	@echo "  Prometheus  -> http://localhost:9090"
	@echo "  Service     -> $(BASE_URL)  (/, /health, /work, /flaky, /metrics)"

down: ## Stop and remove the stack + volumes
	$(COMPOSE) down -v

ps: ## Show stack container status
	$(COMPOSE) ps

logs: ## Tail logs from all stack services
	$(COMPOSE) logs -f

config: ## Validate the compose file (no containers started)
	$(COMPOSE) config -q && echo "docker compose config OK"

# --- load generation (script is owned by the service, per contract) -----------
load: ## Fire N requests across the endpoints to generate telemetry (N=$(N))
	@if [ -f "$(SERVICE_DIR)/scripts/load.py" ]; then \
		cd $(SERVICE_DIR) && uv run python scripts/load.py --base "$(BASE_URL)" --n "$(N)"; \
	elif [ -f "scripts/load.py" ]; then \
		uv run --project $(SERVICE_DIR) python scripts/load.py --base "$(BASE_URL)" --n "$(N)"; \
	else \
		echo "ERROR: load script not found (expected $(SERVICE_DIR)/scripts/load.py)"; exit 1; \
	fi

# --- terraform / IaC against LocalStack ---------------------------------------
tf-up: ## Start LocalStack + terraform init & apply against it
	@if ! docker ps --format '{{.Names}}' | grep -q '^$(LOCALSTACK_NAME)$$'; then \
		echo ">> starting LocalStack ($(LOCALSTACK_IMAGE))"; \
		docker rm -f $(LOCALSTACK_NAME) >/dev/null 2>&1 || true; \
		docker run -d --name $(LOCALSTACK_NAME) -p 4566:4566 $(LOCALSTACK_IMAGE) >/dev/null; \
	fi
	@echo ">> waiting for LocalStack to become ready"
	@for i in $$(seq 1 60); do \
		if curl -fs http://localhost:4566/_localstack/health >/dev/null 2>&1; then \
			echo "   LocalStack ready"; break; \
		fi; \
		sleep 2; \
		if [ $$i -eq 60 ]; then echo "ERROR: LocalStack did not become ready"; exit 1; fi; \
	done
	cd $(TF_DIR) && $(LOCALSTACK_ENV) terraform init && \
		$(LOCALSTACK_ENV) terraform apply -auto-approve

tf-down: ## Terraform destroy + stop LocalStack
	-cd $(TF_DIR) && $(LOCALSTACK_ENV) terraform destroy -auto-approve
	-docker rm -f $(LOCALSTACK_NAME) >/dev/null 2>&1 || true

# --- quality gates ------------------------------------------------------------
test: ## Run the service test suite
	cd $(SERVICE_DIR) && uv run pytest

lint: ## ruff + mypy on the service; terraform fmt-check + validate
	cd $(SERVICE_DIR) && uv run ruff check . && uv run mypy .
	terraform -chdir=$(TF_DIR) fmt -check -recursive
	terraform -chdir=$(TF_DIR) init -backend=false -input=false >/dev/null
	terraform -chdir=$(TF_DIR) validate

fmt: ## Auto-format service (ruff) + terraform
	cd $(SERVICE_DIR) && uv run ruff format . && uv run ruff check --fix .
	terraform -chdir=$(TF_DIR) fmt -recursive
