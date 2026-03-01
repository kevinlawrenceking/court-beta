package model

import (
	"net/http/httptest"
	"testing"
)

func TestPagination_Offset(t *testing.T) {
	tests := []struct {
		page    int
		perPage int
		want    int
	}{
		{1, 10, 0},
		{2, 10, 10},
		{3, 25, 50},
		{1, 50, 0},
		{5, 20, 80},
	}

	for _, tt := range tests {
		p := Pagination{Page: tt.page, PerPage: tt.perPage}
		if got := p.Offset(); got != tt.want {
			t.Errorf("Pagination{%d, %d}.Offset() = %d, want %d", tt.page, tt.perPage, got, tt.want)
		}
	}
}

func TestNewPaginationMeta(t *testing.T) {
	tests := []struct {
		name       string
		page       int
		perPage    int
		total      int
		wantPages  int
	}{
		{"exact division", 1, 10, 30, 3},
		{"remainder", 1, 10, 25, 3},
		{"single page", 1, 50, 3, 1},
		{"zero results", 1, 10, 0, 0},
		{"one result", 1, 10, 1, 1},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			p := Pagination{Page: tt.page, PerPage: tt.perPage}
			meta := NewPaginationMeta(p, tt.total)

			if meta.TotalPages != tt.wantPages {
				t.Errorf("TotalPages = %d, want %d", meta.TotalPages, tt.wantPages)
			}
			if meta.Total != tt.total {
				t.Errorf("Total = %d, want %d", meta.Total, tt.total)
			}
			if meta.Page != tt.page {
				t.Errorf("Page = %d, want %d", meta.Page, tt.page)
			}
		})
	}
}

func TestParsePagination_Defaults(t *testing.T) {
	r := httptest.NewRequest("GET", "/", nil)
	p := ParsePagination(r, 20, 100)

	if p.Page != 1 {
		t.Errorf("Page = %d, want 1", p.Page)
	}
	if p.PerPage != 20 {
		t.Errorf("PerPage = %d, want 20", p.PerPage)
	}
	if p.Sort != "created_at" {
		t.Errorf("Sort = %s, want created_at", p.Sort)
	}
	if p.Order != "desc" {
		t.Errorf("Order = %s, want desc", p.Order)
	}
}

func TestParsePagination_CustomValues(t *testing.T) {
	r := httptest.NewRequest("GET", "/?page=3&per_page=50&sort=case_name&order=asc", nil)
	p := ParsePagination(r, 20, 100)

	if p.Page != 3 {
		t.Errorf("Page = %d, want 3", p.Page)
	}
	if p.PerPage != 50 {
		t.Errorf("PerPage = %d, want 50", p.PerPage)
	}
	if p.Sort != "case_name" {
		t.Errorf("Sort = %s, want case_name", p.Sort)
	}
	if p.Order != "asc" {
		t.Errorf("Order = %s, want asc", p.Order)
	}
}

func TestParsePagination_MaxPageSize(t *testing.T) {
	r := httptest.NewRequest("GET", "/?per_page=500", nil)
	p := ParsePagination(r, 20, 100)

	if p.PerPage != 100 {
		t.Errorf("PerPage = %d, want 100 (max)", p.PerPage)
	}
}

func TestParsePagination_InvalidValues(t *testing.T) {
	r := httptest.NewRequest("GET", "/?page=abc&per_page=-1&order=invalid", nil)
	p := ParsePagination(r, 20, 100)

	if p.Page != 1 {
		t.Errorf("Page = %d, want 1 (default)", p.Page)
	}
	if p.PerPage != 20 {
		t.Errorf("PerPage = %d, want 20 (default)", p.PerPage)
	}
	if p.Order != "desc" {
		t.Errorf("Order = %s, want desc (default)", p.Order)
	}
}

func TestParsePagination_ZeroPage(t *testing.T) {
	r := httptest.NewRequest("GET", "/?page=0", nil)
	p := ParsePagination(r, 20, 100)

	if p.Page != 1 {
		t.Errorf("Page = %d, want 1 (page=0 should use default)", p.Page)
	}
}
