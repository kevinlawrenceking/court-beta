package model

import "time"

// TaskLog represents a scheduled task execution record.
type TaskLog struct {
	ID           int        `json:"id"`
	TaskName     string     `json:"task_name"`
	Status       string     `json:"status"`
	StartedAt    *time.Time `json:"started_at,omitempty"`
	CompletedAt  *time.Time `json:"completed_at,omitempty"`
	DurationMs   int        `json:"duration_ms,omitempty"`
	Result       string     `json:"result,omitempty"`
	ErrorMessage string     `json:"error_message,omitempty"`
}

// GeminiAPILog represents an AI API call record.
type GeminiAPILog struct {
	ID              int       `json:"id"`
	ScriptName      string    `json:"script_name"`
	ModelName       string    `json:"model_name"`
	InputTokens     int       `json:"input_tokens"`
	OutputTokens    int       `json:"output_tokens"`
	Success         bool      `json:"success"`
	ErrorMessage    string    `json:"error_message,omitempty"`
	ProcessingMs    int       `json:"processing_time_ms"`
	CostEstimate    float64   `json:"cost_estimate"`
	CreatedAt       time.Time `json:"created_at"`
}

// ErrorLog represents an application error record.
type ErrorLog struct {
	ID         int       `json:"id"`
	ScriptName string    `json:"script_name"`
	ErrorType  string    `json:"error_type"`
	Message    string    `json:"message"`
	Detail     string    `json:"detail,omitempty"`
	Severity   string    `json:"severity"`
	Resolved   bool      `json:"resolved"`
	CreatedAt  time.Time `json:"created_at"`
}

// Article represents an AI-generated headline/article.
type Article struct {
	ID        int       `json:"id"`
	CaseID    *int      `json:"case_id,omitempty"`
	Headline  string    `json:"headline"`
	Subhead   string    `json:"subhead,omitempty"`
	BodyHTML  string    `json:"body_html,omitempty"`
	ImageURL  string    `json:"image_url,omitempty"`
	ModelName string    `json:"model_name,omitempty"`
	CreatedAt time.Time `json:"created_at"`
}
