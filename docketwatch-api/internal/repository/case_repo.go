package repository

import (
	"context"
	"fmt"
	"strings"

	"github.com/jackc/pgx/v5"
	"github.com/jackc/pgx/v5/pgxpool"
	"github.com/tmz/docketwatch-api/internal/model"
)

// CaseRepo handles database operations for cases.
type CaseRepo struct {
	pool *pgxpool.Pool
}

// NewCaseRepo creates a new CaseRepo.
func NewCaseRepo(pool *pgxpool.Pool) *CaseRepo {
	return &CaseRepo{pool: pool}
}

// List returns a paginated, filtered list of cases.
func (r *CaseRepo) List(ctx context.Context, filter model.CaseFilter, pg model.Pagination) ([]model.Case, int, error) {
	where, args := buildCaseWhere(filter)

	// Count query
	countSQL := "SELECT COUNT(*) FROM cases c" + where
	var total int
	if err := r.pool.QueryRow(ctx, countSQL, args...).Scan(&total); err != nil {
		return nil, 0, fmt.Errorf("count cases: %w", err)
	}

	// Allow-listed sort columns to prevent SQL injection
	sortCol := allowedCaseSort(pg.Sort)
	dataSQL := fmt.Sprintf(`
		SELECT c.id, c.case_number, c.case_name, c.case_type, c.court_code,
		       c.status, c.owner, c.tool_id, c.filing_date, c.created_at, c.updated_at,
		       (SELECT COUNT(*) FROM case_events WHERE fk_case = c.id) AS event_count,
		       (SELECT COUNT(*) FROM documents d JOIN case_events ce ON d.fk_case_event = ce.id WHERE ce.fk_case = c.id) AS doc_count
		FROM cases c
		%s
		ORDER BY %s %s
		LIMIT $%d OFFSET $%d
	`, where, sortCol, pg.Order, len(args)+1, len(args)+2)

	args = append(args, pg.PerPage, pg.Offset())

	rows, err := r.pool.Query(ctx, dataSQL, args...)
	if err != nil {
		return nil, 0, fmt.Errorf("list cases: %w", err)
	}
	defer rows.Close()

	var cases []model.Case
	for rows.Next() {
		var c model.Case
		if err := rows.Scan(
			&c.ID, &c.CaseNumber, &c.CaseName, &c.CaseType, &c.CourtCode,
			&c.Status, &c.Owner, &c.ToolID, &c.FilingDate, &c.CreatedAt, &c.UpdatedAt,
			&c.EventCount, &c.DocCount,
		); err != nil {
			return nil, 0, fmt.Errorf("scan case: %w", err)
		}
		cases = append(cases, c)
	}

	return cases, total, nil
}

// GetByID returns a single case by ID with related data.
func (r *CaseRepo) GetByID(ctx context.Context, id int) (*model.Case, error) {
	sql := `
		SELECT c.id, c.case_number, c.case_name, c.case_type, c.court_code,
		       c.status, c.owner, c.tool_id, c.filing_date, c.created_at, c.updated_at
		FROM cases c
		WHERE c.id = $1
	`
	var c model.Case
	err := r.pool.QueryRow(ctx, sql, id).Scan(
		&c.ID, &c.CaseNumber, &c.CaseName, &c.CaseType, &c.CourtCode,
		&c.Status, &c.Owner, &c.ToolID, &c.FilingDate, &c.CreatedAt, &c.UpdatedAt,
	)
	if err == pgx.ErrNoRows {
		return nil, nil
	}
	if err != nil {
		return nil, fmt.Errorf("get case %d: %w", id, err)
	}
	return &c, nil
}

// Create inserts a new case and returns its ID.
func (r *CaseRepo) Create(ctx context.Context, req model.CreateCaseRequest) (int, error) {
	sql := `
		INSERT INTO cases (case_number, case_name, case_type, court_code, status, owner, tool_id)
		VALUES ($1, $2, $3, $4, COALESCE(NULLIF($5,''), 'Review'), $6, $7)
		RETURNING id
	`
	var id int
	err := r.pool.QueryRow(ctx, sql,
		req.CaseNumber, req.CaseName, req.CaseType, req.CourtCode,
		req.Status, req.Owner, req.ToolID,
	).Scan(&id)
	if err != nil {
		return 0, fmt.Errorf("create case: %w", err)
	}
	return id, nil
}

