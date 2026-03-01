package worker

import (
	"context"
	"encoding/xml"
	"fmt"
	"io"
	"net/http"
	"time"

	"github.com/jackc/pgx/v5/pgxpool"
	"github.com/rs/zerolog/log"
)

// RSSPoller polls PACER RSS feeds for new case events.
// Replaces: check_case_updates.cfm, process_cases.cfm
type RSSPoller struct {
	pool     *pgxpool.Pool
	client   *http.Client
	interval time.Duration
}

// NewRSSPoller creates a new RSS feed poller.
func NewRSSPoller(pool *pgxpool.Pool, interval time.Duration) *RSSPoller {
	return &RSSPoller{
		pool:     pool,
		client:   &http.Client{Timeout: 30 * time.Second},
		interval: interval,
	}
}

// RSS feed structures
type rssFeed struct {
	XMLName xml.Name   `xml:"rss"`
	Channel rssChannel `xml:"channel"`
}

type rssChannel struct {
	Title string    `xml:"title"`
	Items []rssItem `xml:"item"`
}

type rssItem struct {
	Title       string `xml:"title"`
	Link        string `xml:"link"`
	Description string `xml:"description"`
	PubDate     string `xml:"pubDate"`
	GUID        string `xml:"guid"`
}

// Start begins the polling loop. Blocks until context is canceled.
func (p *RSSPoller) Start(ctx context.Context) {
	log.Info().Dur("interval", p.interval).Msg("RSS poller started")

	// Run immediately, then on interval
	p.pollAll(ctx)

	ticker := time.NewTicker(p.interval)
	defer ticker.Stop()

	for {
		select {
		case <-ctx.Done():
			log.Info().Msg("RSS poller stopped")
			return
		case <-ticker.C:
			p.pollAll(ctx)
		}
	}
}

func (p *RSSPoller) pollAll(ctx context.Context) {
	log.Info().Msg("Polling RSS feeds...")

	// Get all active PACER tools with RSS feed URLs
	rows, err := p.pool.Query(ctx,
		"SELECT id, name, api_endpoint FROM tools WHERE tool_type = 'PACER' AND active = TRUE AND api_endpoint IS NOT NULL")
	if err != nil {
		log.Error().Err(err).Msg("Failed to query tools")
		return
	}
	defer rows.Close()

	for rows.Next() {
		var toolID int
		var name, endpoint string
		if err := rows.Scan(&toolID, &name, &endpoint); err != nil {
			log.Error().Err(err).Msg("Failed to scan tool row")
			continue
		}

		if err := p.pollFeed(ctx, toolID, name, endpoint); err != nil {
			log.Error().Err(err).Str("tool", name).Msg("Feed polling failed")
		}
	}
}

func (p *RSSPoller) pollFeed(ctx context.Context, toolID int, toolName, feedURL string) error {
	log.Debug().Str("tool", toolName).Str("url", feedURL).Msg("Polling feed")

	req, err := http.NewRequestWithContext(ctx, "GET", feedURL, nil)
	if err != nil {
		return fmt.Errorf("create request: %w", err)
	}

	resp, err := p.client.Do(req)
	if err != nil {
		return fmt.Errorf("fetch feed: %w", err)
	}
	defer resp.Body.Close()

	body, err := io.ReadAll(resp.Body)
	if err != nil {
		return fmt.Errorf("read feed: %w", err)
	}

	var feed rssFeed
	if err := xml.Unmarshal(body, &feed); err != nil {
		return fmt.Errorf("parse feed: %w", err)
	}

	newCount := 0
	for _, item := range feed.Channel.Items {
		inserted, err := p.processItem(ctx, toolID, item)
		if err != nil {
			log.Error().Err(err).Str("guid", item.GUID).Msg("Failed to process item")
			continue
		}
		if inserted {
			newCount++
		}
	}

	if newCount > 0 {
		log.Info().Str("tool", toolName).Int("new_events", newCount).Msg("New events from RSS")
	}

	return nil
}

func (p *RSSPoller) processItem(ctx context.Context, toolID int, item rssItem) (bool, error) {
	// Check if event already exists (by GUID/URL)
	var exists bool
	err := p.pool.QueryRow(ctx,
		"SELECT EXISTS(SELECT 1 FROM case_events WHERE event_url = $1)",
		item.Link,
	).Scan(&exists)
	if err != nil {
		return false, fmt.Errorf("check exists: %w", err)
	}
	if exists {
		return false, nil
	}

	// Find matching case by parsing case number from title/description
	// The PACER RSS typically includes the case number
	caseNumber := extractCaseNumber(item.Title)
	if caseNumber == "" {
		return false, nil
	}

	var caseID int
	err = p.pool.QueryRow(ctx,
		"SELECT id FROM cases WHERE case_number = $1 AND tool_id = $2",
		caseNumber, toolID,
	).Scan(&caseID)
	if err != nil {
		// Case not tracked - skip
		return false, nil
	}

	// Parse date
	var eventDate *time.Time
	if t, err := time.Parse(time.RFC1123, item.PubDate); err == nil {
		eventDate = &t
	}

	// Insert new event
	_, err = p.pool.Exec(ctx,
		`INSERT INTO case_events (fk_case, event_date, event_description, event_url, is_doc)
		 VALUES ($1, $2, $3, $4, $5)`,
		caseID, eventDate, item.Description, item.Link, true,
	)
	if err != nil {
		return false, fmt.Errorf("insert event: %w", err)
	}

	return true, nil
}

// extractCaseNumber attempts to parse a case number from an RSS item title.
func extractCaseNumber(title string) string {
	// PACER RSS titles typically contain the case number
	// Example: "1:24-cv-01234 Smith v. Jones"
	// This is a simplified extraction; production would use regex
	if len(title) > 0 {
		// Find first space - everything before it is usually the case number
		for i, ch := range title {
			if ch == ' ' && i > 5 {
				return title[:i]
			}
		}
	}
	return ""
}
