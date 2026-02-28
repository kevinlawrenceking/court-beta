package main

import (
	"context"
	"os"
	"os/signal"
	"syscall"
	"time"

	"github.com/rs/zerolog"
	"github.com/rs/zerolog/log"

	"github.com/tmz/docketwatch-api/internal/config"
	"github.com/tmz/docketwatch-api/internal/repository"
)

func main() {
	zerolog.TimeFieldFormat = zerolog.TimeFormatUnix
	log.Logger = log.Output(zerolog.ConsoleWriter{Out: os.Stderr, TimeFormat: time.RFC3339})

	ctx, cancel := context.WithCancel(context.Background())
	defer cancel()

	cfg, err := config.Load()
	if err != nil {
		log.Fatal().Err(err).Msg("Failed to load config")
	}

	pool, err := repository.NewPool(ctx, cfg.DatabaseURL)
	if err != nil {
		log.Fatal().Err(err).Msg("Failed to connect to database")
	}
	defer pool.Close()

	log.Info().Msg("Starting DocketWatch background worker")

	// TODO: Initialize workers:
	// - RSS poller (cron-based)
	// - Celebrity matcher (SQS consumer)
	// - Cleanup worker (cron-based)
	// - Email notifier (SQS consumer)
	//
	// Each worker runs in its own goroutine.
	// Use a cron library (e.g., robfig/cron) for scheduled tasks.
	// Use SQS long-polling for event-driven tasks.

	_ = cfg

	// Wait for shutdown signal
	sigCh := make(chan os.Signal, 1)
	signal.Notify(sigCh, syscall.SIGINT, syscall.SIGTERM)
	<-sigCh

	log.Info().Msg("Worker shutting down")
	cancel()
}
