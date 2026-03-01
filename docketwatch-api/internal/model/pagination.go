package model

import (
	"net/http"
	"strconv"
)

// Pagination holds pagination parameters parsed from the request.
type Pagination struct {
	Page    int    `json:"page"`
	PerPage int    `json:"per_page"`
	Sort    string `json:"sort"`
	Order   string `json:"order"` // "asc" or "desc"
}

// Offset returns the SQL OFFSET value.
func (p Pagination) Offset() int {
	return (p.Page - 1) * p.PerPage
}

// PaginatedResponse wraps any data with pagination metadata.
type PaginatedResponse struct {
	Data interface{} `json:"data"`
	Meta PaginationMeta `json:"meta"`
}

// PaginationMeta contains pagination info for the response.
type PaginationMeta struct {
	Page       int `json:"page"`
	PerPage    int `json:"per_page"`
	Total      int `json:"total"`
	TotalPages int `json:"total_pages"`
}

// NewPaginationMeta creates pagination metadata from total count.
func NewPaginationMeta(p Pagination, total int) PaginationMeta {
	totalPages := total / p.PerPage
	if total%p.PerPage > 0 {
		totalPages++
	}
	return PaginationMeta{
		Page:       p.Page,
		PerPage:    p.PerPage,
		Total:      total,
		TotalPages: totalPages,
	}
}

// ParsePagination extracts pagination parameters from an HTTP request.
func ParsePagination(r *http.Request, defaultPageSize, maxPageSize int) Pagination {
	p := Pagination{
		Page:    1,
		PerPage: defaultPageSize,
		Sort:    "created_at",
		Order:   "desc",
	}

	if v := r.URL.Query().Get("page"); v != "" {
		if page, err := strconv.Atoi(v); err == nil && page > 0 {
			p.Page = page
		}
	}

	if v := r.URL.Query().Get("per_page"); v != "" {
		if pp, err := strconv.Atoi(v); err == nil && pp > 0 {
			p.PerPage = pp
			if p.PerPage > maxPageSize {
				p.PerPage = maxPageSize
			}
		}
	}

	if v := r.URL.Query().Get("sort"); v != "" {
		p.Sort = v
	}

	if v := r.URL.Query().Get("order"); v == "asc" || v == "desc" {
		p.Order = v
	}

	return p
}
