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

// CaseHandler handles HTTP requests for cases.
type CaseHandler struct {
	repo     *repository.CaseRepo
	userRepo *repository.UserRepo
	cfg      *config.Config
	validate *validator.Validate
}

// NewCaseHandler creates a new CaseHandler.
func NewCaseHandler(repo *repository.CaseRepo, userRepo *repository.UserRepo, cfg *config.Config) *CaseHandler {
	return &CaseHandler{
		repo:     repo,
		userRepo: userRepo,
		cfg:      cfg,
		validate: validator.New(),
	}
}

// Routes returns the case routes.
func (h *CaseHandler) Routes() chi.Router {
	r := chi.NewRouter()

	r.Get("/", h.List)
	r.Post("/", h.Create)
	r.Patch("/bulk-status", h.BulkUpdateStatus)

	r.Route("/{id}", func(r chi.Router) {
		r.Get("/", h.Get)
		r.Put("/", h.Update)
		r.Delete("/", h.Delete)
		r.Patch("/status", h.UpdateStatus)
		r.Get("/summary", h.GetSummary)

		// Subscribers
		r.Post("/subscribers", h.AddSubscriber)
		r.Delete("/subscribers/{username}", h.RemoveSubscriber)
	})

	return r
}

// List handles GET /api/cases
func (h *CaseHandler) List(w http.ResponseWriter, r *http.Request) {
	pg := model.ParsePagination(r, h.cfg.DefaultPageSize, h.cfg.MaxPageSize)
	filter := parseCaseFilter(r)

	cases, total, err := h.repo.List(r.Context(), filter, pg)
	if err != nil {
		writeError(w, http.StatusInternalServerError, "INTERNAL", err.Error())
		return
	}

	if cases == nil {
		cases = []model.Case{}
	}
	writePaginated(w, cases, pg, total)
}

// Get handles GET /api/cases/{id}
func (h *CaseHandler) Get(w http.ResponseWriter, r *http.Request) {
	id, err := strconv.Atoi(chi.URLParam(r, "id"))
	if err != nil {
		writeError(w, http.StatusBadRequest, "INVALID_ID", "Invalid case ID")
		return
	}

	c, err := h.repo.GetByID(r.Context(), id)
	if err != nil {
		writeError(w, http.StatusInternalServerError, "INTERNAL", err.Error())
		return
	}
	if c == nil {
		writeError(w, http.StatusNotFound, "NOT_FOUND", "Case not found")
		return
	}

	writeJSON(w, http.StatusOK, map[string]interface{}{"data": c})
}

// Create handles POST /api/cases
func (h *CaseHandler) Create(w http.ResponseWriter, r *http.Request) {
	var req model.CreateCaseRequest
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

	c, _ := h.repo.GetByID(r.Context(), id)
	writeJSON(w, http.StatusCreated, map[string]interface{}{"data": c})
}

// Update handles PUT /api/cases/{id}
func (h *CaseHandler) Update(w http.ResponseWriter, r *http.Request) {
	id, err := strconv.Atoi(chi.URLParam(r, "id"))
	if err != nil {
		writeError(w, http.StatusBadRequest, "INVALID_ID", "Invalid case ID")
		return
	}

	var req model.UpdateCaseRequest
	if err := decodeJSON(r, &req); err != nil {
		writeError(w, http.StatusBadRequest, "INVALID_JSON", "Invalid request body")
		return
	}

	if err := h.repo.Update(r.Context(), id, req); err != nil {
		writeError(w, http.StatusInternalServerError, "INTERNAL", err.Error())
		return
	}

	c, _ := h.repo.GetByID(r.Context(), id)
	writeJSON(w, http.StatusOK, map[string]interface{}{"data": c})
}

// Delete handles DELETE /api/cases/{id}
func (h *CaseHandler) Delete(w http.ResponseWriter, r *http.Request) {
	id, err := strconv.Atoi(chi.URLParam(r, "id"))
	if err != nil {
		writeError(w, http.StatusBadRequest, "INVALID_ID", "Invalid case ID")
		return
	}

	if err := h.repo.Delete(r.Context(), id); err != nil {
		writeError(w, http.StatusInternalServerError, "INTERNAL", err.Error())
		return
	}

	writeJSON(w, http.StatusOK, map[string]string{"status": "deleted"})
}

