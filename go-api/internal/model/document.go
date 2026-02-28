package model

import (
	"encoding/json"
	"time"

	"github.com/google/uuid"
)

// Document represents a PDF document with OCR text and AI summaries.
type Document struct {
	ID                    int              `json:"id"`
	DocUID                uuid.UUID        `json:"doc_uid"`
	CaseEventID           *int             `json:"case_event_id,omitempty"`
	PDFTitle              string           `json:"pdf_title,omitempty"`
	RelPath               string           `json:"rel_path,omitempty"`
	S3Key                 string           `json:"s3_key,omitempty"`
	FileSize              int              `json:"file_size,omitempty"`
	SHA256Hash            string           `json:"sha256_hash,omitempty"`
	OCRText               string           `json:"ocr_text,omitempty"`
	SummaryAI             string           `json:"summary_ai,omitempty"`
	SummaryAIHTML         string           `json:"summary_ai_html,omitempty"`
	SummaryAIExtraction   json.RawMessage  `json:"summary_ai_extraction_json,omitempty"`
	ModelName             string           `json:"model_name,omitempty"`
	ProcessingMs          int              `json:"processing_ms,omitempty"`
	TokensInput           int              `json:"tokens_input,omitempty"`
	TokensOutput          int              `json:"tokens_output,omitempty"`
	CreatedAt             time.Time        `json:"created_at"`

	// Joined
	Event *Event `json:"event,omitempty"`
}

// UploadDocumentRequest is the input for uploading a new PDF.
type UploadDocumentRequest struct {
	CaseEventID *int   `json:"case_event_id,omitempty"`
	PDFTitle    string `json:"pdf_title,omitempty"`
	// File data is handled via multipart form
}

// AskQuestionRequest is the input for Q&A on a document.
type AskQuestionRequest struct {
	Question  string    `json:"question" validate:"required"`
	SessionID uuid.UUID `json:"session_id,omitempty"`
}

// AskQuestionResponse is the output from document Q&A.
type AskQuestionResponse struct {
	Answer       string          `json:"answer"`
	CitedFields  json.RawMessage `json:"cited_fields,omitempty"`
	ModelName    string          `json:"model_name"`
	TokensInput  int             `json:"tokens_input"`
	TokensOutput int             `json:"tokens_output"`
	ProcessingMs int             `json:"processing_ms"`
}

// QCFeedbackRequest is the input for saving QC feedback.
type QCFeedbackRequest struct {
	Rating      string `json:"rating" validate:"required,oneof=success failure"`
	Notes       string `json:"notes,omitempty"`
	ModelName   string `json:"model_name,omitempty"`
	UploadSHA   string `json:"upload_sha256,omitempty"`
}

// PromptFeedbackRequest is the input for saving prompt/answer feedback.
type PromptFeedbackRequest struct {
	PromptID int    `json:"prompt_id" validate:"required"`
	Rating   int    `json:"rating" validate:"required,min=1,max=5"`
	Feedback string `json:"feedback,omitempty"`
}

// ConversationEntry represents a single Q&A exchange for a document.
type ConversationEntry struct {
	ID           int       `json:"id"`
	DocumentID   int       `json:"document_id"`
	SessionID    uuid.UUID `json:"session_id"`
	PromptText   string    `json:"prompt_text"`
	ResponseText string    `json:"response_text"`
	ModelName    string    `json:"model_name"`
	TokensInput  int       `json:"tokens_input"`
	TokensOutput int       `json:"tokens_output"`
	Rating       *int      `json:"rating,omitempty"`
	Feedback     string    `json:"feedback,omitempty"`
	CreatedAt    time.Time `json:"created_at"`
}
