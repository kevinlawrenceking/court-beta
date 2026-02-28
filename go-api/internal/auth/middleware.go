package auth

import (
	"context"
	"crypto/rsa"
	"encoding/base64"
	"encoding/json"
	"fmt"
	"math/big"
	"net/http"
	"strings"
	"sync"
	"time"

	"github.com/golang-jwt/jwt/v5"
	"github.com/rs/zerolog/log"
)

type contextKey string

const UserContextKey contextKey = "user"

// Claims represents the JWT claims from a Cognito token.
type Claims struct {
	Sub      string `json:"sub"`
	Username string `json:"cognito:username"`
	Email    string `json:"email"`
	Groups   []string `json:"cognito:groups"`
	jwt.RegisteredClaims
}

// JWKSet represents a JSON Web Key Set from Cognito.
type JWKSet struct {
	Keys []JWK `json:"keys"`
}

// JWK represents a single JSON Web Key.
type JWK struct {
	Kid string `json:"kid"`
	Kty string `json:"kty"`
	N   string `json:"n"`
	E   string `json:"e"`
	Use string `json:"use"`
}

// Middleware provides JWT authentication middleware for HTTP handlers.
type Middleware struct {
	issuer   string
	clientID string
	keys     map[string]*rsa.PublicKey
	keysMu   sync.RWMutex
	devMode  bool
}

// NewMiddleware creates a new auth middleware.
// If devMode is true, authentication is skipped and a mock user is injected.
func NewMiddleware(issuer, clientID string, devMode bool) *Middleware {
	return &Middleware{
		issuer:   issuer,
		clientID: clientID,
		keys:     make(map[string]*rsa.PublicKey),
		devMode:  devMode,
	}
}

// Handler returns the HTTP middleware function.
func (m *Middleware) Handler(next http.Handler) http.Handler {
	return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		if m.devMode {
			claims := &Claims{
				Sub:      "dev-user-001",
				Username: "developer",
				Email:    "dev@tmz.com",
			}
			ctx := context.WithValue(r.Context(), UserContextKey, claims)
			next.ServeHTTP(w, r.WithContext(ctx))
			return
		}

		authHeader := r.Header.Get("Authorization")
		if authHeader == "" {
			http.Error(w, `{"error":{"code":"UNAUTHORIZED","message":"Missing Authorization header"}}`, http.StatusUnauthorized)
			return
		}

		parts := strings.SplitN(authHeader, " ", 2)
		if len(parts) != 2 || parts[0] != "Bearer" {
			http.Error(w, `{"error":{"code":"UNAUTHORIZED","message":"Invalid Authorization header format"}}`, http.StatusUnauthorized)
			return
		}

		claims, err := m.validateToken(parts[1])
		if err != nil {
			log.Warn().Err(err).Msg("JWT validation failed")
			http.Error(w, `{"error":{"code":"UNAUTHORIZED","message":"Invalid token"}}`, http.StatusUnauthorized)
			return
		}

		ctx := context.WithValue(r.Context(), UserContextKey, claims)
		next.ServeHTTP(w, r.WithContext(ctx))
	})
}

// GetUser extracts the authenticated user claims from the request context.
func GetUser(ctx context.Context) *Claims {
	if claims, ok := ctx.Value(UserContextKey).(*Claims); ok {
		return claims
	}
	return nil
}

func (m *Middleware) validateToken(tokenStr string) (*Claims, error) {
	token, err := jwt.ParseWithClaims(tokenStr, &Claims{}, func(token *jwt.Token) (interface{}, error) {
		if _, ok := token.Method.(*jwt.SigningMethodRSA); !ok {
			return nil, fmt.Errorf("unexpected signing method: %v", token.Header["alg"])
		}

		kid, ok := token.Header["kid"].(string)
		if !ok {
			return nil, fmt.Errorf("missing kid in token header")
		}

		key, err := m.getKey(kid)
		if err != nil {
			return nil, err
		}
		return key, nil
	},
		jwt.WithIssuer(m.issuer),
		jwt.WithAudience(m.clientID),
		jwt.WithLeeway(30*time.Second),
	)
	if err != nil {
		return nil, err
	}

	claims, ok := token.Claims.(*Claims)
	if !ok || !token.Valid {
		return nil, fmt.Errorf("invalid token claims")
	}

	return claims, nil
}

func (m *Middleware) getKey(kid string) (*rsa.PublicKey, error) {
	m.keysMu.RLock()
	if key, ok := m.keys[kid]; ok {
		m.keysMu.RUnlock()
		return key, nil
	}
	m.keysMu.RUnlock()

	if err := m.fetchJWKS(); err != nil {
		return nil, err
	}

	m.keysMu.RLock()
	defer m.keysMu.RUnlock()
	if key, ok := m.keys[kid]; ok {
		return key, nil
	}
	return nil, fmt.Errorf("key %s not found in JWKS", kid)
}

func (m *Middleware) fetchJWKS() error {
	url := fmt.Sprintf("%s/.well-known/jwks.json", m.issuer)

	resp, err := http.Get(url)
	if err != nil {
		return fmt.Errorf("failed to fetch JWKS: %w", err)
	}
	defer resp.Body.Close()

	var jwks JWKSet
	if err := json.NewDecoder(resp.Body).Decode(&jwks); err != nil {
		return fmt.Errorf("failed to decode JWKS: %w", err)
	}

	m.keysMu.Lock()
	defer m.keysMu.Unlock()

	for _, jwk := range jwks.Keys {
		if jwk.Kty != "RSA" || jwk.Use != "sig" {
			continue
		}

		nBytes, err := base64.RawURLEncoding.DecodeString(jwk.N)
		if err != nil {
			continue
		}
		eBytes, err := base64.RawURLEncoding.DecodeString(jwk.E)
		if err != nil {
			continue
		}

		n := new(big.Int).SetBytes(nBytes)
		e := new(big.Int).SetBytes(eBytes)

		m.keys[jwk.Kid] = &rsa.PublicKey{
			N: n,
			E: int(e.Int64()),
		}
	}

	return nil
}
