package handler

import (
	"crypto/sha256"
	"fmt"
	"io"
	"net/http"
	"strconv"

	"github.com/go-chi/chi/v5"
	"github.com/go-playground/validator/v10"
	"github.com/google/uuid"
	"github.com/tmz/docketwatch-api/internal/auth"
	"github.com/tmz/docketwatch-api/internal/config"
	"github.com/tmz/docketwatch-api/internal/model"
	"github.com/tmz/docketwatch-api/internal/repository"
	"github.com/tmz/docketwatch-api/internal/storage"
)

// DocumentHandler handles HTTP requests for documents.
type DocumentHandler struct {
	repo     *repository.DocumentRepo
	store    *storage.S3Store
	cfg      *config.Config
	validate *validator.Validate
}

// NewDocumentHandler creates a new DocumentHandler.
func NewDocumentHandler(repo *repository.DocumentRepo, store *storage.S3Store, cfg *config.Config) *DocumentHandler {
	return &DocumentHandler{
		repo:     repo,
		store:    store,
		cfg:      cfg,
		validate: validator.New(),
	}
}

// Routes returns the document routes.
func (h *DocumentHandler) Routes() chi.Router {
	r := chi.NewRouter()

	r.Post("/upload", h.Upload)

	r.Route("/{id}", func(r chi.Router) {
		r.Get("/", h.Get)
		r.Post("/summarize", h.Summarize)
		r.Post("/download-pacer", h.DownloadPacer)
		r.Post("/ask", h.Ask)
		r.Get("/conversations", h.GetConversations)
		r.Post("/qc-feedback", h.SaveQCFeedback)
		r.Post("/prompt-feedback", h.SavePromptFeedback)
	})

	return r
}

// Get handles GET /api/documents/{id}
func (h *DocumentHandler) Get(w http.ResponseWriter, r *http.Request) {
	id, err := strconv.Atoi(chi.URLParam(r, "id"))
	if err != nil {
		writeError(w, http.StatusBadRequest, "INVALID_ID", "Invalid document ID")
		return
	}

	doc, err := h.repo.GetByID(r.Context(), id)
	if err != nil {
		writeError(w, http.StatusInternalServerError, "INTERNAL", err.Error())
		return
	}
	if doc == nil {
		writeError(w, http.StatusNotFound, "NOT_FOUND", "Document not found")
		return
	}

	writeJSON(w, http.StatusOK, map[string]interface{}{"data": doc})
}

// Upload handles POST /api/documents/upload (multipart form)
func (h *DocumentHandler) Upload(w http.ResponseWriter, r *http.Request) {
	const maxSize = 25 << 20 // 25 MB
	r.Body = http.MaxBytesReader(w, r.Body, maxSize)

	if err := r.ParseMultipartForm(maxSize); err != nil {
		writeError(w, http.StatusBadRequest, "FILE_TOO_LARGE", "File exceeds 25MB limit")
		return
	}

	file, header, err := r.FormFile("file")
	if err != nil {
		writeError(w, http.StatusBadRequest, "NO_FILE", "No file provided")
		return
	}
	defer file.Close()

	// Validate PDF magic bytes
	buf := make([]byte, 5)
	if _, err := file.Read(buf); err != nil {
		writeError(w, http.StatusBadRequest, "READ_ERROR", "Cannot read file")
		return
	}
	if string(buf) != "%PDF-" {
		writeError(w, http.StatusBadRequest, "INVALID_FILE", "File must be a PDF")
		return
	}
	if _, err := file.Seek(0, io.SeekStart); err != nil {
		writeError(w, http.StatusInternalServerError, "INTERNAL", "Seek error")
		return
	}

	// Read file and compute hash
	data, err := io.ReadAll(file)
	if err != nil {
		writeError(w, http.StatusInternalServerError, "INTERNAL", "Failed to read file")
		return
	}
	hash := fmt.Sprintf("%x", sha256.Sum256(data))

	// Upload to S3
	s3Key := fmt.Sprintf("uploads/%s/%s", uuid.New().String(), header.Filename)
	if err := h.store.PutObject(r.Context(), h.cfg.S3UploadsBucket, s3Key, data, "application/pdf"); err != nil {
		writeError(w, http.StatusInternalServerError, "S3_ERROR", "Failed to store file")
		return
	}

	// Create document record
	doc := &model.Document{
		PDFTitle:   header.Filename,
		S3Key:      s3Key,
		FileSize:   len(data),
		SHA256Hash: hash,
	}

	if eventIDStr := r.FormValue("case_event_id"); eventIDStr != "" {
		if eid, err := strconv.Atoi(eventIDStr); err == nil {
			doc.CaseEventID = &eid
		}
	}

	id, err := h.repo.Create(r.Context(), doc)
	if err != nil {
		writeError(w, http.StatusInternalServerError, "INTERNAL", err.Error())
		return
	}

	created, _ := h.repo.GetByID(r.Context(), id)
	writeJSON(w, http.StatusCreated, map[string]interface{}{"data": created})
}

