package model

import "time"

// Event represents a docket entry / court event.
type Event struct {
	ID               int        `json:"id"`
	CaseID           int        `json:"case_id"`
	EventDate        *time.Time `json:"event_date,omitempty"`
	EventDescription string     `json:"event_description"`
	EventURL         string     `json:"event_url,omitempty"`
	IsDoc            bool       `json:"is_doc"`
	Acknowledged     bool       `json:"acknowledged"`
	AcknowledgedAt   *time.Time `json:"acknowledged_at,omitempty"`
	AcknowledgedBy   string     `json:"acknowledged_by,omitempty"`
	Processing       bool       `json:"processing"`
	Storyworthy      bool       `json:"storyworthy"`
	CreatedAt        time.Time  `json:"created_at"`

	// Joined
	Case     *Case     `json:"case,omitempty"`
	Document *Document `json:"document,omitempty"`
}

// AcknowledgeRequest is the input for acknowledging an event.
type AcknowledgeRequest struct {
	Username string `json:"username" validate:"required"`
}

// EventFilter defines the filtering options for listing events.
type EventFilter struct {
	CaseID       *int  `json:"case_id,omitempty"`
	Acknowledged *bool `json:"acknowledged,omitempty"`
	IsDoc        *bool `json:"is_doc,omitempty"`
	Storyworthy  *bool `json:"storyworthy,omitempty"`
}
