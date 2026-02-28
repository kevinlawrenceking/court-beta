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

// CelebrityHandler handles HTTP requests for celebrities.
type CelebrityHandler struct {
	repo     *repository.CelebrityRepo
	cfg      *config.Config
	validate *validator.Validate
}

// NewCelebrityHandler creates a new CelebrityHandler.
func NewCelebrityHandler(repo *repository.CelebrityRepo, cfg *config.Config) *CelebrityHandler {
	return &CelebrityHandler{
		repo:     repo,
		cfg:      cfg,
		validate: validator.New(),
	}
}

// Routes returns the celebrity routes.
func (h *CelebrityHandler) Routes() chi.Router {
	r := chi.NewRouter()

	r.Get("/", h.List)
	r.Post("/", h.Create)
	r.Get("/search", h.Search)
	r.Get("/{id}", h.Get)

	return r
}

// List handles GET /api/celebrities
func (h *CelebrityHandler) List(w http.ResponseWriter, r *http.Request) {
	pg := model.ParsePagination(r, h.cfg.DefaultPageSize, h.cfg.MaxPageSize)
	filter := parseCelebrityFilter(r)

	celebs, total, err := h.repo.List(r.Context(), filter, pg)
	if err != nil {
		writeError(w, http.StatusInternalServerError, "INTERNAL", err.Error())
		return
	}

	if celebs == nil {
		celebs = []model.Celebrity{}
	}
	writePaginated(w, celebs, pg, total)
}

// Get handles GET /api/celebrities/{id}
func (h *CelebrityHandler) Get(w http.ResponseWriter, r *http.Request) {
	id, err := strconv.Atoi(chi.URLParam(r, "id"))
	if err != nil {
		writeError(w, http.StatusBadRequest, "INVALID_ID", "Invalid celebrity ID")
		return
	}

	celeb, err := h.repo.GetByID(r.Context(), id)
	if err != nil {
		writeError(w, http.StatusInternalServerError, "INTERNAL", err.Error())
		return
	}
	if celeb == nil {
		writeError(w, http.StatusNotFound, "NOT_FOUND", "Celebrity not found")
		return
	}

	writeJSON(w, http.StatusOK, map[string]interface{}{"data": celeb})
}

// Create handles POST /api/celebrities
func (h *CelebrityHandler) Create(w http.ResponseWriter, r *http.Request) {
	var req model.CreateCelebrityRequest
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

	celeb, _ := h.repo.GetByID(r.Context(), id)
	writeJSON(w, http.StatusCreated, map[string]interface{}{"data": celeb})
}

// Search handles GET /api/celebrities/search?q=name
func (h *CelebrityHandler) Search(w http.ResponseWriter, r *http.Request) {
	query := r.URL.Query().Get("q")
	if query == "" {
		writeError(w, http.StatusBadRequest, "MISSING_QUERY", "Query parameter 'q' is required")
		return
	}

	limit := 20
	if v := r.URL.Query().Get("limit"); v != "" {
		if l, err := strconv.Atoi(v); err == nil && l > 0 && l <= 100 {
			limit = l
		}
	}

	celebs, err := h.repo.Search(r.Context(), query, limit)
	if err != nil {
		writeError(w, http.StatusInternalServerError, "INTERNAL", err.Error())
		return
	}

	if celebs == nil {
		celebs = []model.Celebrity{}
	}
	writeJSON(w, http.StatusOK, map[string]interface{}{"data": celebs})
}

func parseCelebrityFilter(r *http.Request) model.CelebrityFilter {
	var f model.CelebrityFilter
	f.Query = r.URL.Query().Get("q")
	if v := r.URL.Query().Get("verified"); v != "" {
		b := v == "true"
		f.Verified = &b
	}
	return f
}
