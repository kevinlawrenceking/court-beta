package handler

import (
	"net/http"
	"strconv"

	"github.com/go-chi/chi/v5"
	"github.com/tmz/docketwatch-api/internal/repository"
)

// MonitorHandler handles HTTP requests for the live monitor.
type MonitorHandler struct {
	eventRepo *repository.EventRepo
}

// NewMonitorHandler creates a new MonitorHandler.
func NewMonitorHandler(eventRepo *repository.EventRepo) *MonitorHandler {
	return &MonitorHandler{eventRepo: eventRepo}
}

// Routes returns the monitor routes.
func (h *MonitorHandler) Routes() chi.Router {
	r := chi.NewRouter()
	r.Get("/events", h.RecentEvents)
	return r
}

// RecentEvents handles GET /api/monitor/events
func (h *MonitorHandler) RecentEvents(w http.ResponseWriter, r *http.Request) {
	limit := 50
	if v := r.URL.Query().Get("limit"); v != "" {
		if l, err := strconv.Atoi(v); err == nil && l > 0 && l <= 200 {
			limit = l
		}
	}

	events, err := h.eventRepo.RecentForMonitor(r.Context(), limit)
	if err != nil {
		writeError(w, http.StatusInternalServerError, "INTERNAL", err.Error())
		return
	}

	writeJSON(w, http.StatusOK, map[string]interface{}{"data": events})
}
