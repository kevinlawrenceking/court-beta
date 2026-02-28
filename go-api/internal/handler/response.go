package handler

import (
	"encoding/json"
	"net/http"

	"github.com/rs/zerolog/log"
	"github.com/tmz/docketwatch-api/internal/model"
)

// ErrorResponse represents a JSON error response.
type ErrorResponse struct {
	Error ErrorBody `json:"error"`
}

// ErrorBody contains error details.
type ErrorBody struct {
	Code    string `json:"code"`
	Message string `json:"message"`
}

// writeJSON writes a JSON response with the given status code.
func writeJSON(w http.ResponseWriter, status int, v interface{}) {
	w.Header().Set("Content-Type", "application/json")
	w.WriteHeader(status)
	if err := json.NewEncoder(w).Encode(v); err != nil {
		log.Error().Err(err).Msg("Failed to encode JSON response")
	}
}

// writeError writes a JSON error response.
func writeError(w http.ResponseWriter, status int, code, message string) {
	writeJSON(w, status, ErrorResponse{
		Error: ErrorBody{Code: code, Message: message},
	})
}

// writePaginated writes a paginated JSON response.
func writePaginated(w http.ResponseWriter, data interface{}, pg model.Pagination, total int) {
	writeJSON(w, http.StatusOK, model.PaginatedResponse{
		Data: data,
		Meta: model.NewPaginationMeta(pg, total),
	})
}

// decodeJSON decodes a JSON request body into v.
func decodeJSON(r *http.Request, v interface{}) error {
	defer r.Body.Close()
	return json.NewDecoder(r.Body).Decode(v)
}
