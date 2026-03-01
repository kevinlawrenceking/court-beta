package repository

import (
	"context"
	"fmt"
	"strings"
	"time"

	"github.com/jackc/pgx/v5"
	"github.com/jackc/pgx/v5/pgxpool"
	"github.com/tmz/docketwatch-api/internal/model"
)

// EventRepo handles database operations for case events.
type EventRepo struct {
	pool *pgxpool.Pool
}

// NewEventRepo creates a new EventRepo.
func NewEventRepo(pool *pgxpool.Pool) *EventRepo {
	return &EventRepo{pool: pool}
}

// List returns a paginated, filtered list of events.
func (r *EventRepo) List(ctx context.Context, filter model.EventFilter, pg model.Pagination) ([]model.Event, int, error) {
	where, args := buildEventWhere(filter)

	var total int
	countSQL := "SELECT COUNT(*) FROM case_events e" + where
	if err := r.pool.QueryRow(ctx, countSQL, args...).Scan(&total); err != nil {
		return nil, 0, fmt.Errorf("count events: %w", err)
	}

	sortCol := allowedEventSort(pg.Sort)
	dataSQL := fmt.Sprintf(`
		SELECT e.id, e.fk_case, e.event_date, e.event_description, e.event_url,
		       e.is_doc, e.acknowledged, e.acknowledged_at, e.acknowledged_by,
		       e.processing, e.storyworthy, e.created_at
		FROM case_events e
		%s
		ORDER BY %s %s
		LIMIT $%d OFFSET $%d
	`, where, sortCol, pg.Order, len(args)+1, len(args)+2)

	args = append(args, pg.PerPage, pg.Offset())

	rows, err := r.pool.Query(ctx, dataSQL, args...)
	if err != nil {
		return nil, 0, fmt.Errorf("list events: %w", err)
	}
	defer rows.Close()

	var events []model.Event
	for rows.Next() {
		var e model.Event
		if err := rows.Scan(
			&e.ID, &e.CaseID, &e.EventDate, &e.EventDescription, &e.EventURL,
			&e.IsDoc, &e.Acknowledged, &e.AcknowledgedAt, &e.AcknowledgedBy,
			&e.Processing, &e.Storyworthy, &e.CreatedAt,
		); err != nil {
			return nil, 0, fmt.Errorf("scan event: %w", err)
		}
		events = append(events, e)
	}

	return events, total, nil
}

// GetByID returns a single event by ID.
func (r *EventRepo) GetByID(ctx context.Context, id int) (*model.Event, error) {
	sql := `
		SELECT e.id, e.fk_case, e.event_date, e.event_description, e.event_url,
		       e.is_doc, e.acknowledged, e.acknowledged_at, e.acknowledged_by,
		       e.processing, e.storyworthy, e.created_at
		FROM case_events e
		WHERE e.id = $1
	`
	var e model.Event
	err := r.pool.QueryRow(ctx, sql, id).Scan(
		&e.ID, &e.CaseID, &e.EventDate, &e.EventDescription, &e.EventURL,
		&e.IsDoc, &e.Acknowledged, &e.AcknowledgedAt, &e.AcknowledgedBy,
		&e.Processing, &e.Storyworthy, &e.CreatedAt,
	)
	if err == pgx.ErrNoRows {
		return nil, nil
	}
	if err != nil {
		return nil, fmt.Errorf("get event %d: %w", id, err)
	}
	return &e, nil
}

// Acknowledge marks an event as acknowledged.
func (r *EventRepo) Acknowledge(ctx context.Context, id int, username string) error {
	now := time.Now()
	_, err := r.pool.Exec(ctx,
		"UPDATE case_events SET acknowledged = TRUE, acknowledged_at = $1, acknowledged_by = $2 WHERE id = $3",
		now, username, id,
	)
	if err != nil {
		return fmt.Errorf("acknowledge event %d: %w", id, err)
	}
	return nil
}

// BulkAcknowledge marks multiple events as acknowledged.
func (r *EventRepo) BulkAcknowledge(ctx context.Context, ids []int, username string) error {
	now := time.Now()
	_, err := r.pool.Exec(ctx,
		"UPDATE case_events SET acknowledged = TRUE, acknowledged_at = $1, acknowledged_by = $2 WHERE id = ANY($3)",
		now, username, ids,
	)
	if err != nil {
		return fmt.Errorf("bulk acknowledge: %w", err)
	}
	return nil
}

// RecentForMonitor returns the most recent events for the live monitor.
func (r *EventRepo) RecentForMonitor(ctx context.Context, limit int) ([]model.Event, error) {
	sql := `
		SELECT e.id, e.fk_case, e.event_date, e.event_description, e.event_url,
		       e.is_doc, e.acknowledged, e.acknowledged_at, e.acknowledged_by,
		       e.processing, e.storyworthy, e.created_at
		FROM case_events e
		ORDER BY e.created_at DESC
		LIMIT $1
	`
	rows, err := r.pool.Query(ctx, sql, limit)
	if err != nil {
		return nil, fmt.Errorf("recent events: %w", err)
	}
	defer rows.Close()

	var events []model.Event
	for rows.Next() {
		var e model.Event
		if err := rows.Scan(
			&e.ID, &e.CaseID, &e.EventDate, &e.EventDescription, &e.EventURL,
			&e.IsDoc, &e.Acknowledged, &e.AcknowledgedAt, &e.AcknowledgedBy,
			&e.Processing, &e.Storyworthy, &e.CreatedAt,
		); err != nil {
			return nil, fmt.Errorf("scan monitor event: %w", err)
		}
		events = append(events, e)
	}

	return events, nil
}

func buildEventWhere(f model.EventFilter) (string, []interface{}) {
	conditions := []string{}
	args := []interface{}{}
	n := 1

	if f.CaseID != nil {
		conditions = append(conditions, fmt.Sprintf("e.fk_case = $%d", n))
		args = append(args, *f.CaseID)
		n++
	}
	if f.Acknowledged != nil {
		conditions = append(conditions, fmt.Sprintf("e.acknowledged = $%d", n))
		args = append(args, *f.Acknowledged)
		n++
	}
	if f.IsDoc != nil {
		conditions = append(conditions, fmt.Sprintf("e.is_doc = $%d", n))
		args = append(args, *f.IsDoc)
		n++
	}
	if f.Storyworthy != nil {
		conditions = append(conditions, fmt.Sprintf("e.storyworthy = $%d", n))
		args = append(args, *f.Storyworthy)
		n++
	}

	if len(conditions) == 0 {
		return "", args
	}
	return " WHERE " + strings.Join(conditions, " AND "), args
}

func allowedEventSort(col string) string {
	allowed := map[string]string{
		"id":          "e.id",
		"event_date":  "e.event_date",
		"created_at":  "e.created_at",
	}
	if v, ok := allowed[col]; ok {
		return v
	}
	return "e.created_at"
}
