package model

import (
	"time"
)

// Case represents a court case being tracked.
type Case struct {
	ID         int        `json:"id"`
	CaseNumber string     `json:"case_number"`
	CaseName   string     `json:"case_name"`
	CaseType   string     `json:"case_type,omitempty"`
	CourtCode  string     `json:"court_code,omitempty"`
	Status     string     `json:"status"`
	Owner      string     `json:"owner,omitempty"`
	ToolID     *int       `json:"tool_id,omitempty"`
	FilingDate *time.Time `json:"filing_date,omitempty"`
	CreatedAt  time.Time  `json:"created_at"`
	UpdatedAt  time.Time  `json:"updated_at"`

	// Joined data (populated on detail views)
	Court       *Court              `json:"court,omitempty"`
	Tool        *Tool               `json:"tool,omitempty"`
	Celebrities []CelebrityMatch    `json:"celebrities,omitempty"`
	EventCount  int                 `json:"event_count,omitempty"`
	DocCount    int                 `json:"doc_count,omitempty"`
	Subscribers []EmailSubscription `json:"subscribers,omitempty"`
}

// CreateCaseRequest is the input for creating a new case.
type CreateCaseRequest struct {
	CaseNumber string `json:"case_number" validate:"required,max=100"`
	CaseName   string `json:"case_name" validate:"required"`
	CaseType   string `json:"case_type,omitempty"`
	CourtCode  string `json:"court_code,omitempty"`
	Status     string `json:"status,omitempty"`
	Owner      string `json:"owner,omitempty"`
	ToolID     *int   `json:"tool_id,omitempty"`
}

// UpdateCaseRequest is the input for updating a case.
type UpdateCaseRequest struct {
	CaseNumber *string `json:"case_number,omitempty" validate:"omitempty,max=100"`
	CaseName   *string `json:"case_name,omitempty"`
	CaseType   *string `json:"case_type,omitempty"`
	CourtCode  *string `json:"court_code,omitempty"`
	Status     *string `json:"status,omitempty"`
	Owner      *string `json:"owner,omitempty"`
	ToolID     *int    `json:"tool_id,omitempty"`
}

// UpdateStatusRequest is the input for changing case status.
type UpdateStatusRequest struct {
	Status string `json:"status" validate:"required,oneof=Review Tracked Removed"`
}

// BulkStatusRequest is the input for bulk status changes.
type BulkStatusRequest struct {
	IDs    []int  `json:"ids" validate:"required,min=1"`
	Status string `json:"status" validate:"required,oneof=Review Tracked Removed"`
}

// CaseFilter defines the filtering options for listing cases.
type CaseFilter struct {
	Status      string `json:"status,omitempty"`
	ToolID      *int   `json:"tool_id,omitempty"`
	StateCode   string `json:"state_code,omitempty"`
	CountyID    *int   `json:"county_id,omitempty"`
	CourtCode   string `json:"court_code,omitempty"`
	CelebrityID *int   `json:"celebrity_id,omitempty"`
	Owner       string `json:"owner,omitempty"`
	Query       string `json:"q,omitempty"` // full-text search
}

// EmailSubscription links a user to case notifications.
type EmailSubscription struct {
	ID       int    `json:"id"`
	CaseID   int    `json:"case_id"`
	Username string `json:"username"`
	Notify   bool   `json:"notify"`
}
