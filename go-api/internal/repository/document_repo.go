package repository

import (
	"context"
	"fmt"

	"github.com/google/uuid"
	"github.com/jackc/pgx/v5"
	"github.com/jackc/pgx/v5/pgxpool"
	"github.com/tmz/docketwatch-api/internal/model"
)

// DocumentRepo handles database operations for documents.
type DocumentRepo struct {
	pool *pgxpool.Pool
}

// NewDocumentRepo creates a new DocumentRepo.
func NewDocumentRepo(pool *pgxpool.Pool) *DocumentRepo {
	return &DocumentRepo{pool: pool}
}

// GetByID returns a document by ID.
func (r *DocumentRepo) GetByID(ctx context.Context, id int) (*model.Document, error) {
	sql := `
		SELECT id, doc_uid, fk_case_event, pdf_title, rel_path, s3_key,
		       file_size, sha256_hash, ocr_text, summary_ai, summary_ai_html,
		       summary_ai_extraction_json, model_name, processing_ms,
		       tokens_input, tokens_output, created_at
		FROM documents WHERE id = $1
	`
	var d model.Document
	err := r.pool.QueryRow(ctx, sql, id).Scan(
		&d.ID, &d.DocUID, &d.CaseEventID, &d.PDFTitle, &d.RelPath, &d.S3Key,
		&d.FileSize, &d.SHA256Hash, &d.OCRText, &d.SummaryAI, &d.SummaryAIHTML,
		&d.SummaryAIExtraction, &d.ModelName, &d.ProcessingMs,
		&d.TokensInput, &d.TokensOutput, &d.CreatedAt,
	)
	if err == pgx.ErrNoRows {
		return nil, nil
	}
	if err != nil {
		return nil, fmt.Errorf("get document %d: %w", id, err)
	}
	return &d, nil
}

// GetByDocUID returns a document by its UUID.
func (r *DocumentRepo) GetByDocUID(ctx context.Context, uid uuid.UUID) (*model.Document, error) {
	sql := `
		SELECT id, doc_uid, fk_case_event, pdf_title, rel_path, s3_key,
		       file_size, sha256_hash, ocr_text, summary_ai, summary_ai_html,
		       summary_ai_extraction_json, model_name, processing_ms,
		       tokens_input, tokens_output, created_at
		FROM documents WHERE doc_uid = $1
	`
	var d model.Document
	err := r.pool.QueryRow(ctx, sql, uid).Scan(
		&d.ID, &d.DocUID, &d.CaseEventID, &d.PDFTitle, &d.RelPath, &d.S3Key,
		&d.FileSize, &d.SHA256Hash, &d.OCRText, &d.SummaryAI, &d.SummaryAIHTML,
		&d.SummaryAIExtraction, &d.ModelName, &d.ProcessingMs,
		&d.TokensInput, &d.TokensOutput, &d.CreatedAt,
	)
	if err == pgx.ErrNoRows {
		return nil, nil
	}
	if err != nil {
		return nil, fmt.Errorf("get document by uid: %w", err)
	}
	return &d, nil
}

// Create inserts a new document record and returns its ID.
func (r *DocumentRepo) Create(ctx context.Context, d *model.Document) (int, error) {
	sql := `
		INSERT INTO documents (fk_case_event, pdf_title, s3_key, file_size, sha256_hash)
		VALUES ($1, $2, $3, $4, $5)
		RETURNING id, doc_uid
	`
	err := r.pool.QueryRow(ctx, sql,
		d.CaseEventID, d.PDFTitle, d.S3Key, d.FileSize, d.SHA256Hash,
	).Scan(&d.ID, &d.DocUID)
	if err != nil {
		return 0, fmt.Errorf("create document: %w", err)
	}
	return d.ID, nil
}

// UpdateSummary updates the AI summary fields for a document.
func (r *DocumentRepo) UpdateSummary(ctx context.Context, id int, summaryAI, summaryHTML string, extractionJSON []byte, modelName string, processingMs, tokensIn, tokensOut int) error {
	sql := `
		UPDATE documents
		SET summary_ai = $1, summary_ai_html = $2, summary_ai_extraction_json = $3,
		    model_name = $4, processing_ms = $5, tokens_input = $6, tokens_output = $7
		WHERE id = $8
	`
	_, err := r.pool.Exec(ctx, sql,
		summaryAI, summaryHTML, extractionJSON, modelName, processingMs, tokensIn, tokensOut, id,
	)
	if err != nil {
		return fmt.Errorf("update summary for doc %d: %w", id, err)
	}
	return nil
}

