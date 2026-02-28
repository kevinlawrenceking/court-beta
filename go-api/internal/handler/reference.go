package handler

import (
	"net/http"
	"strconv"

	"github.com/go-chi/chi/v5"
	"github.com/tmz/docketwatch-api/internal/model"
	"github.com/tmz/docketwatch-api/internal/repository"
)

// ReferenceHandler handles HTTP requests for reference data (states, counties, courts, tools).
type ReferenceHandler struct {
	courtRepo *repository.CourtRepo
	celebRepo *repository.CelebrityRepo
}

// NewReferenceHandler creates a new ReferenceHandler.
func NewReferenceHandler(courtRepo *repository.CourtRepo, celebRepo *repository.CelebrityRepo) *ReferenceHandler {
	return &ReferenceHandler{courtRepo: courtRepo, celebRepo: celebRepo}
}

// Routes returns the reference data routes.
func (h *ReferenceHandler) Routes() chi.Router {
	r := chi.NewRouter()

	r.Get("/states", h.ListStates)
	r.Get("/counties", h.ListCounties)
	r.Get("/courts", h.ListCourts)
	r.Get("/tools", h.ListTools)
	r.Get("/celebrities", h.ListCelebrities)

	return r
}

// ListStates handles GET /api/reference/states
func (h *ReferenceHandler) ListStates(w http.ResponseWriter, r *http.Request) {
	states, err := h.courtRepo.ListStates(r.Context())
	if err != nil {
		writeError(w, http.StatusInternalServerError, "INTERNAL", err.Error())
		return
	}
	writeJSON(w, http.StatusOK, map[string]interface{}{"data": states})
}

// ListCounties handles GET /api/reference/counties?state_code=CA
func (h *ReferenceHandler) ListCounties(w http.ResponseWriter, r *http.Request) {
	stateCode := r.URL.Query().Get("state_code")
	counties, err := h.courtRepo.ListCounties(r.Context(), stateCode)
	if err != nil {
		writeError(w, http.StatusInternalServerError, "INTERNAL", err.Error())
		return
	}
	writeJSON(w, http.StatusOK, map[string]interface{}{"data": counties})
}

// ListCourts handles GET /api/reference/courts?county_id=1&state_code=CA
func (h *ReferenceHandler) ListCourts(w http.ResponseWriter, r *http.Request) {
	var countyID *int
	if v := r.URL.Query().Get("county_id"); v != "" {
		if id, err := strconv.Atoi(v); err == nil {
			countyID = &id
		}
	}
	stateCode := r.URL.Query().Get("state_code")

	courts, err := h.courtRepo.ListCourts(r.Context(), countyID, stateCode)
	if err != nil {
		writeError(w, http.StatusInternalServerError, "INTERNAL", err.Error())
		return
	}
	writeJSON(w, http.StatusOK, map[string]interface{}{"data": courts})
}

// ListTools handles GET /api/reference/tools
func (h *ReferenceHandler) ListTools(w http.ResponseWriter, r *http.Request) {
	tools, err := h.courtRepo.ListTools(r.Context())
	if err != nil {
		writeError(w, http.StatusInternalServerError, "INTERNAL", err.Error())
		return
	}
	writeJSON(w, http.StatusOK, map[string]interface{}{"data": tools})
}

// ListCelebrities handles GET /api/reference/celebrities (for dropdown/select filters)
func (h *ReferenceHandler) ListCelebrities(w http.ResponseWriter, r *http.Request) {
	query := r.URL.Query().Get("q")
	if query != "" {
		celebs, err := h.celebRepo.Search(r.Context(), query, 50)
		if err != nil {
			writeError(w, http.StatusInternalServerError, "INTERNAL", err.Error())
			return
		}
		writeJSON(w, http.StatusOK, map[string]interface{}{"data": celebs})
		return
	}

	pg := model.Pagination{Page: 1, PerPage: 1000, Sort: "name", Order: "asc"}
	filter := model.CelebrityFilter{}
	celebs, _, err := h.celebRepo.List(r.Context(), filter, pg)
	if err != nil {
		writeError(w, http.StatusInternalServerError, "INTERNAL", err.Error())
		return
	}
	writeJSON(w, http.StatusOK, map[string]interface{}{"data": celebs})
}
