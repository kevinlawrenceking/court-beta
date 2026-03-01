package handler

import (
	"net/http"
	"strconv"

	"github.com/go-chi/chi/v5"
	"github.com/go-playground/validator/v10"
	"github.com/tmz/docketwatch-api/internal/auth"
	"github.com/tmz/docketwatch-api/internal/config"
	"github.com/tmz/docketwatch-api/internal/model"
	"github.com/tmz/docketwatch-api/internal/repository"
)

// EventHandler handles HTTP requests for events.
type EventHandler struct {
	repo     *repository.EventRepo
	cfg      *config.Config
	validate *validator.Validate
}

// NewEventHandler creates a new EventHandler.
func NewEventHandler(repo *repository.EventRepo, cfg *config.Config) *EventHandler {
	return &EventHandler{
		repo:     repo,
		cfg:      cfg,
		validate: validator.New(),
	}
}

// Routes returns the event routes.
func (h *EventHandler) Routes() chi.Router {
	r := chi.NewRouter()

	r.Get("/", h.List)
	r.Post("/bulk-acknowledge", h.BulkAcknowledge)

	r.Route("/{id}", func(r chi.Router) {
		r.Post("/acknowledge", h.Acknowledge)
	})

	return r
}

// List handles GET /api/events
func (h *EventHandler) List(w http.ResponseWriter, r *http.Request) {
	pg := model.ParsePagination(r, h.cfg.DefaultPageSize, h.cfg.MaxPageSize)
	filter := parseEventFilter(r)

	events, total, err := h.repo.List(r.Context(), filter, pg)
	if err != nil {
		writeError(w, http.StatusInternalServerError, "INTERNAL", err.Error())
		return
	}

	if events == nil {
		events = []model.Event{}
	}
	writePaginated(w, events, pg, total)
}

// Acknowledge handles POST /api/events/{id}/acknowledge
func (h *EventHandler) Acknowledge(w http.ResponseWriter, r *http.Request) {
	id, err := strconv.Atoi(chi.URLParam(r, "id"))
	if err != nil {
		writeError(w, http.StatusBadRequest, "INVALID_ID", "Invalid event ID")
		return
	}

	user := auth.GetUser(r.Context())
	username := "system"
	if user != nil {
		username = user.Username
	}

	if err := h.repo.Acknowledge(r.Context(), id, username); err != nil {
		writeError(w, http.StatusInternalServerError, "INTERNAL", err.Error())
		return
	}

	writeJSON(w, http.StatusOK, map[string]string{"status": "acknowledged"})
}

// BulkAcknowledge handles POST /api/events/bulk-acknowledge
func (h *EventHandler) BulkAcknowledge(w http.ResponseWriter, r *http.Request) {
	var req struct {
		IDs []int `json:"ids" validate:"required,min=1"`
	}
	if err := decodeJSON(r, &req); err != nil {
		writeError(w, http.StatusBadRequest, "INVALID_JSON", "Invalid request body")
		return
	}
	if err := h.validate.Struct(req); err != nil {
		writeError(w, http.StatusBadRequest, "VALIDATION", err.Error())
		return
	}

	user := auth.GetUser(r.Context())
	username := "system"
	if user != nil {
		username = user.Username
	}

	if err := h.repo.BulkAcknowledge(r.Context(), req.IDs, username); err != nil {
		writeError(w, http.StatusInternalServerError, "INTERNAL", err.Error())
		return
	}

	writeJSON(w, http.StatusOK, map[string]interface{}{"status": "acknowledged", "count": len(req.IDs)})
}

func parseEventFilter(r *http.Request) model.EventFilter {
	var f model.EventFilter
	if v := r.URL.Query().Get("case_id"); v != "" {
		if id, err := strconv.Atoi(v); err == nil {
			f.CaseID = &id
		}
	}
	if v := r.URL.Query().Get("acknowledged"); v != "" {
		b := v == "true"
		f.Acknowledged = &b
	}
	if v := r.URL.Query().Get("is_doc"); v != "" {
		b := v == "true"
		f.IsDoc = &b
	}
	if v := r.URL.Query().Get("storyworthy"); v != "" {
		b := v == "true"
		f.Storyworthy = &b
	}
	return f
}
