package model

import "time"

// Celebrity represents a celebrity tracked in the system.
type Celebrity struct {
	ID         int       `json:"id"`
	Name       string    `json:"name"`
	TMZCelebID *int      `json:"tmz_celeb_id,omitempty"`
	ImageURL   string    `json:"image_url,omitempty"`
	Verified   bool      `json:"verified"`
	CreatedAt  time.Time `json:"created_at"`

	// Joined
	CaseCount int `json:"case_count,omitempty"`
}

// CreateCelebrityRequest is the input for adding a celebrity.
type CreateCelebrityRequest struct {
	Name       string `json:"name" validate:"required,max=200"`
	TMZCelebID *int   `json:"tmz_celeb_id,omitempty"`
	ImageURL   string `json:"image_url,omitempty"`
}

// CelebrityMatch represents a link between a celebrity and a case.
type CelebrityMatch struct {
	ID          int       `json:"id"`
	CaseID      int       `json:"case_id"`
	CelebrityID int       `json:"celebrity_id"`
	MatchStatus string    `json:"match_status"`
	MatchScore  float64   `json:"match_score,omitempty"`
	MatchedBy   string    `json:"matched_by,omitempty"`
	CreatedAt   time.Time `json:"created_at"`

	// Joined
	Celebrity *Celebrity `json:"celebrity,omitempty"`
	Case      *Case      `json:"case,omitempty"`
}

// CreateMatchRequest is the input for linking a celebrity to a case.
type CreateMatchRequest struct {
	CaseID      int    `json:"case_id" validate:"required"`
	CelebrityID int    `json:"celebrity_id" validate:"required"`
	MatchStatus string `json:"match_status,omitempty"`
}

// UpdateMatchStatusRequest is the input for updating match status.
type UpdateMatchStatusRequest struct {
	Status string `json:"status" validate:"required,oneof=Pending Tracked Verified Rejected Removed"`
}

// MatchFilter defines the filtering options for listing matches.
type MatchFilter struct {
	CaseID      *int   `json:"case_id,omitempty"`
	CelebrityID *int   `json:"celebrity_id,omitempty"`
	Status      string `json:"status,omitempty"`
}

// CelebrityFilter defines the filtering options for listing celebrities.
type CelebrityFilter struct {
	Verified *bool  `json:"verified,omitempty"`
	Query    string `json:"q,omitempty"`
}