// UpdateOCR sets the OCR text for a document.
func (r *DocumentRepo) UpdateOCR(ctx context.Context, id int, ocrText string) error {
	_, err := r.pool.Exec(ctx, "UPDATE documents SET ocr_text = $1 WHERE id = $2", ocrText, id)
	if err != nil {
		return fmt.Errorf("update ocr for doc %d: %w", id, err)
	}
	return nil
}

// ListByEvent returns all documents for a given case event.
func (r *DocumentRepo) ListByEvent(ctx context.Context, eventID int) ([]model.Document, error) {
	sql := `
		SELECT id, doc_uid, fk_case_event, pdf_title, s3_key, file_size,
		       sha256_hash, model_name, processing_ms, created_at
		FROM documents WHERE fk_case_event = $1
		ORDER BY created_at DESC
	`
	rows, err := r.pool.Query(ctx, sql, eventID)
	if err != nil {
		return nil, fmt.Errorf("list docs by event: %w", err)
	}
	defer rows.Close()

	var docs []model.Document
	for rows.Next() {
		var d model.Document
		if err := rows.Scan(
			&d.ID, &d.DocUID, &d.CaseEventID, &d.PDFTitle, &d.S3Key, &d.FileSize,
			&d.SHA256Hash, &d.ModelName, &d.ProcessingMs, &d.CreatedAt,
		); err != nil {
			return nil, fmt.Errorf("scan document: %w", err)
		}
		docs = append(docs, d)
	}
	return docs, nil
}

// SaveQCFeedback inserts a QC feedback record.
func (r *DocumentRepo) SaveQCFeedback(ctx context.Context, docID int, req model.QCFeedbackRequest, username string) error {
	sql := `
		INSERT INTO summary_qc_feedback (fk_document, rating, notes, model_name, upload_sha256, username)
		VALUES ($1, $2, $3, $4, $5, $6)
	`
	_, err := r.pool.Exec(ctx, sql, docID, req.Rating, req.Notes, req.ModelName, req.UploadSHA, username)
	if err != nil {
		return fmt.Errorf("save qc feedback: %w", err)
	}
	return nil
}

// SavePromptFeedback updates the rating and feedback for a document prompt.
func (r *DocumentRepo) SavePromptFeedback(ctx context.Context, req model.PromptFeedbackRequest) error {
	sql := `UPDATE document_prompts SET rating = $1, feedback = $2 WHERE id = $3`
	_, err := r.pool.Exec(ctx, sql, req.Rating, req.Feedback, req.PromptID)
	if err != nil {
		return fmt.Errorf("save prompt feedback: %w", err)
	}
	return nil
}

// GetConversationHistory returns all Q&A entries for a document.
func (r *DocumentRepo) GetConversationHistory(ctx context.Context, docID int) ([]model.ConversationEntry, error) {
	sql := `
		SELECT id, fk_document, session_id, prompt_text, response_text,
		       model_name, tokens_input, tokens_output, rating, feedback, created_at
		FROM document_prompts
		WHERE fk_document = $1
		ORDER BY created_at ASC
	`
	rows, err := r.pool.Query(ctx, sql, docID)
	if err != nil {
		return nil, fmt.Errorf("get conversations: %w", err)
	}
	defer rows.Close()

	var entries []model.ConversationEntry
	for rows.Next() {
		var e model.ConversationEntry
		if err := rows.Scan(
			&e.ID, &e.DocumentID, &e.SessionID, &e.PromptText, &e.ResponseText,
			&e.ModelName, &e.TokensInput, &e.TokensOutput, &e.Rating, &e.Feedback, &e.CreatedAt,
		); err != nil {
			return nil, fmt.Errorf("scan conversation: %w", err)
		}
		entries = append(entries, e)
	}
	return entries, nil
}
