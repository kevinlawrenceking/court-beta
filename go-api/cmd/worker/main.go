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
	"github.com/tmz/docketwatch-api/internal/storage"
	"github.com/tmz/docketwatch-api/internal/worker"
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

	// Initialize S3 storage
	var s3Store *storage.S3Store
	if cfg.AWSEndpoint != "" {
		s3Store, err = storage.NewS3StoreWithEndpoint(ctx, cfg.AWSRegion, cfg.AWSEndpoint)
	} else {
		s3Store, err = storage.NewS3Store(ctx, cfg.AWSRegion)
	}
	if err != nil {
		log.Warn().Err(err).Msg("S3 initialization failed; cleanup worker will skip S3 operations")
	}

	log.Info().Msg("Starting DocketWatch background workers")

	// Launch workers in goroutines
	// 1. RSS Poller - checks PACER feeds every 5 minutes
	rssPoller := worker.NewRSSPoller(pool, 5*time.Minute)
	go rssPoller.Start(ctx)

	// 2. Celebrity Matcher - runs every 15 minutes
	matcher := worker.NewCelebrityMatcher(pool, 15*time.Minute)
	go matcher.Start(ctx)

	// 3. Cleanup Worker - runs every 24 hours
	if s3Store != nil {
		cleaner := worker.NewCleanupWorker(pool, s3Store, cfg.S3DocumentsBucket, 24*time.Hour)
		go cleaner.Start(ctx)
	}

	// 4. Email Notifier - checks every 5 minutes, sends via SES
	appURL := "https://docketwatch.tmz.tv"
	if cfg.IsDevelopment() {
		appURL = "http://localhost:3000"
	}
	notifier := worker.NewEmailNotifier(pool, cfg.AWSRegion, cfg.AWSEndpoint, 5*time.Minute, cfg.SESFromAddress, appURL)
	go notifier.Start(ctx)

	log.Info().Msg("All workers running")

	// Wait for shutdown signal
	sigCh := make(chan os.Signal, 1)
	signal.Notify(sigCh, syscall.SIGINT, syscall.SIGTERM)
	<-sigCh

	log.Info().Msg("Shutting down workers...")
	cancel()

	// Give workers time to finish current operations
	time.Sleep(2 * time.Second)
	log.Info().Msg("Workers stopped")
}
