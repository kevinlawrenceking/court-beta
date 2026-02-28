package repository

import (
	"context"
	"fmt"
	"strings"

	"github.com/jackc/pgx/v5/pgxpool"
	"github.com/tmz/docketwatch-api/internal/model"
)

// MatchRepo handles database operations for celebrity-case matches.
type MatchRepo struct {
	pool *pgxpool.Pool
}

// NewMatchRepo creates a new MatchRepo.
func NewMatchRepo(pool *pgxpool.Pool) *MatchRepo {
	return &MatchRepo{pool: pool}
}

// List returns a paginated, filtered list of matches.
func (r *MatchRepo) List(ctx context.Context, filter model.MatchFilter, pg model.Pagination) ([]model.CelebrityMatch, int, error) {
	where, args := buildMatchWhere(filter)

	var total int
	if err := r.pool.QueryRow(ctx, "SELECT COUNT(*) FROM case_celebrity_matches m"+where, args...).Scan(&total); err != nil {
		return nil, 0, fmt.Errorf("count matches: %w", err)
	}

	dataSQL := fmt.Sprintf(`
		SELECT m.id, m.fk_case, m.fk_celebrity, m.match_status, m.match_score, m.matched_by, m.created_at
		FROM case_celebrity_matches m
		%s
		ORDER BY m.created_at DESC
		LIMIT $%d OFFSET $%d
	`, where, len(args)+1, len(args)+2)

	args = append(args, pg.PerPage, pg.Offset())

	rows, err := r.pool.Query(ctx, dataSQL, args...)
	if err != nil {
		return nil, 0, fmt.Errorf("list matches: %w", err)
	}
	defer rows.Close()

	var matches []model.CelebrityMatch
	for rows.Next() {
		var m model.CelebrityMatch
		if err := rows.Scan(&m.ID, &m.CaseID, &m.CelebrityID, &m.MatchStatus, &m.MatchScore, &m.MatchedBy, &m.CreatedAt); err != nil {
			return nil, 0, fmt.Errorf("scan match: %w", err)
		}
		matches = append(matches, m)
	}
	return matches, total, nil
}

// Create inserts a new celebrity-case match.
func (r *MatchRepo) Create(ctx context.Context, req model.CreateMatchRequest) (int, error) {
	status := req.MatchStatus
	if status == "" {
		status = "Tracked"
	}
	var id int
	err := r.pool.QueryRow(ctx,
		`INSERT INTO case_celebrity_matches (fk_case, fk_celebrity, match_status)
		 VALUES ($1, $2, $3)
		 ON CONFLICT (fk_case, fk_celebrity) DO UPDATE SET match_status = $3
		 RETURNING id`,
		req.CaseID, req.CelebrityID, status,
	).Scan(&id)
	if err != nil {
		return 0, fmt.Errorf("create match: %w", err)
	}
	return id, nil
}

// UpdateStatus changes the match status.
func (r *MatchRepo) UpdateStatus(ctx context.Context, id int, status string) error {
	_, err := r.pool.Exec(ctx,
		"UPDATE case_celebrity_matches SET match_status = $1 WHERE id = $2",
		status, id,
	)
	if err != nil {
		return fmt.Errorf("update match status: %w", err)
	}
	return nil
}

// Delete soft-deletes a match by setting status to Removed.
func (r *MatchRepo) Delete(ctx context.Context, id int) error {
	_, err := r.pool.Exec(ctx,
		"UPDATE case_celebrity_matches SET match_status = 'Removed' WHERE id = $1", id,
	)
	if err != nil {
		return fmt.Errorf("delete match %d: %w", id, err)
	}
	return nil
}

// ListByCaseID returns all non-removed matches for a case.
func (r *MatchRepo) ListByCaseID(ctx context.Context, caseID int) ([]model.CelebrityMatch, error) {
	sql := `
		SELECT m.id, m.fk_case, m.fk_celebrity, m.match_status, m.match_score, m.matched_by, m.created_at,
		       c.name, c.tmz_celeb_id, c.image_url, c.verified
		FROM case_celebrity_matches m
		JOIN celebrities c ON m.fk_celebrity = c.id
		WHERE m.fk_case = $1 AND m.match_status != 'Removed'
		ORDER BY c.name ASC
	`
	rows, err := r.pool.Query(ctx, sql, caseID)
	if err != nil {
		return nil, fmt.Errorf("matches by case: %w", err)
	}
	defer rows.Close()

	var matches []model.CelebrityMatch
	for rows.Next() {
		var m model.CelebrityMatch
		celeb := &model.Celebrity{}
		if err := rows.Scan(
			&m.ID, &m.CaseID, &m.CelebrityID, &m.MatchStatus, &m.MatchScore, &m.MatchedBy, &m.CreatedAt,
			&celeb.Name, &celeb.TMZCelebID, &celeb.ImageURL, &celeb.Verified,
		); err != nil {
			return nil, fmt.Errorf("scan match: %w", err)
		}
		celeb.ID = m.CelebrityID
		m.Celebrity = celeb
		matches = append(matches, m)
	}
	return matches, nil
}

func buildMatchWhere(f model.MatchFilter) (string, []interface{}) {
	conditions := []string{}
	args := []interface{}{}
	n := 1

	if f.CaseID != nil {
		conditions = append(conditions, fmt.Sprintf("m.fk_case = $%d", n))
		args = append(args, *f.CaseID)
		n++
	}
	if f.CelebrityID != nil {
		conditions = append(conditions, fmt.Sprintf("m.fk_celebrity = $%d", n))
		args = append(args, *f.CelebrityID)
		n++
	}
	if f.Status != "" {
		conditions = append(conditions, fmt.Sprintf("m.match_status = $%d", n))
		args = append(args, f.Status)
		n++
	}

	// Always exclude removed unless specifically filtered
	if f.Status == "" {
		conditions = append(conditions, "m.match_status != 'Removed'")
	}

	if len(conditions) == 0 {
		return "", args
	}
	return " WHERE " + strings.Join(conditions, " AND "), args
}
