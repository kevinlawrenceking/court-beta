package worker

import (
	"context"
	"time"

	"github.com/jackc/pgx/v5/pgxpool"
	"github.com/rs/zerolog/log"

	"github.com/tmz/docketwatch-api/internal/storage"
)

// CleanupWorker performs periodic maintenance tasks.
// Replaces: daily_removal.cfm, cleanup_removed_unfiled_pdfs.cfm, cleaner.cfm
type CleanupWorker struct {
	pool     *pgxpool.Pool
	s3Store  *storage.S3Store
	bucket   string
	interval time.Duration
}

// NewCleanupWorker creates a new cleanup worker.
func NewCleanupWorker(pool *pgxpool.Pool, s3Store *storage.S3Store, bucket string, interval time.Duration) *CleanupWorker {
	return &CleanupWorker{
		pool:     pool,
		s3Store:  s3Store,
		bucket:   bucket,
		interval: interval,
	}
}

// Start begins the cleanup loop. Blocks until context is canceled.
func (w *CleanupWorker) Start(ctx context.Context) {
	log.Info().Dur("interval", w.interval).Msg("Cleanup worker started")

	ticker := time.NewTicker(w.interval)
	defer ticker.Stop()

	for {
		select {
		case <-ctx.Done():
			log.Info().Msg("Cleanup worker stopped")
			return
		case <-ticker.C:
			w.runCleanup(ctx)
		}
	}
}

func (w *CleanupWorker) runCleanup(ctx context.Context) {
	log.Info().Msg("Running cleanup tasks...")

	w.cleanupRemovedCaseDocs(ctx)
	w.cleanupOrphanedDocuments(ctx)
	w.cleanupOldErrorLogs(ctx)
	w.logTaskRun(ctx, "cleanup", "success", "")
}

// cleanupRemovedCaseDocs deletes S3 objects for documents belonging to removed cases.
func (w *CleanupWorker) cleanupRemovedCaseDocs(ctx context.Context) {
	rows, err := w.pool.Query(ctx, `
		SELECT d.id, d.s3_key
		FROM documents d
		JOIN case_events ce ON d.fk_case_event = ce.id
		JOIN cases c ON ce.fk_case = c.id
		WHERE c.status = 'Removed'
		AND d.s3_key IS NOT NULL
		AND d.s3_key != ''
		LIMIT 50
	`)
	if err != nil {
		log.Error().Err(err).Msg("Failed to query removed case docs")
		return
	}
	defer rows.Close()

	deleteCount := 0
	for rows.Next() {
		var docID int
		var s3Key string
		if err := rows.Scan(&docID, &s3Key); err != nil {
			continue
		}

		if err := w.s3Store.DeleteObject(ctx, w.bucket, s3Key); err != nil {
			log.Error().Err(err).Str("s3_key", s3Key).Msg("Failed to delete S3 object")
			continue
		}

		// Clear the S3 key in the database
		_, err := w.pool.Exec(ctx, "UPDATE documents SET s3_key = NULL WHERE id = $1", docID)
		if err != nil {
			log.Error().Err(err).Int("doc_id", docID).Msg("Failed to clear S3 key")
		}
		deleteCount++
	}

	if deleteCount > 0 {
		log.Info().Int("deleted", deleteCount).Msg("Cleaned up removed case documents")
	}
}

// cleanupOrphanedDocuments removes document records with no case event link.
func (w *CleanupWorker) cleanupOrphanedDocuments(ctx context.Context) {
	result, err := w.pool.Exec(ctx, `
		DELETE FROM documents
		WHERE fk_case_event IS NULL
		AND created_at < NOW() - INTERVAL '30 days'
		AND s3_key IS NULL
	`)
	if err != nil {
		log.Error().Err(err).Msg("Failed to cleanup orphaned docs")
		return
	}

	if result.RowsAffected() > 0 {
		log.Info().Int64("deleted", result.RowsAffected()).Msg("Cleaned up orphaned documents")
	}
}

// cleanupOldErrorLogs removes resolved error logs older than 90 days.
func (w *CleanupWorker) cleanupOldErrorLogs(ctx context.Context) {
	result, err := w.pool.Exec(ctx, `
		DELETE FROM error_logs
		WHERE resolved = TRUE
		AND created_at < NOW() - INTERVAL '90 days'
	`)
	if err != nil {
		log.Error().Err(err).Msg("Failed to cleanup error logs")
		return
	}

	if result.RowsAffected() > 0 {
		log.Info().Int64("deleted", result.RowsAffected()).Msg("Cleaned up old error logs")
	}
}

func (w *CleanupWorker) logTaskRun(ctx context.Context, taskName, status, errMsg string) {
	_, err := w.pool.Exec(ctx, `
		INSERT INTO scheduled_task_log (task_name, status, started_at, completed_at, duration_ms)
		VALUES ($1, $2, NOW(), NOW(), 0)
	`, taskName, status)
	if err != nil {
		log.Error().Err(err).Msg("Failed to log task run")
	}
}
