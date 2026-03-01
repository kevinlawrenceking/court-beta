package worker

import (
	"context"
	"strings"
	"time"
	"unicode"

	"github.com/jackc/pgx/v5/pgxpool"
	"github.com/rs/zerolog/log"
)

// CelebrityMatcher automatically matches case parties against the celebrity database.
// Replaces: process_celebrity_matches.cfm, process_celebrity_matches_strict.cfm
// Ports: includes/functions.cfm (fncNormalizeCaseName, fncIsMatch)
type CelebrityMatcher struct {
	pool     *pgxpool.Pool
	interval time.Duration
}

// NewCelebrityMatcher creates a new matcher.
func NewCelebrityMatcher(pool *pgxpool.Pool, interval time.Duration) *CelebrityMatcher {
	return &CelebrityMatcher{pool: pool, interval: interval}
}

// Start begins the matching loop. Blocks until context is canceled.
func (m *CelebrityMatcher) Start(ctx context.Context) {
	log.Info().Dur("interval", m.interval).Msg("Celebrity matcher started")

	ticker := time.NewTicker(m.interval)
	defer ticker.Stop()

	for {
		select {
		case <-ctx.Done():
			log.Info().Msg("Celebrity matcher stopped")
			return
		case <-ticker.C:
			m.runMatching(ctx)
		}
	}
}

func (m *CelebrityMatcher) runMatching(ctx context.Context) {
	log.Info().Msg("Running celebrity matching...")

	// Get unmatched cases (cases without any celebrity matches yet)
	rows, err := m.pool.Query(ctx, `
		SELECT c.id, c.case_name
		FROM cases c
		WHERE c.status IN ('Review', 'Tracked')
		AND NOT EXISTS (
			SELECT 1 FROM case_celebrity_matches ccm
			WHERE ccm.fk_case = c.id
		)
		ORDER BY c.created_at DESC
		LIMIT 100
	`)
	if err != nil {
		log.Error().Err(err).Msg("Failed to query unmatched cases")
		return
	}
	defer rows.Close()

	type caseRow struct {
		id   int
		name string
	}
	var cases []caseRow
	for rows.Next() {
		var c caseRow
		if err := rows.Scan(&c.id, &c.name); err != nil {
			continue
		}
		cases = append(cases, c)
	}

	if len(cases) == 0 {
		return
	}

	// Get all celebrities
	celebRows, err := m.pool.Query(ctx, "SELECT id, name FROM celebrities")
	if err != nil {
		log.Error().Err(err).Msg("Failed to query celebrities")
		return
	}
	defer celebRows.Close()

	type celebRow struct {
		id   int
		name string
	}
	var celebrities []celebRow
	for celebRows.Next() {
		var c celebRow
		if err := celebRows.Scan(&c.id, &c.name); err != nil {
			continue
		}
		celebrities = append(celebrities, c)
	}

	matchCount := 0
	for _, cs := range cases {
		normalizedCase := normalizeCaseName(cs.name)
		for _, celeb := range celebrities {
			score := isMatch(normalizedCase, celeb.name)
			if score > 0 {
				_, err := m.pool.Exec(ctx, `
					INSERT INTO case_celebrity_matches (fk_case, fk_celebrity, match_status, match_score, matched_by)
					VALUES ($1, $2, 'Pending', $3, 'auto-matcher')
					ON CONFLICT (fk_case, fk_celebrity) DO NOTHING
				`, cs.id, celeb.id, score)
				if err != nil {
					log.Error().Err(err).Int("case_id", cs.id).Int("celeb_id", celeb.id).Msg("Insert match failed")
				} else {
					matchCount++
				}
			}
		}
	}

	if matchCount > 0 {
		log.Info().Int("matches", matchCount).Int("cases_checked", len(cases)).Msg("Celebrity matching complete")
	}
}

// normalizeCaseName reformats "LAST, FIRST" to "FIRST LAST" and removes titles.
// Port of: fncNormalizeCaseName from includes/functions.cfm
func normalizeCaseName(name string) string {
	name = strings.TrimSpace(name)
	name = strings.ToLower(name)

	// Remove common legal suffixes
	for _, suffix := range []string{
		" et al", " et al.", " individually", " a minor",
		" inc.", " inc", " llc", " ltd", " corp.", " corp",
		" v.", " vs.", " vs ", " v ",
	} {
		name = strings.ReplaceAll(name, suffix, " ")
	}

	// Remove titles
	for _, title := range []string{
		"mr.", "mrs.", "ms.", "dr.", "jr.", "sr.",
		"mr ", "mrs ", "ms ", "dr ", "jr ", "sr ",
		"hon.", "judge ", "esq.",
	} {
		name = strings.ReplaceAll(name, title, "")
	}

	// Handle "LAST, FIRST" format
	if parts := strings.SplitN(name, ",", 2); len(parts) == 2 {
		first := strings.TrimSpace(parts[1])
		last := strings.TrimSpace(parts[0])
		if first != "" && last != "" {
			name = first + " " + last
		}
	}

	// Remove non-alpha characters except spaces
	var cleaned strings.Builder
	for _, r := range name {
		if unicode.IsLetter(r) || r == ' ' {
			cleaned.WriteRune(r)
		}
	}

	// Collapse multiple spaces
	result := strings.Join(strings.Fields(cleaned.String()), " ")
	return result
}

// isMatch performs word-by-word matching between a case name and celebrity name.
// Returns a match score (0.0 = no match, 1.0 = perfect match).
// Port of: fncIsMatch from includes/functions.cfm
func isMatch(normalizedCaseName, celebrityName string) float64 {
	celebLower := strings.ToLower(strings.TrimSpace(celebrityName))
	celebWords := strings.Fields(celebLower)

	if len(celebWords) < 2 {
		return 0
	}

	caseWords := strings.Fields(normalizedCaseName)
	if len(caseWords) == 0 {
		return 0
	}

	matchedWords := 0
	for _, cw := range celebWords {
		if len(cw) <= 1 {
			continue // Skip initials
		}
		for _, nw := range caseWords {
			if cw == nw {
				matchedWords++
				break
			}
		}
	}

	if matchedWords < 2 {
		return 0
	}

	// Score: proportion of celebrity name words found in case name
	score := float64(matchedWords) / float64(len(celebWords))
	return score
}
