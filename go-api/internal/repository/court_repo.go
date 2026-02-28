package repository

import (
	"context"
	"fmt"

	"github.com/jackc/pgx/v5/pgxpool"
	"github.com/tmz/docketwatch-api/internal/model"
)

// CourtRepo handles database operations for courts, counties, and states.
type CourtRepo struct {
	pool *pgxpool.Pool
}

// NewCourtRepo creates a new CourtRepo.
func NewCourtRepo(pool *pgxpool.Pool) *CourtRepo {
	return &CourtRepo{pool: pool}
}

// ListStates returns all states.
func (r *CourtRepo) ListStates(ctx context.Context) ([]model.State, error) {
	rows, err := r.pool.Query(ctx, "SELECT state_code, state_name FROM states ORDER BY state_name")
	if err != nil {
		return nil, fmt.Errorf("list states: %w", err)
	}
	defer rows.Close()

	var states []model.State
	for rows.Next() {
		var s model.State
		if err := rows.Scan(&s.StateCode, &s.StateName); err != nil {
			return nil, fmt.Errorf("scan state: %w", err)
		}
		states = append(states, s)
	}
	return states, nil
}

// ListCounties returns counties, optionally filtered by state.
func (r *CourtRepo) ListCounties(ctx context.Context, stateCode string) ([]model.County, error) {
	query := "SELECT id, name, state_code FROM counties"
	args := []interface{}{}
	if stateCode != "" {
		query += " WHERE state_code = $1"
		args = append(args, stateCode)
	}
	query += " ORDER BY name"

	rows, err := r.pool.Query(ctx, query, args...)
	if err != nil {
		return nil, fmt.Errorf("list counties: %w", err)
	}
	defer rows.Close()

	var counties []model.County
	for rows.Next() {
		var c model.County
		if err := rows.Scan(&c.ID, &c.Name, &c.StateCode); err != nil {
			return nil, fmt.Errorf("scan county: %w", err)
		}
		counties = append(counties, c)
	}
	return counties, nil
}

// ListCourts returns courts, optionally filtered by county.
func (r *CourtRepo) ListCourts(ctx context.Context, countyID *int, stateCode string) ([]model.Court, error) {
	sql := "SELECT id, court_code, court_name, address, fk_county, court_type FROM courts"
	args := []interface{}{}

	if countyID != nil {
		sql += " WHERE fk_county = $1"
		args = append(args, *countyID)
	} else if stateCode != "" {
		sql += " WHERE fk_county IN (SELECT id FROM counties WHERE state_code = $1)"
		args = append(args, stateCode)
	}
	sql += " ORDER BY court_name"

	pgRows, err := r.pool.Query(ctx, sql, args...)
	if err != nil {
		return nil, fmt.Errorf("list courts: %w", err)
	}
	defer pgRows.Close()

	var courts []model.Court
	for pgRows.Next() {
		var c model.Court
		if err := pgRows.Scan(&c.ID, &c.CourtCode, &c.CourtName, &c.Address, &c.CountyID, &c.CourtType); err != nil {
			return nil, fmt.Errorf("scan court: %w", err)
		}
		courts = append(courts, c)
	}
	return courts, nil
}

// ListTools returns all active tools.
func (r *CourtRepo) ListTools(ctx context.Context) ([]model.Tool, error) {
	rows, err := r.pool.Query(ctx,
		"SELECT id, name, tool_type, api_endpoint, active FROM tools WHERE active = TRUE ORDER BY name")
	if err != nil {
		return nil, fmt.Errorf("list tools: %w", err)
	}
	defer rows.Close()

	var tools []model.Tool
	for rows.Next() {
		var t model.Tool
		if err := rows.Scan(&t.ID, &t.Name, &t.ToolType, &t.APIEndpoint, &t.Active); err != nil {
			return nil, fmt.Errorf("scan tool: %w", err)
		}
		tools = append(tools, t)
	}
	return tools, nil
}
