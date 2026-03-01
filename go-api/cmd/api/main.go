package main

import (
	"context"
	"fmt"
	"net/http"
	"os"
	"os/signal"
	"syscall"
	"time"

	"github.com/go-chi/chi/v5"
	chimw "github.com/go-chi/chi/v5/middleware"
	"github.com/go-chi/cors"
	"github.com/rs/zerolog"
	"github.com/rs/zerolog/log"

	"github.com/tmz/docketwatch-api/internal/auth"
	"github.com/tmz/docketwatch-api/internal/config"
	"github.com/tmz/docketwatch-api/internal/handler"
	"github.com/tmz/docketwatch-api/internal/queue"
	"github.com/tmz/docketwatch-api/internal/repository"
	"github.com/tmz/docketwatch-api/internal/storage"
)

func main() {
	// Configure logging
	zerolog.TimeFieldFormat = zerolog.TimeFormatUnix
	log.Logger = log.Output(zerolog.ConsoleWriter{Out: os.Stderr, TimeFormat: time.RFC3339})

	ctx, cancel := context.WithCancel(context.Background())
	defer cancel()

	// Load config
	cfg, err := config.Load()
	if err != nil {
		log.Fatal().Err(err).Msg("Failed to load config")
	}

	if cfg.IsDevelopment() {
		zerolog.SetGlobalLevel(zerolog.DebugLevel)
		log.Info().Msg("Running in development mode")
	} else {
		zerolog.SetGlobalLevel(zerolog.InfoLevel)
		log.Logger = zerolog.New(os.Stderr).With().Timestamp().Logger()
	}

	// Connect to database
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
		log.Warn().Err(err).Msg("S3 store initialization failed; file operations will be unavailable")
	}

	// Initialize SQS client
	var sqsClient *queue.SQSClient
	sqsClient, err = queue.NewSQSClient(ctx, cfg.AWSRegion, cfg.AWSEndpoint)
	if err != nil {
		log.Warn().Err(err).Msg("SQS client initialization failed; queue operations will be unavailable")
	}

	// Initialize repositories
	caseRepo := repository.NewCaseRepo(pool)
	eventRepo := repository.NewEventRepo(pool)
	docRepo := repository.NewDocumentRepo(pool)
	celebRepo := repository.NewCelebrityRepo(pool)
	matchRepo := repository.NewMatchRepo(pool)
	courtRepo := repository.NewCourtRepo(pool)
	userRepo := repository.NewUserRepo(pool)

	// Initialize auth middleware
	authMW := auth.NewMiddleware(cfg.CognitoIssuer, cfg.CognitoClientID, cfg.IsDevelopment())

	// Initialize handlers
	caseHandler := handler.NewCaseHandler(caseRepo, userRepo, cfg)
	eventHandler := handler.NewEventHandler(eventRepo, cfg)
	docHandler := handler.NewDocumentHandler(docRepo, s3Store, sqsClient, cfg)
	celebHandler := handler.NewCelebrityHandler(celebRepo, cfg)
	matchHandler := handler.NewMatchHandler(matchRepo, cfg)
	monitorHandler := handler.NewMonitorHandler(eventRepo)
	refHandler := handler.NewReferenceHandler(courtRepo, celebRepo)

	// Build router
	r := chi.NewRouter()

	// Global middleware
	r.Use(chimw.RequestID)
	r.Use(chimw.RealIP)
	r.Use(chimw.Logger)
	r.Use(chimw.Recoverer)
	r.Use(chimw.Timeout(60 * time.Second))
	r.Use(cors.Handler(cors.Options{
		AllowedOrigins:   []string{"*"},
		AllowedMethods:   []string{"GET", "POST", "PUT", "PATCH", "DELETE", "OPTIONS"},
		AllowedHeaders:   []string{"Accept", "Authorization", "Content-Type"},
		ExposedHeaders:   []string{"Link"},
		AllowCredentials: true,
		MaxAge:           300,
	}))

	// Health check (no auth)
	r.Get("/health", func(w http.ResponseWriter, r *http.Request) {
		w.Header().Set("Content-Type", "application/json")
		w.WriteHeader(http.StatusOK)
		fmt.Fprint(w, `{"status":"ok","service":"docketwatch-api"}`)
	})

	// API routes (authenticated)
	r.Route("/api", func(r chi.Router) {
		r.Use(authMW.Handler)

		r.Mount("/cases", caseHandler.Routes())
		r.Mount("/events", eventHandler.Routes())
		r.Mount("/documents", docHandler.Routes())
		r.Mount("/celebrities", celebHandler.Routes())
		r.Mount("/matches", matchHandler.Routes())
		r.Mount("/monitor", monitorHandler.Routes())
		r.Mount("/reference", refHandler.Routes())
	})

	// Start server
	addr := ":" + cfg.Port
	srv := &http.Server{
		Addr:         addr,
		Handler:      r,
		ReadTimeout:  15 * time.Second,
		WriteTimeout: 60 * time.Second,
		IdleTimeout:  120 * time.Second,
	}

	// Graceful shutdown
	go func() {
		sigCh := make(chan os.Signal, 1)
		signal.Notify(sigCh, syscall.SIGINT, syscall.SIGTERM)
		<-sigCh

		log.Info().Msg("Shutting down server...")
		shutdownCtx, shutdownCancel := context.WithTimeout(context.Background(), 30*time.Second)
		defer shutdownCancel()

		if err := srv.Shutdown(shutdownCtx); err != nil {
			log.Fatal().Err(err).Msg("Server shutdown failed")
		}
		cancel()
	}()

	log.Info().Str("addr", addr).Msg("Starting DocketWatch API server")
	if err := srv.ListenAndServe(); err != nil && err != http.ErrServerClosed {
		log.Fatal().Err(err).Msg("Server failed")
	}

	log.Info().Msg("Server stopped")
}