// Update modifies an existing case.
func (r *CaseRepo) Update(ctx context.Context, id int, req model.UpdateCaseRequest) error {
	sets := []string{}
	args := []interface{}{}
	argN := 1

	if req.CaseNumber != nil {
		sets = append(sets, fmt.Sprintf("case_number = $%d", argN))
		args = append(args, *req.CaseNumber)
		argN++
	}
	if req.CaseName != nil {
		sets = append(sets, fmt.Sprintf("case_name = $%d", argN))
		args = append(args, *req.CaseName)
		argN++
	}
	if req.CaseType != nil {
		sets = append(sets, fmt.Sprintf("case_type = $%d", argN))
		args = append(args, *req.CaseType)
		argN++
	}
	if req.CourtCode != nil {
		sets = append(sets, fmt.Sprintf("court_code = $%d", argN))
		args = append(args, *req.CourtCode)
		argN++
	}
	if req.Status != nil {
		sets = append(sets, fmt.Sprintf("status = $%d", argN))
		args = append(args, *req.Status)
		argN++
	}
	if req.Owner != nil {
		sets = append(sets, fmt.Sprintf("owner = $%d", argN))
		args = append(args, *req.Owner)
		argN++
	}
	if req.ToolID != nil {
		sets = append(sets, fmt.Sprintf("tool_id = $%d", argN))
		args = append(args, *req.ToolID)
		argN++
	}

	if len(sets) == 0 {
		return nil
	}

	sql := fmt.Sprintf("UPDATE cases SET %s WHERE id = $%d", strings.Join(sets, ", "), argN)
	args = append(args, id)

	_, err := r.pool.Exec(ctx, sql, args...)
	if err != nil {
		return fmt.Errorf("update case %d: %w", id, err)
	}
	return nil
}

// UpdateStatus changes the status of a single case.
func (r *CaseRepo) UpdateStatus(ctx context.Context, id int, status string) error {
	_, err := r.pool.Exec(ctx, "UPDATE cases SET status = $1 WHERE id = $2", status, id)
	if err != nil {
		return fmt.Errorf("update case status: %w", err)
	}
	return nil
}

// BulkUpdateStatus changes the status of multiple cases.
func (r *CaseRepo) BulkUpdateStatus(ctx context.Context, ids []int, status string) error {
	_, err := r.pool.Exec(ctx, "UPDATE cases SET status = $1 WHERE id = ANY($2)", status, ids)
	if err != nil {
		return fmt.Errorf("bulk update case status: %w", err)
	}
	return nil
}

// Delete removes a case by ID.
func (r *CaseRepo) Delete(ctx context.Context, id int) error {
	_, err := r.pool.Exec(ctx, "DELETE FROM cases WHERE id = $1", id)
	if err != nil {
		return fmt.Errorf("delete case %d: %w", id, err)
	}
	return nil
}

func buildCaseWhere(f model.CaseFilter) (string, []interface{}) {
	conditions := []string{}
	args := []interface{}{}
	n := 1

	if f.Status != "" {
		conditions = append(conditions, fmt.Sprintf("c.status = $%d", n))
		args = append(args, f.Status)
		n++
	}
	if f.ToolID != nil {
		conditions = append(conditions, fmt.Sprintf("c.tool_id = $%d", n))
		args = append(args, *f.ToolID)
		n++
	}
	if f.StateCode != "" {
		conditions = append(conditions, fmt.Sprintf("c.court_code IN (SELECT court_code FROM courts ct JOIN counties co ON ct.fk_county = co.id WHERE co.state_code = $%d)", n))
		args = append(args, f.StateCode)
		n++
	}
	if f.CountyID != nil {
		conditions = append(conditions, fmt.Sprintf("c.court_code IN (SELECT court_code FROM courts WHERE fk_county = $%d)", n))
		args = append(args, *f.CountyID)
		n++
	}
	if f.CourtCode != "" {
		conditions = append(conditions, fmt.Sprintf("c.court_code = $%d", n))
		args = append(args, f.CourtCode)
		n++
	}
	if f.CelebrityID != nil {
		conditions = append(conditions, fmt.Sprintf("c.id IN (SELECT fk_case FROM case_celebrity_matches WHERE fk_celebrity = $%d AND match_status != 'Removed')", n))
		args = append(args, *f.CelebrityID)
		n++
	}
	if f.Owner != "" {
		conditions = append(conditions, fmt.Sprintf("c.owner = $%d", n))
		args = append(args, f.Owner)
		n++
	}
	if f.Query != "" {
		conditions = append(conditions, fmt.Sprintf("to_tsvector('english', COALESCE(c.case_name,'') || ' ' || COALESCE(c.case_number,'')) @@ plainto_tsquery('english', $%d)", n))
		args = append(args, f.Query)
		n++
	}

	if len(conditions) == 0 {
		return "", args
	}
	return " WHERE " + strings.Join(conditions, " AND "), args
}

func allowedCaseSort(col string) string {
	allowed := map[string]string{
		"id":          "c.id",
		"case_number": "c.case_number",
		"case_name":   "c.case_name",
		"status":      "c.status",
		"created_at":  "c.created_at",
		"updated_at":  "c.updated_at",
		"filing_date": "c.filing_date",
	}
	if v, ok := allowed[col]; ok {
		return v
	}
	return "c.created_at"
}
