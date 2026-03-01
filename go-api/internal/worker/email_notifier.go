package worker

import (
	"context"
	"fmt"
	"time"

	"github.com/jackc/pgx/v5/pgxpool"
	"github.com/rs/zerolog/log"
)

// EmailNotifier sends email notifications for new case events to subscribers.
// Replaces: email_match.cfm
//
// In production, uses AWS SES. The notification check runs periodically
// and finds unacknowledged events for cases with email subscribers.
type EmailNotifier struct {
	pool     *pgxpool.Pool
	interval time.Duration
	sender   string
	// sesClient *ses.Client // TODO: Add SES client
}

// NewEmailNotifier creates a new email notifier.
func NewEmailNotifier(pool *pgxpool.Pool, interval time.Duration, sender string) *EmailNotifier {
	return &EmailNotifier{
		pool:     pool,
		interval: interval,
		sender:   sender,
	}
}

// Start begins the notification loop. Blocks until context is canceled.
func (n *EmailNotifier) Start(ctx context.Context) {
	log.Info().Dur("interval", n.interval).Msg("Email notifier started")

	ticker := time.NewTicker(n.interval)
	defer ticker.Stop()

	for {
		select {
		case <-ctx.Done():
			log.Info().Msg("Email notifier stopped")
			return
		case <-ticker.C:
			n.checkAndNotify(ctx)
		}
	}
}

func (n *EmailNotifier) checkAndNotify(ctx context.Context) {
	// Find unnotified events for cases with subscribers
	rows, err := n.pool.Query(ctx, `
		SELECT DISTINCT
			ce.id AS event_id,
			c.id AS case_id,
			c.case_number,
			c.case_name,
			ce.event_description,
			ce.event_date
		FROM case_events ce
		JOIN cases c ON ce.fk_case = c.id
		WHERE ce.acknowledged = FALSE
		AND ce.created_at > NOW() - INTERVAL '1 hour'
		AND EXISTS (
			SELECT 1 FROM case_email_recipients cer
			WHERE cer.fk_case = c.id AND cer.notify = TRUE
		)
		ORDER BY ce.created_at DESC
		LIMIT 20
	`)
	if err != nil {
		log.Error().Err(err).Msg("Failed to query unnotified events")
		return
	}
	defer rows.Close()

	type notification struct {
		eventID      int
		caseID       int
		caseNumber   string
		caseName     string
		description  string
		eventDate    *time.Time
	}

	var notifications []notification
	for rows.Next() {
		var n notification
		if err := rows.Scan(&n.eventID, &n.caseID, &n.caseNumber,
			&n.caseName, &n.description, &n.eventDate); err != nil {
			continue
		}
		notifications = append(notifications, n)
	}

	if len(notifications) == 0 {
		return
	}

	for _, notif := range notifications {
		n.sendNotification(ctx, notif.caseID, notif.caseNumber, notif.caseName, notif.description)
	}
}

func (n *EmailNotifier) sendNotification(ctx context.Context, caseID int, caseNumber, caseName, description string) {
	// Get subscribers for this case
	rows, err := n.pool.Query(ctx, `
		SELECT cer.username, u.email
		FROM case_email_recipients cer
		JOIN users u ON cer.username = u.username
		WHERE cer.fk_case = $1 AND cer.notify = TRUE AND u.email IS NOT NULL
	`, caseID)
	if err != nil {
		log.Error().Err(err).Int("case_id", caseID).Msg("Failed to get subscribers")
		return
	}
	defer rows.Close()

	for rows.Next() {
		var username, email string
		if err := rows.Scan(&username, &email); err != nil {
			continue
		}

		subject := fmt.Sprintf("DocketWatch Alert: %s - %s", caseNumber, caseName)
		body := fmt.Sprintf(
			"New court activity detected:\n\nCase: %s - %s\n\nEvent: %s\n\nView in DocketWatch: https://docketwatch.tmz.tv/cases/%d",
			caseNumber, caseName, description, caseID,
		)

		// TODO: Send via AWS SES
		// _, err := n.sesClient.SendEmail(ctx, &ses.SendEmailInput{...})
		log.Info().
			Str("to", email).
			Str("subject", subject).
			Msg("Would send email notification")
		_ = body
	}
}