// UpdateStatus handles PATCH /api/cases/{id}/status
func (h *CaseHandler) UpdateStatus(w http.ResponseWriter, r *http.Request) {
	id, err := strconv.Atoi(chi.URLParam(r, "id"))
	if err != nil {
		writeError(w, http.StatusBadRequest, "INVALID_ID", "Invalid case ID")
		return
	}

	var req model.UpdateStatusRequest
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

// BulkUpdateStatus handles PATCH /api/cases/bulk-status
func (h *CaseHandler) BulkUpdateStatus(w http.ResponseWriter, r *http.Request) {
	var req model.BulkStatusRequest
	if err := decodeJSON(r, &req); err != nil {
		writeError(w, http.StatusBadRequest, "INVALID_JSON", "Invalid request body")
		return
	}
	if err := h.validate.Struct(req); err != nil {
		writeError(w, http.StatusBadRequest, "VALIDATION", err.Error())
		return
	}

	if err := h.repo.BulkUpdateStatus(r.Context(), req.IDs, req.Status); err != nil {
		writeError(w, http.StatusInternalServerError, "INTERNAL", err.Error())
		return
	}

	writeJSON(w, http.StatusOK, map[string]interface{}{"status": "updated", "count": len(req.IDs)})
}

// GetSummary handles GET /api/cases/{id}/summary
func (h *CaseHandler) GetSummary(w http.ResponseWriter, r *http.Request) {
	id, err := strconv.Atoi(chi.URLParam(r, "id"))
	if err != nil {
		writeError(w, http.StatusBadRequest, "INVALID_ID", "Invalid case ID")
		return
	}

	c, err := h.repo.GetByID(r.Context(), id)
	if err != nil {
		writeError(w, http.StatusInternalServerError, "INTERNAL", err.Error())
		return
	}
	if c == nil {
		writeError(w, http.StatusNotFound, "NOT_FOUND", "Case not found")
		return
	}

	writeJSON(w, http.StatusOK, map[string]interface{}{"data": c})
}

// AddSubscriber handles POST /api/cases/{id}/subscribers
func (h *CaseHandler) AddSubscriber(w http.ResponseWriter, r *http.Request) {
	caseID, err := strconv.Atoi(chi.URLParam(r, "id"))
	if err != nil {
		writeError(w, http.StatusBadRequest, "INVALID_ID", "Invalid case ID")
		return
	}

	user := auth.GetUser(r.Context())
	if user == nil {
		writeError(w, http.StatusUnauthorized, "UNAUTHORIZED", "Not authenticated")
		return
	}

	if err := h.userRepo.AddCaseSubscriber(r.Context(), caseID, user.Username); err != nil {
		writeError(w, http.StatusInternalServerError, "INTERNAL", err.Error())
		return
	}

	writeJSON(w, http.StatusCreated, map[string]string{"status": "subscribed"})
}

// RemoveSubscriber handles DELETE /api/cases/{id}/subscribers/{username}
func (h *CaseHandler) RemoveSubscriber(w http.ResponseWriter, r *http.Request) {
	caseID, err := strconv.Atoi(chi.URLParam(r, "id"))
	if err != nil {
		writeError(w, http.StatusBadRequest, "INVALID_ID", "Invalid case ID")
		return
	}

	username := chi.URLParam(r, "username")
	if err := h.userRepo.RemoveCaseSubscriber(r.Context(), caseID, username); err != nil {
		writeError(w, http.StatusInternalServerError, "INTERNAL", err.Error())
		return
	}

	writeJSON(w, http.StatusOK, map[string]string{"status": "unsubscribed"})
}

func parseCaseFilter(r *http.Request) model.CaseFilter {
	f := model.CaseFilter{
		Status:    r.URL.Query().Get("status"),
		StateCode: r.URL.Query().Get("state_code"),
		CourtCode: r.URL.Query().Get("court_code"),
		Owner:     r.URL.Query().Get("owner"),
		Query:     r.URL.Query().Get("q"),
	}
	if v := r.URL.Query().Get("tool_id"); v != "" {
		if id, err := strconv.Atoi(v); err == nil {
			f.ToolID = &id
		}
	}
	if v := r.URL.Query().Get("county_id"); v != "" {
		if id, err := strconv.Atoi(v); err == nil {
			f.CountyID = &id
		}
	}
	if v := r.URL.Query().Get("celebrity_id"); v != "" {
		if id, err := strconv.Atoi(v); err == nil {
			f.CelebrityID = &id
		}
	}
	return f
}
