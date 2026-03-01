.PHONY: build run test lint migrate-up migrate-down docker-build docker-up docker-down

# Build
build:
	go build -o bin/api ./cmd/api
	go build -o bin/worker ./cmd/worker

run:
	go run ./cmd/api

run-worker:
	go run ./cmd/worker

# Test
test:
	go test ./... -v -race -count=1

test-cover:
	go test ./... -coverprofile=coverage.out
	go tool cover -html=coverage.out -o coverage.html

# Lint
lint:
	golangci-lint run ./...

# Database migrations
migrate-up:
	migrate -path migrations -database "$(DATABASE_URL)" up

migrate-down:
	migrate -path migrations -database "$(DATABASE_URL)" down 1

migrate-create:
	migrate create -ext sql -dir migrations -seq $(name)

# Docker
docker-build:
	docker build -t docketwatch-api .

docker-up:
	docker compose up -d

docker-down:
	docker compose down

# Local dev with live reload (requires air: go install github.com/air-verse/air@latest)
dev:
	air -c .air.toml
