package config

import (
	"fmt"
	"os"
	"strconv"
)

// Config holds all application configuration loaded from environment variables.
type Config struct {
	// Server
	Port string
	Env  string // "development", "staging", "production"

	// Database
	DatabaseURL string

	// AWS
	AWSRegion         string
	AWSEndpoint       string // LocalStack endpoint for local dev
	S3DocumentsBucket string
	S3UploadsBucket   string
	SQSSummarizeURL   string
	SQSQAURL          string
	SQSPacerURL       string

	// Cognito
	CognitoUserPoolID string
	CognitoClientID   string
	CognitoIssuer     string

	// SES
	SESFromAddress string

	// PACER
	PACERBaseURL string

	// Gemini
	GeminiAPIKey string

	// Pagination defaults
	DefaultPageSize int
	MaxPageSize     int
}

// Load reads configuration from environment variables.
func Load() (*Config, error) {
	cfg := &Config{
		Port:            getEnv("PORT", "8080"),
		Env:             getEnv("ENV", "development"),
		DatabaseURL:     getEnv("DATABASE_URL", "postgres://docketwatch:docketwatch@localhost:5432/docketwatch?sslmode=disable"),
		AWSRegion:         getEnv("AWS_REGION", "us-east-1"),
		AWSEndpoint:       getEnv("AWS_ENDPOINT", ""),
		S3DocumentsBucket: getEnv("S3_DOCUMENTS_BUCKET", "dw-documents"),
		S3UploadsBucket:   getEnv("S3_UPLOADS_BUCKET", "dw-uploads"),
		SQSSummarizeURL:   getEnv("SQS_SUMMARIZE_QUEUE_URL", ""),
		SQSQAURL:          getEnv("SQS_QA_QUEUE_URL", ""),
		SQSPacerURL:       getEnv("SQS_PACER_QUEUE_URL", ""),
		CognitoUserPoolID: getEnv("COGNITO_USER_POOL_ID", ""),
		CognitoClientID:   getEnv("COGNITO_CLIENT_ID", ""),
		CognitoIssuer:     getEnv("COGNITO_ISSUER", ""),
		SESFromAddress:     getEnv("SES_FROM_ADDRESS", "noreply@docketwatch.tmz.tv"),
		PACERBaseURL:       getEnv("PACER_BASE_URL", "https://ecf.pacer.gov"),
		GeminiAPIKey:       getEnv("GEMINI_API_KEY", ""),
		DefaultPageSize:    getEnvInt("DEFAULT_PAGE_SIZE", 25),
		MaxPageSize:        getEnvInt("MAX_PAGE_SIZE", 100),
	}

	if cfg.CognitoIssuer == "" && cfg.CognitoUserPoolID != "" {
		cfg.CognitoIssuer = fmt.Sprintf("https://cognito-idp.%s.amazonaws.com/%s", cfg.AWSRegion, cfg.CognitoUserPoolID)
	}

	return cfg, nil
}

// IsDevelopment returns true if running in development mode.
func (c *Config) IsDevelopment() bool {
	return c.Env == "development"
}

func getEnv(key, fallback string) string {
	if v := os.Getenv(key); v != "" {
		return v
	}
	return fallback
}

func getEnvInt(key string, fallback int) int {
	if v := os.Getenv(key); v != "" {
		if i, err := strconv.Atoi(v); err == nil {
			return i
		}
	}
	return fallback
}
