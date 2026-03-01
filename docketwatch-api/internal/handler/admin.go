package handler

import (
	"encoding/json"
	"net/http"
	"strconv"

	"github.com/go-chi/chi/v5"
	"github.com/tmz/docketwatch-api/internal/repository"
)

// AdminHandler handles HTTP requests for admin endpoints.
type AdminHandler struct {
	adminRepo *repository.AdminRepo
}

// NewAdminHandler creates a new AdminHandler.
func NewAdminHandler(adminRepo *repository.AdminRepo) *AdminHandler {
	return &AdminHandler{adminRepo: adminRepo}
}

// Routes returns the admin routes.
func (h *AdminHandler) Routes() chi.Router {
	r := chi.NewRouter()

	r.Get("/tasks", h.ListTaskLogs)
	r.Get("/errors", h.ListErrorLogs)
	r.Post("/errors/resolve", h.ResolveErrors)
	r.Get("/api-logs", h.ListGeminiAPILogs)
	r.Get("/articles", h.ListArticles)

	return r
}

// ListTaskLogs handles GET /api/admin/tasks?limit=50
func (h *AdminHandler) ListTaskLogs(w http.ResponseWriter, r *http.Request) {
	limit := 50
	if v := r.URL.Query().Get("limit"); v != "" {
		if n, err := strconv.Atoi(v); err == nil {
			limit = n
		}
	}

	logs, err := h.adminRepo.ListTaskLogs(r.Context(), limit)
	if err != nil {
		writeError(w, http.StatusInternalServerError, "INTERNAL", err.Error())
		return
	}
	writeJSON(w, http.StatusOK, map[string]interface{}{"data": logs})
}

// ListErrorLogs handles GET /api/admin/errors?severity=error&resolved=false&limit=100
func (h *AdminHandler) ListErrorLogs(w http.ResponseWriter, r *http.Request) {
	severity := r.URL.Query().Get("severity")

	var resolved *bool
	if v := r.URL.Query().Get("resolved"); v != "" {
		b := v == "true"
		resolved = &b
	}

	limit := 100
	if v := r.URL.Query().Get("limit"); v != "" {
		if n, err := strconv.Atoi(v); err == nil {
			limit = n
		}
	}

	logs, err := h.adminRepo.ListErrorLogs(r.Context(), severity, resolved, limit)
	if err != nil {
		writeError(w, http.StatusInternalServerError, "INTERNAL", err.Error())
		return
	}
	writeJSON(w, http.StatusOK, map[string]interface{}{"data": logs})
}

// ResolveErrors handles POST /api/admin/errors/resolve with body {"ids": [1,2,3]}
func (h *AdminHandler) ResolveErrors(w http.ResponseWriter, r *http.Request) {
	var body struct {
		IDs []int `json:"ids"`
	}
	if err := json.NewDecoder(r.Body).Decode(&body); err != nil {
		writeError(w, http.StatusBadRequest, "INVALID_BODY", "Invalid request body")
		return
	}
	if len(body.IDs) == 0 {
		writeError(w, http.StatusBadRequest, "INVALID_BODY", "No IDs provided")
		return
	}

	affected, err := h.adminRepo.ResolveErrors(r.Context(), body.IDs)
	if err != nil {
		writeError(w, http.StatusInternalServerError, "INTERNAL", err.Error())
		return
	}
	writeJSON(w, http.StatusOK, map[string]interface{}{
		"resolved": affected,
	})
}

// ListGeminiAPILogs handles GET /api/admin/api-logs?limit=50
func (h *AdminHandler) ListGeminiAPILogs(w http.ResponseWriter, r *http.Request) {
	limit := 50
	if v := r.URL.Query().Get("limit"); v != "" {
		if n, err := strconv.Atoi(v); err == nil {
			limit = n
		}
	}

	logs, err := h.adminRepo.ListGeminiAPILogs(r.Context(), limit)
	if err != nil {
		writeError(w, http.StatusInternalServerError, "INTERNAL", err.Error())
		return
	}
	writeJSON(w, http.StatusOK, map[string]interface{}{"data": logs})
}

// ListArticles handles GET /api/admin/articles?limit=50
func (h *AdminHandler) ListArticles(w http.ResponseWriter, r *http.Request) {
	limit := 50
	if v := r.URL.Query().Get("limit"); v != "" {
		if n, err := strconv.Atoi(v); err == nil {
			limit = n
		}
	}

	articles, err := h.adminRepo.ListArticles(r.Context(), limit)
	if err != nil {
		writeError(w, http.StatusInternalServerError, "INTERNAL", err.Error())
		return
	}
	writeJSON(w, http.StatusOK, map[string]interface{}{"data": articles})
}
