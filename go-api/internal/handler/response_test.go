package handler

import (
	"encoding/json"
	"net/http"
	"net/http/httptest"
	"strings"
	"testing"

	"github.com/tmz/docketwatch-api/internal/model"
)

func TestWriteJSON(t *testing.T) {
	w := httptest.NewRecorder()
	data := map[string]string{"hello": "world"}
	writeJSON(w, http.StatusOK, data)

	if w.Code != http.StatusOK {
		t.Errorf("expected status %d, got %d", http.StatusOK, w.Code)
	}

	ct := w.Header().Get("Content-Type")
	if ct != "application/json" {
		t.Errorf("expected Content-Type application/json, got %s", ct)
	}

	var result map[string]string
	if err := json.NewDecoder(w.Body).Decode(&result); err != nil {
		t.Fatalf("failed to decode response: %v", err)
	}
	if result["hello"] != "world" {
		t.Errorf("expected hello=world, got %s", result["hello"])
	}
}

func TestWriteJSON_StatusCodes(t *testing.T) {
	codes := []int{
		http.StatusOK,
		http.StatusCreated,
		http.StatusAccepted,
		http.StatusBadRequest,
		http.StatusNotFound,
		http.StatusInternalServerError,
	}

	for _, code := range codes {
		w := httptest.NewRecorder()
		writeJSON(w, code, map[string]string{})
		if w.Code != code {
			t.Errorf("expected status %d, got %d", code, w.Code)
		}
	}
}

func TestWriteError(t *testing.T) {
	w := httptest.NewRecorder()
	writeError(w, http.StatusBadRequest, "TEST_CODE", "test message")

	if w.Code != http.StatusBadRequest {
		t.Errorf("expected status %d, got %d", http.StatusBadRequest, w.Code)
	}

	var result ErrorResponse
	if err := json.NewDecoder(w.Body).Decode(&result); err != nil {
		t.Fatalf("failed to decode response: %v", err)
	}
	if result.Error.Code != "TEST_CODE" {
		t.Errorf("expected code TEST_CODE, got %s", result.Error.Code)
	}
	if result.Error.Message != "test message" {
		t.Errorf("expected message 'test message', got %s", result.Error.Message)
	}
}

func TestWritePaginated(t *testing.T) {
	w := httptest.NewRecorder()
	data := []string{"a", "b", "c"}
	pg := model.Pagination{Page: 1, PerPage: 10, Sort: "created_at", Order: "desc"}

	writePaginated(w, data, pg, 25)

	if w.Code != http.StatusOK {
		t.Errorf("expected status 200, got %d", w.Code)
	}

	var result struct {
		Data []string `json:"data"`
		Meta struct {
			Page       int `json:"page"`
			PerPage    int `json:"per_page"`
			Total      int `json:"total"`
			TotalPages int `json:"total_pages"`
		} `json:"meta"`
	}
	if err := json.NewDecoder(w.Body).Decode(&result); err != nil {
		t.Fatalf("failed to decode: %v", err)
	}
	if len(result.Data) != 3 {
		t.Errorf("expected 3 items, got %d", len(result.Data))
	}
	if result.Meta.Total != 25 {
		t.Errorf("expected total=25, got %d", result.Meta.Total)
	}
	if result.Meta.TotalPages != 3 {
		t.Errorf("expected totalPages=3, got %d", result.Meta.TotalPages)
	}
}

func TestDecodeJSON(t *testing.T) {
	body := `{"name":"test","value":42}`
	r := httptest.NewRequest(http.MethodPost, "/", strings.NewReader(body))

	var result struct {
		Name  string `json:"name"`
		Value int    `json:"value"`
	}
	if err := decodeJSON(r, &result); err != nil {
		t.Fatalf("failed to decode: %v", err)
	}
	if result.Name != "test" {
		t.Errorf("expected name=test, got %s", result.Name)
	}
	if result.Value != 42 {
		t.Errorf("expected value=42, got %d", result.Value)
	}
}

func TestDecodeJSON_Invalid(t *testing.T) {
	r := httptest.NewRequest(http.MethodPost, "/", strings.NewReader("not json"))
	var result map[string]string
	if err := decodeJSON(r, &result); err == nil {
		t.Error("expected error for invalid JSON")
	}
}

func TestDecodeJSON_Empty(t *testing.T) {
	r := httptest.NewRequest(http.MethodPost, "/", strings.NewReader(""))
	var result map[string]string
	if err := decodeJSON(r, &result); err == nil {
		t.Error("expected error for empty body")
	}
}
