package repository

import (
	"context"
	"fmt"
	"strings"

	"github.com/jackc/pgx/v5"
	"github.com/jackc/pgx/v5/pgxpool"
	"github.com/tmz/docketwatch-api/internal/model"
)

// CelebrityRepo handles database operations for celebrities.
type CelebrityRepo struct {
	pool *pgxpool.Pool
}

// NewCelebrityRepo creates a new CelebrityRepo.
func NewCelebrityRepo(pool *pgxpool.Pool) *CelebrityRepo {
	return &CelebrityRepo{pool: pool}
}

// List returns a paginated list of celebrities.
func (r *CelebrityRepo) List(ctx context.Context, filter model.CelebrityFilter, pg model.Pagination) ([]model.Celebrity, int, error) {
	where, args := buildCelebrityWhere(filter)

	var total int
	if err := r.pool.QueryRow(ctx, "SELECT COUNT(*) FROM celebrities c"+where, args...).Scan(&total); err != nil {
		return nil, 0, fmt.Errorf("count celebrities: %w", err)
	}

	dataSQL := fmt.Sprintf(`
		SELECT c.id, c.name, c.tmz_celeb_id, c.image_url, c.verified, c.created_at,
		       (SELECT COUNT(*) FROM case_celebrity_matches WHERE fk_celebrity = c.id AND match_status != 'Removed') AS case_count
		FROM celebrities c
		%s
		ORDER BY c.name ASC
		LIMIT $%d OFFSET $%d
	`, where, len(args)+1, len(args)+2)

	args = append(args, pg.PerPage, pg.Offset())

	rows, err := r.pool.Query(ctx, dataSQL, args...)
	if err != nil {
		return nil, 0, fmt.Errorf("list celebrities: %w", err)
	}
	defer rows.Close()

	var celebs []model.Celebrity
	for rows.Next() {
		var c model.Celebrity
		if err := rows.Scan(&c.ID, &c.Name, &c.TMZCelebID, &c.ImageURL, &c.Verified, &c.CreatedAt, &c.CaseCount); err != nil {
			return nil, 0, fmt.Errorf("scan celebrity: %w", err)
		}
		celebs = append(celebs, c)
	}
	return celebs, total, nil
}

// GetByID returns a celebrity by ID.
func (r *CelebrityRepo) GetByID(ctx context.Context, id int) (*model.Celebrity, error) {
	sql := `
		SELECT c.id, c.name, c.tmz_celeb_id, c.image_url, c.verified, c.created_at,
		       (SELECT COUNT(*) FROM case_celebrity_matches WHERE fk_celebrity = c.id AND match_status != 'Removed') AS case_count
		FROM celebrities c WHERE c.id = $1
	`
	var c model.Celebrity
	err := r.pool.QueryRow(ctx, sql, id).Scan(&c.ID, &c.Name, &c.TMZCelebID, &c.ImageURL, &c.Verified, &c.CreatedAt, &c.CaseCount)
	if err == pgx.ErrNoRows {
		return nil, nil
	}
	if err != nil {
		return nil, fmt.Errorf("get celebrity %d: %w", id, err)
	}
	return &c, nil
}

// Create inserts a new celebrity.
func (r *CelebrityRepo) Create(ctx context.Context, req model.CreateCelebrityRequest) (int, error) {
	var id int
	err := r.pool.QueryRow(ctx,
		"INSERT INTO celebrities (name, tmz_celeb_id, image_url) VALUES ($1, $2, $3) RETURNING id",
		req.Name, req.TMZCelebID, req.ImageURL,
	).Scan(&id)
	if err != nil {
		return 0, fmt.Errorf("create celebrity: %w", err)
	}
	return id, nil
}

// Search returns celebrities matching a query string (for autocomplete).
func (r *CelebrityRepo) Search(ctx context.Context, query string, limit int) ([]model.Celebrity, error) {
	sql := `
		SELECT id, name, tmz_celeb_id, image_url, verified, created_at
		FROM celebrities
		WHERE name ILIKE $1
		ORDER BY name ASC
		LIMIT $2
	`
	rows, err := r.pool.Query(ctx, sql, "%"+query+"%", limit)
	if err != nil {
		return nil, fmt.Errorf("search celebrities: %w", err)
	}
	defer rows.Close()

	var celebs []model.Celebrity
	for rows.Next() {
		var c model.Celebrity
		if err := rows.Scan(&c.ID, &c.Name, &c.TMZCelebID, &c.ImageURL, &c.Verified, &c.CreatedAt); err != nil {
			return nil, fmt.Errorf("scan celebrity search: %w", err)
		}
		celebs = append(celebs, c)
	}
	return celebs, nil
}

func buildCelebrityWhere(f model.CelebrityFilter) (string, []interface{}) {
	conditions := []string{}
	args := []interface{}{}
	n := 1

	if f.Verified != nil {
		conditions = append(conditions, fmt.Sprintf("c.verified = $%d", n))
		args = append(args, *f.Verified)
		n++
	}
	if f.Query != "" {
		conditions = append(conditions, fmt.Sprintf("c.name ILIKE $%d", n))
		args = append(args, "%"+f.Query+"%")
		n++
	}

	if len(conditions) == 0 {
		return "", args
	}
	return " WHERE " + strings.Join(conditions, " AND "), args
}
