package model

import "time"

// User represents an application user.
type User struct {
	ID         int       `json:"id"`
	Username   string    `json:"username"`
	Email      string    `json:"email,omitempty"`
	FirstName  string    `json:"first_name,omitempty"`
	LastName   string    `json:"last_name,omitempty"`
	Role       string    `json:"role"`
	CognitoSub string   `json:"cognito_sub,omitempty"`
	CreatedAt  time.Time `json:"created_at"`
}

// UserPreference stores a user's UI preference.
type UserPreference struct {
	Key   string      `json:"key"`
	Value interface{} `json:"value"`
}

// UpdatePreferencesRequest is the input for saving user preferences.
type UpdatePreferencesRequest struct {
	Key   string      `json:"key" validate:"required"`
	Value interface{} `json:"value" validate:"required"`
}
