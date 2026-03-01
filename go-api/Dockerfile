# Build stage
FROM golang:1.22-alpine AS builder

RUN apk add --no-cache git

WORKDIR /app
COPY go.mod go.sum ./
RUN go mod download

COPY . .
RUN CGO_ENABLED=0 GOOS=linux go build -ldflags="-s -w" -o /bin/api ./cmd/api
RUN CGO_ENABLED=0 GOOS=linux go build -ldflags="-s -w" -o /bin/worker ./cmd/worker

# API runtime
FROM alpine:3.19 AS api

RUN apk add --no-cache ca-certificates tzdata

WORKDIR /app
COPY --from=builder /bin/api /bin/api
COPY migrations/ /app/migrations/

EXPOSE 8080
CMD ["/bin/api"]

# Worker runtime
FROM alpine:3.19 AS worker

RUN apk add --no-cache ca-certificates tzdata

WORKDIR /app
COPY --from=builder /bin/worker /bin/worker

CMD ["/bin/worker"]
