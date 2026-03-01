package repository

import (
	"context"
	"encoding/json"
	"fmt"

	"github.com/jackc/pgx/v5"
	"github.com/jackc/pgx/v5/pgxpool"
	"github.com/tmz/docketwatch-api/internal/model"
)

// UserRepo handles database operations for users and preferences.
type UserRepo struct {
	pool *pgxpool.Pool
}

// NewUserRepo creates a new UserRepo.
func NewUserRepo(pool *pgxpool.Pool) *UserRepo {
	return &UserRepo{pool: pool}
}

// GetByUsername returns a user by username.
func (r *UserRepo) GetByUsername(ctx context.Context, username string) (*model.User, error) {
	sql := `SELECT id, username, email, first_name, last_name, role, cognito_sub, created_at
	        FROM users WHERE username = $1`
	var u model.User
	err := r.pool.QueryRow(ctx, sql, username).Scan(
		&u.ID, &u.Username, &u.Email, &u.FirstName, &u.LastName, &u.Role, &u.CognitoSub, &u.CreatedAt,
	)
	if err == pgx.ErrNoRows {
		return nil, nil
	}
	if err != nil {
		return nil, fmt.Errorf("get user by username: %w", err)
	}
	return &u, nil
}

// GetByCognitoSub returns a user by Cognito subject ID.
func (r *UserRepo) GetByCognitoSub(ctx context.Context, sub string) (*model.User, error) {
	sql := `SELECT id, username, email, first_name, last_name, role, cognito_sub, created_at
	        FROM users WHERE cognito_sub = $1`
	var u model.User
	err := r.pool.QueryRow(ctx, sql, sub).Scan(
		&u.ID, &u.Username, &u.Email, &u.FirstName, &u.LastName, &u.Role, &u.CognitoSub, &u.CreatedAt,
	)
	if err == pgx.ErrNoRows {
		return nil, nil
	}
	if err != nil {
		return nil, fmt.Errorf("get user by cognito sub: %w", err)
	}
	return &u, nil
}

// SavePreference upserts a user preference.
func (r *UserRepo) SavePreference(ctx context.Context, userID int, key string, value interface{}) error {
	jsonVal, err := json.Marshal(value)
	if err != nil {
		return fmt.Errorf("marshal preference: %w", err)
	}

	sql := `
		INSERT INTO user_preferences (fk_user, preference_key, preference_value)
		VALUES ($1, $2, $3)
		ON CONFLICT (fk_user, preference_key) DO UPDATE SET preference_value = $3
	`
	_, err = r.pool.Exec(ctx, sql, userID, key, jsonVal)
	if err != nil {
		return fmt.Errorf("save preference: %w", err)
	}
	return nil
}

// GetPreferences returns all preferences for a user.
func (r *UserRepo) GetPreferences(ctx context.Context, userID int) (map[string]json.RawMessage, error) {
	rows, err := r.pool.Query(ctx,
		"SELECT preference_key, preference_value FROM user_preferences WHERE fk_user = $1",
		userID)
	if err != nil {
		return nil, fmt.Errorf("get preferences: %w", err)
	}
	defer rows.Close()

	prefs := make(map[string]json.RawMessage)
	for rows.Next() {
		var key string
		var val json.RawMessage
		if err := rows.Scan(&key, &val); err != nil {
			return nil, fmt.Errorf("scan preference: %w", err)
		}
		prefs[key] = val
	}
	return prefs, nil
}

// AddCaseSubscriber adds a user to case email notifications.
func (r *UserRepo) AddCaseSubscriber(ctx context.Context, caseID int, username string) error {
	sql := `
		INSERT INTO case_email_recipients (fk_case, username, notify)
		VALUES ($1, $2, TRUE)
		ON CONFLICT (fk_case, username) DO UPDATE SET notify = TRUE
	`
	_, err := r.pool.Exec(ctx, sql, caseID, username)
	if err != nil {
		return fmt.Errorf("add subscriber: %w", err)
	}
	return nil
}

// RemoveCaseSubscriber removes a user from case email notifications.
func (r *UserRepo) RemoveCaseSubscriber(ctx context.Context, caseID int, username string) error {
	_, err := r.pool.Exec(ctx,
		"DELETE FROM case_email_recipients WHERE fk_case = $1 AND username = $2",
		caseID, username)
	if err != nil {
		return fmt.Errorf("remove subscriber: %w", err)
	}
	return nil
}

// ListCaseSubscribers returns all subscribers for a case.
func (r *UserRepo) ListCaseSubscribers(ctx context.Context, caseID int) ([]model.EmailSubscription, error) {
	rows, err := r.pool.Query(ctx,
		"SELECT id, fk_case, username, notify FROM case_email_recipients WHERE fk_case = $1 ORDER BY username",
		caseID)
	if err != nil {
		return nil, fmt.Errorf("list subscribers: %w", err)
	}
	defer rows.Close()

	var subs []model.EmailSubscription
	for rows.Next() {
		var s model.EmailSubscription
		if err := rows.Scan(&s.ID, &s.CaseID, &s.Username, &s.Notify); err != nil {
			return nil, fmt.Errorf("scan subscriber: %w", err)
		}
		subs = append(subs, s)
	}
	return subs, nil
}
