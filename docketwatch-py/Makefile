.PHONY: help install lint test docker-build

help: ## Show this help
	@grep -E '^[a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) | sort | \
		awk 'BEGIN {FS = ":.*?## "}; {printf "  \033[36m%-20s\033[0m %s\n", $$1, $$2}'

install: ## Install Python dependencies
	pip install -r requirements.txt

lint: ## Lint with ruff
	ruff check .
	ruff format --check .

test: ## Run tests
	pytest -v tests/

test-cover: ## Run tests with coverage
	pytest --cov=. --cov-report=html -v tests/

docker-build: ## Build Docker image
	docker build -t docketwatch-python-worker .
