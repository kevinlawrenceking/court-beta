package handler

import (
	"net/http"
	"strconv"

	"github.com/go-chi/chi/v5"
	"github.com/go-playground/validator/v10"
	"github.com/tmz/docketwatch-api/internal/config"
	"github.com/tmz/docketwatch-api/internal/model"
	"github.com/tmz/docketwatch-api/internal/repository"
)

// MatchHandler handles HTTP requests for celebrity-case matches.
type MatchHandler struct {
	repo     *repository.MatchRepo
	cfg      *config.Config
	validate *validator.Validate
}

// NewMatchHandler creates a new MatchHandler.
func NewMatchHandler(repo *repository.MatchRepo, cfg *config.Config) *MatchHandler {
	return &MatchHandler{
		repo:     repo,
		cfg:      cfg,
		validate: validator.New(),
	}
}

// Routes returns the match routes.
func (h *MatchHandler) Routes() chi.Router {
	r := chi.NewRouter()

	r.Get("/", h.List)
	r.Post("/", h.Create)

	r.Route("/{id}", func(r chi.Router) {
		r.Delete("/", h.Delete)
		r.Patch("/status", h.UpdateStatus)
	})

	return r
}

// List handles GET /api/matches
func (h *MatchHandler) List(w http.ResponseWriter, r *http.Request) {
	pg := model.ParsePagination(r, h.cfg.DefaultPageSize, h.cfg.MaxPageSize)
	filter := parseMatchFilter(r)

	matches, total, err := h.repo.List(r.Context(), filter, pg)
	if err != nil {
		writeError(w, http.StatusInternalServerError, "INTERNAL", err.Error())
		return
	}

	if matches == nil {
		matches = []model.CelebrityMatch{}
	}
	writePaginated(w, matches, pg, total)
}

// Create handles POST /api/matches
func (h *MatchHandler) Create(w http.ResponseWriter, r *http.Request) {
	var req model.CreateMatchRequest
	if err := decodeJSON(r, &req); err != nil {
		writeError(w, http.StatusBadRequest, "INVALID_JSON", "Invalid request body")
		return
	}
	if err := h.validate.Struct(req); err != nil {
		writeError(w, http.StatusBadRequest, "VALIDATION", err.Error())
		return
	}

	id, err := h.repo.Create(r.Context(), req)
	if err != nil {
		writeError(w, http.StatusInternalServerError, "INTERNAL", err.Error())
		return
	}

	writeJSON(w, http.StatusCreated, map[string]interface{}{"data": map[string]int{"id": id}})
}

// Delete handles DELETE /api/matches/{id}
func (h *MatchHandler) Delete(w http.ResponseWriter, r *http.Request) {
	id, err := strconv.Atoi(chi.URLParam(r, "id"))
	if err != nil {
		writeError(w, http.StatusBadRequest, "INVALID_ID", "Invalid match ID")
		return
	}

	if err := h.repo.Delete(r.Context(), id); err != nil {
		writeError(w, http.StatusInternalServerError, "INTERNAL", err.Error())
		return
	}

	writeJSON(w, http.StatusOK, map[string]string{"status": "removed"})
}

// UpdateStatus handles PATCH /api/matches/{id}/status
func (h *MatchHandler) UpdateStatus(w http.ResponseWriter, r *http.Request) {
	id, err := strconv.Atoi(chi.URLParam(r, "id"))
	if err != nil {
		writeError(w, http.StatusBadRequest, "INVALID_ID", "Invalid match ID")
		return
	}

	var req model.UpdateMatchStatusRequest
	if err := decodeJSON(r, &req); err != nil {
		writeError(w, http.StatusBadRequest, "INVALID_JSON", "Invalid request body")
		return
	}
	if err := h.validate.Struct(req); err != nil {
		writeError(w, http.StatusBadRequest, "VALIDATION", err.Error())
		return
	}

	if err := h.repo.UpdateStatus(r.Context(), id, req.Status); err != nil {
		writeError(w, http.StatusInternalServerError, "INTERNAL", err.Error())
		return
	}

	writeJSON(w, http.StatusOK, map[string]string{"status": "updated"})
}

func parseMatchFilter(r *http.Request) model.MatchFilter {
	var f model.MatchFilter
	f.Status = r.URL.Query().Get("status")
	if v := r.URL.Query().Get("case_id"); v != "" {
		if id, err := strconv.Atoi(v); err == nil {
			f.CaseID = &id
		}
	}
	if v := r.URL.Query().Get("celebrity_id"); v != "" {
		if id, err := strconv.Atoi(v); err == nil {
			f.CelebrityID = &id
		}
	}
	return f
}
