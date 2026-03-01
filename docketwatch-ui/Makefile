.PHONY: help get run build test analyze format lint

help: ## Show this help
	@grep -E '^[a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) | sort | \
		awk 'BEGIN {FS = ":.*?## "}; {printf "  \033[36m%-20s\033[0m %s\n", $$1, $$2}'

get: ## Install Flutter dependencies
	flutter pub get

run: ## Run in debug mode (Chrome)
	flutter run -d chrome

build: ## Build for production (web, canvaskit renderer)
	flutter build web --release --web-renderer canvaskit

test: ## Run tests
	flutter test

analyze: ## Run static analysis
	flutter analyze --no-fatal-infos

format: ## Check formatting
	dart format --set-exit-if-changed lib/

lint: analyze format ## Run all lint checks
