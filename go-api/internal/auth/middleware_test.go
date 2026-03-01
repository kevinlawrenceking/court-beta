package auth

import (
	"context"
	"encoding/json"
	"net/http"
	"net/http/httptest"
	"testing"
)

func TestGetUser_NilContext(t *testing.T) {
	ctx := context.Background()
	user := GetUser(ctx)
	if user != nil {
		t.Error("expected nil user from empty context")
	}
}

func TestGetUser_WithClaims(t *testing.T) {
	claims := &Claims{
		Sub:      "sub-123",
		Username: "testuser",
		Email:    "test@example.com",
		Groups:   []string{"admin"},
	}
	ctx := context.WithValue(context.Background(), UserContextKey, claims)

	user := GetUser(ctx)
	if user == nil {
		t.Fatal("expected non-nil user")
	}
	if user.Sub != "sub-123" {
		t.Errorf("Sub = %s, want sub-123", user.Sub)
	}
	if user.Username != "testuser" {
		t.Errorf("Username = %s, want testuser", user.Username)
	}
	if user.Email != "test@example.com" {
		t.Errorf("Email = %s, want test@example.com", user.Email)
	}
	if len(user.Groups) != 1 || user.Groups[0] != "admin" {
		t.Errorf("Groups = %v, want [admin]", user.Groups)
	}
}

func TestGetUser_WrongType(t *testing.T) {
	ctx := context.WithValue(context.Background(), UserContextKey, "not-a-claims-struct")
	user := GetUser(ctx)
	if user != nil {
		t.Error("expected nil user when context value is wrong type")
	}
}

func TestMiddleware_DevMode(t *testing.T) {
	m := NewMiddleware("", "", true)

	var capturedUser *Claims
	handler := m.Handler(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		capturedUser = GetUser(r.Context())
		w.WriteHeader(http.StatusOK)
	}))

	w := httptest.NewRecorder()
	r := httptest.NewRequest(http.MethodGet, "/", nil)
	handler.ServeHTTP(w, r)

	if w.Code != http.StatusOK {
		t.Errorf("expected status 200, got %d", w.Code)
	}
	if capturedUser == nil {
		t.Fatal("expected dev user to be injected")
	}
	if capturedUser.Username != "developer" {
		t.Errorf("Username = %s, want developer", capturedUser.Username)
	}
	if capturedUser.Sub != "dev-user-001" {
		t.Errorf("Sub = %s, want dev-user-001", capturedUser.Sub)
	}
}

func TestMiddleware_MissingAuthHeader(t *testing.T) {
	m := NewMiddleware("https://cognito-idp.us-west-2.amazonaws.com/pool", "client-id", false)

	handler := m.Handler(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		t.Error("handler should not be called without auth header")
	}))

	w := httptest.NewRecorder()
	r := httptest.NewRequest(http.MethodGet, "/", nil)
	handler.ServeHTTP(w, r)

	if w.Code != http.StatusUnauthorized {
		t.Errorf("expected status 401, got %d", w.Code)
	}

	var result struct {
		Error struct {
			Code string `json:"code"`
		} `json:"error"`
	}
	json.NewDecoder(w.Body).Decode(&result)
	if result.Error.Code != "UNAUTHORIZED" {
		t.Errorf("expected error code UNAUTHORIZED, got %s", result.Error.Code)
	}
}

func TestMiddleware_InvalidAuthFormat(t *testing.T) {
	m := NewMiddleware("https://cognito-idp.us-west-2.amazonaws.com/pool", "client-id", false)

	handler := m.Handler(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		t.Error("handler should not be called with bad auth format")
	}))

	w := httptest.NewRecorder()
	r := httptest.NewRequest(http.MethodGet, "/", nil)
	r.Header.Set("Authorization", "Basic dXNlcjpwYXNz")
	handler.ServeHTTP(w, r)

	if w.Code != http.StatusUnauthorized {
		t.Errorf("expected status 401, got %d", w.Code)
	}
}

func TestMiddleware_InvalidToken(t *testing.T) {
	m := NewMiddleware("https://cognito-idp.us-west-2.amazonaws.com/pool", "client-id", false)

	handler := m.Handler(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		t.Error("handler should not be called with invalid token")
	}))

	w := httptest.NewRecorder()
	r := httptest.NewRequest(http.MethodGet, "/", nil)
	r.Header.Set("Authorization", "Bearer invalid.token.here")
	handler.ServeHTTP(w, r)

	if w.Code != http.StatusUnauthorized {
		t.Errorf("expected status 401, got %d", w.Code)
	}
}
