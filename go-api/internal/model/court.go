package model

// Court represents a courthouse.
type Court struct {
	ID        int    `json:"id"`
	CourtCode string `json:"court_code"`
	CourtName string `json:"court_name"`
	Address   string `json:"address,omitempty"`
	CountyID  *int   `json:"county_id,omitempty"`
	CourtType string `json:"court_type,omitempty"`

	// Joined
	County *County `json:"county,omitempty"`
}

// County represents a county.
type County struct {
	ID        int    `json:"id"`
	Name      string `json:"name"`
	StateCode string `json:"state_code"`

	// Joined
	State *State `json:"state,omitempty"`
}

// State represents a US state.
type State struct {
	StateCode string `json:"state_code"`
	StateName string `json:"state_name"`
}

// Tool represents an external data source (PACER, UniCourt, etc.).
type Tool struct {
	ID          int    `json:"id"`
	Name        string `json:"name"`
	ToolType    string `json:"tool_type,omitempty"`
	APIEndpoint string `json:"api_endpoint,omitempty"`
	Active      bool   `json:"active"`
}
