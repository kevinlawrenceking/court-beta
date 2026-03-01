package repository

import (
	"context"
	"strconv"

	"github.com/jackc/pgx/v5/pgxpool"
	"github.com/tmz/docketwatch-api/internal/model"
)

// AdminRepo handles queries for admin/monitoring data.
type AdminRepo struct {
	pool *pgxpool.Pool
}

// NewAdminRepo creates a new AdminRepo.
func NewAdminRepo(pool *pgxpool.Pool) *AdminRepo {
	return &AdminRepo{pool: pool}
}

// ListTaskLogs returns recent scheduled task log entries.
func (r *AdminRepo) ListTaskLogs(ctx context.Context, limit int) ([]model.TaskLog, error) {
	if limit <= 0 || limit > 200 {
		limit = 50
	}

	rows, err := r.pool.Query(ctx, `
		SELECT id, task_name, status, started_at, completed_at, duration_ms,
		       COALESCE(result, ''), COALESCE(error_message, '')
		FROM scheduled_task_log
		ORDER BY started_at DESC
		LIMIT $1
	`, limit)
	if err != nil {
		return nil, err
	}
	defer rows.Close()

	var logs []model.TaskLog
	for rows.Next() {
		var t model.TaskLog
		if err := rows.Scan(&t.ID, &t.TaskName, &t.Status, &t.StartedAt,
			&t.CompletedAt, &t.DurationMs, &t.Result, &t.ErrorMessage); err != nil {
			return nil, err
		}
		logs = append(logs, t)
	}
	return logs, nil
}

// ListErrorLogs returns error log entries with optional filtering.
func (r *AdminRepo) ListErrorLogs(ctx context.Context, severity string, resolved *bool, limit int) ([]model.ErrorLog, error) {
	if limit <= 0 || limit > 500 {
		limit = 100
	}

	query := `SELECT id, COALESCE(script_name, ''), COALESCE(error_type, ''),
	                 COALESCE(message, ''), COALESCE(detail, ''), COALESCE(severity, 'error'),
	                 resolved, created_at
	          FROM error_logs WHERE 1=1`
	args := []interface{}{}
	argIdx := 1

	if severity != "" {
		query += ` AND severity = $` + itoa(argIdx)
		args = append(args, severity)
		argIdx++
	}
	if resolved != nil {
		query += ` AND resolved = $` + itoa(argIdx)
		args = append(args, *resolved)
		argIdx++
	}

	query += ` ORDER BY created_at DESC LIMIT $` + itoa(argIdx)
	args = append(args, limit)

	rows, err := r.pool.Query(ctx, query, args...)
	if err != nil {
		return nil, err
	}
	defer rows.Close()

	var logs []model.ErrorLog
	for rows.Next() {
		var e model.ErrorLog
		if err := rows.Scan(&e.ID, &e.ScriptName, &e.ErrorType, &e.Message,
			&e.Detail, &e.Severity, &e.Resolved, &e.CreatedAt); err != nil {
			return nil, err
		}
		logs = append(logs, e)
	}
	return logs, nil
}

// ResolveErrors marks errors as resolved.
func (r *AdminRepo) ResolveErrors(ctx context.Context, ids []int) (int64, error) {
	result, err := r.pool.Exec(ctx, `
		UPDATE error_logs SET resolved = TRUE WHERE id = ANY($1)
	`, ids)
	if err != nil {
		return 0, err
	}
	return result.RowsAffected(), nil
}

// ListGeminiAPILogs returns recent Gemini API call logs.
func (r *AdminRepo) ListGeminiAPILogs(ctx context.Context, limit int) ([]model.GeminiAPILog, error) {
	if limit <= 0 || limit > 200 {
		limit = 50
	}

	rows, err := r.pool.Query(ctx, `
		SELECT id, COALESCE(script_name, ''), COALESCE(model_name, ''),
		       input_tokens, output_tokens, success,
		       COALESCE(error_message, ''), processing_time_ms,
		       COALESCE(cost_estimate, 0), created_at
		FROM gemini_api_log
		ORDER BY created_at DESC
		LIMIT $1
	`, limit)
	if err != nil {
		return nil, err
	}
	defer rows.Close()

	var logs []model.GeminiAPILog
	for rows.Next() {
		var g model.GeminiAPILog
		if err := rows.Scan(&g.ID, &g.ScriptName, &g.ModelName, &g.InputTokens,
			&g.OutputTokens, &g.Success, &g.ErrorMessage, &g.ProcessingMs,
			&g.CostEstimate, &g.CreatedAt); err != nil {
			return nil, err
		}
		logs = append(logs, g)
	}
	return logs, nil
}

// ListArticles returns recent AI-generated articles.
func (r *AdminRepo) ListArticles(ctx context.Context, limit int) ([]model.Article, error) {
	if limit <= 0 || limit > 100 {
		limit = 50
	}

	rows, err := r.pool.Query(ctx, `
		SELECT id, case_id, headline, COALESCE(subhead, ''),
		       COALESCE(body_html, ''), COALESCE(image_url, ''),
		       COALESCE(model_name, ''), created_at
		FROM articles
		ORDER BY created_at DESC
		LIMIT $1
	`, limit)
	if err != nil {
		return nil, err
	}
	defer rows.Close()

	var articles []model.Article
	for rows.Next() {
		var a model.Article
		if err := rows.Scan(&a.ID, &a.CaseID, &a.Headline, &a.Subhead,
			&a.BodyHTML, &a.ImageURL, &a.ModelName, &a.CreatedAt); err != nil {
			return nil, err
		}
		articles = append(articles, a)
	}
	return articles, nil
}

func itoa(n int) string {
	return strconv.Itoa(n)
}