// Summarize handles POST /api/documents/{id}/summarize
// Queues the document for AI summarization via SQS.
func (h *DocumentHandler) Summarize(w http.ResponseWriter, r *http.Request) {
	id, err := strconv.Atoi(chi.URLParam(r, "id"))
	if err != nil {
		writeError(w, http.StatusBadRequest, "INVALID_ID", "Invalid document ID")
		return
	}

	doc, err := h.repo.GetByID(r.Context(), id)
	if err != nil {
		writeError(w, http.StatusInternalServerError, "INTERNAL", err.Error())
		return
	}
	if doc == nil {
		writeError(w, http.StatusNotFound, "NOT_FOUND", "Document not found")
		return
	}

	// TODO: Send SQS message to summarize queue
	// sqs.SendMessage(ctx, h.cfg.SQSSummarizeURL, {doc_id, s3_key})

	writeJSON(w, http.StatusAccepted, map[string]interface{}{
		"status":  "queued",
		"doc_id":  doc.ID,
		"message": "Document queued for summarization",
	})
}

// DownloadPacer handles POST /api/documents/{id}/download-pacer
func (h *DocumentHandler) DownloadPacer(w http.ResponseWriter, r *http.Request) {
	id, err := strconv.Atoi(chi.URLParam(r, "id"))
	if err != nil {
		writeError(w, http.StatusBadRequest, "INVALID_ID", "Invalid document ID")
		return
	}

	_ = id
	// TODO: Implement PACER download via SQS queue
	writeJSON(w, http.StatusAccepted, map[string]string{
		"status":  "queued",
		"message": "PACER download queued",
	})
}

// Ask handles POST /api/documents/{id}/ask
func (h *DocumentHandler) Ask(w http.ResponseWriter, r *http.Request) {
	id, err := strconv.Atoi(chi.URLParam(r, "id"))
	if err != nil {
		writeError(w, http.StatusBadRequest, "INVALID_ID", "Invalid document ID")
		return
	}

	var req model.AskQuestionRequest
	if err := decodeJSON(r, &req); err != nil {
		writeError(w, http.StatusBadRequest, "INVALID_JSON", "Invalid request body")
		return
	}
	if err := h.validate.Struct(req); err != nil {
		writeError(w, http.StatusBadRequest, "VALIDATION", err.Error())
		return
	}

	_ = id
	// TODO: Send to Q&A SQS queue and await response
	writeJSON(w, http.StatusAccepted, map[string]string{
		"status":  "queued",
		"message": "Question queued for processing",
	})
}

// GetConversations handles GET /api/documents/{id}/conversations
func (h *DocumentHandler) GetConversations(w http.ResponseWriter, r *http.Request) {
	id, err := strconv.Atoi(chi.URLParam(r, "id"))
	if err != nil {
		writeError(w, http.StatusBadRequest, "INVALID_ID", "Invalid document ID")
		return
	}

	entries, err := h.repo.GetConversationHistory(r.Context(), id)
	if err != nil {
		writeError(w, http.StatusInternalServerError, "INTERNAL", err.Error())
		return
	}

	if entries == nil {
		entries = []model.ConversationEntry{}
	}
	writeJSON(w, http.StatusOK, map[string]interface{}{"data": entries})
}

// SaveQCFeedback handles POST /api/documents/{id}/qc-feedback
func (h *DocumentHandler) SaveQCFeedback(w http.ResponseWriter, r *http.Request) {
	id, err := strconv.Atoi(chi.URLParam(r, "id"))
	if err != nil {
		writeError(w, http.StatusBadRequest, "INVALID_ID", "Invalid document ID")
		return
	}

	var req model.QCFeedbackRequest
	if err := decodeJSON(r, &req); err != nil {
		writeError(w, http.StatusBadRequest, "INVALID_JSON", "Invalid request body")
		return
	}
	if err := h.validate.Struct(req); err != nil {
		writeError(w, http.StatusBadRequest, "VALIDATION", err.Error())
		return
	}

	user := auth.GetUser(r.Context())
	username := "anonymous"
	if user != nil {
		username = user.Username
	}

	if err := h.repo.SaveQCFeedback(r.Context(), id, req, username); err != nil {
		writeError(w, http.StatusInternalServerError, "INTERNAL", err.Error())
		return
	}

	writeJSON(w, http.StatusCreated, map[string]string{"status": "saved"})
}

// SavePromptFeedback handles POST /api/documents/{id}/prompt-feedback
func (h *DocumentHandler) SavePromptFeedback(w http.ResponseWriter, r *http.Request) {
	var req model.PromptFeedbackRequest
	if err := decodeJSON(r, &req); err != nil {
		writeError(w, http.StatusBadRequest, "INVALID_JSON", "Invalid request body")
		return
	}
	if err := h.validate.Struct(req); err != nil {
		writeError(w, http.StatusBadRequest, "VALIDATION", err.Error())
		return
	}

	if err := h.repo.SavePromptFeedback(r.Context(), req); err != nil {
		writeError(w, http.StatusInternalServerError, "INTERNAL", err.Error())
		return
	}

	writeJSON(w, http.StatusOK, map[string]string{"status": "saved"})
}
