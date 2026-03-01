.PHONY: help dev-up dev-down api-build api-run flutter-run lint test

help: ## Show this help
	@grep -E '^[a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) | sort | \
		awk 'BEGIN {FS = ":.*?## "}; {printf "  \033[36m%-20s\033[0m %s\n", $$1, $$2}'

# ─── Local Development ─────────────────────────────────────────────────────

dev-up: ## Start local dev environment (PostgreSQL, LocalStack)
	cd go-api && docker compose up -d postgres localstack
	@echo "Waiting for PostgreSQL..."
	@sleep 3
	cd go-api && docker compose run --rm migrate
	@echo "Local dev environment ready"

dev-down: ## Stop local dev environment
	cd go-api && docker compose down

# ─── Go API ────────────────────────────────────────────────────────────────

api-build: ## Build Go API binary
	cd go-api && go build -o bin/api ./cmd/api

api-run: ## Run Go API locally
	cd go-api && go run ./cmd/api

worker-run: ## Run Go worker locally
	cd go-api && go run ./cmd/worker

api-test: ## Run Go tests
	cd go-api && go test -race ./...

# ─── Flutter ───────────────────────────────────────────────────────────────

flutter-get: ## Install Flutter dependencies
	cd flutter-web && flutter pub get

flutter-run: ## Run Flutter web in debug mode
	cd flutter-web && flutter run -d chrome

flutter-build: ## Build Flutter web for production
	cd flutter-web && flutter build web --release --web-renderer canvaskit

flutter-test: ## Run Flutter tests
	cd flutter-web && flutter test

# ─── Python Workers ───────────────────────────────────────────────────────

python-install: ## Install Python dependencies
	cd python-workers && pip install -r requirements.txt

python-lint: ## Lint Python code
	cd python-workers && ruff check . && ruff format --check .

python-test: ## Run Python tests
	cd python-workers && pytest -v tests/

# ─── Terraform ─────────────────────────────────────────────────────────────

tf-init: ## Initialize Terraform
	cd infra && terraform init

tf-plan: ## Plan Terraform changes
	cd infra && terraform plan -var-file=environments/production/terraform.tfvars

tf-apply: ## Apply Terraform changes
	cd infra && terraform apply -var-file=environments/production/terraform.tfvars

tf-fmt: ## Format Terraform files
	cd infra && terraform fmt -recursive

# ─── Lint All ──────────────────────────────────────────────────────────────

lint: ## Run all linters
	cd go-api && golangci-lint run
	cd flutter-web && flutter analyze
	cd python-workers && ruff check .
	cd infra && terraform fmt -check -recursive

# ─── Docker ────────────────────────────────────────────────────────────────

docker-api: ## Build API Docker image
	cd go-api && docker build --target api -t docketwatch-api .

docker-worker: ## Build worker Docker image
	cd go-api && docker build --target worker -t docketwatch-worker .

docker-python: ## Build Python worker Docker image
	cd python-workers && docker build -t docketwatch-python-worker .
