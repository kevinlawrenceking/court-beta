package worker

import (
	"context"
	"fmt"
	"time"

	"github.com/aws/aws-sdk-go-v2/aws"
	awsconfig "github.com/aws/aws-sdk-go-v2/config"
	"github.com/aws/aws-sdk-go-v2/service/sesv2"
	"github.com/aws/aws-sdk-go-v2/service/sesv2/types"
	"github.com/jackc/pgx/v5/pgxpool"
	"github.com/rs/zerolog/log"
)

// EmailNotifier sends email notifications for new case events to subscribers.
// Replaces: email_match.cfm
//
// Uses AWS SES v2 to deliver notification emails. Falls back to log-only
// mode when SES is not configured (development).
type EmailNotifier struct {
	pool      *pgxpool.Pool
	sesClient *sesv2.Client
	interval  time.Duration
	sender    string
	appURL    string
}

// NewEmailNotifier creates a new email notifier with SES support.
func NewEmailNotifier(pool *pgxpool.Pool, region, endpoint string, interval time.Duration, sender, appURL string) *EmailNotifier {
	n := &EmailNotifier{
		pool:     pool,
		interval: interval,
		sender:   sender,
		appURL:   appURL,
	}

	// Initialize SES client.
	cfg, err := awsconfig.LoadDefaultConfig(context.Background(), awsconfig.WithRegion(region))
	if err != nil {
		log.Warn().Err(err).Msg("SES client init failed; email notifier will run in log-only mode")
		return n
	}

	if endpoint != "" {
		n.sesClient = sesv2.NewFromConfig(cfg, func(o *sesv2.Options) {
			o.BaseEndpoint = aws.String(endpoint)
		})
	} else {
		n.sesClient = sesv2.NewFromConfig(cfg)
	}

	return n
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
		eventID     int
		caseID      int
		caseNumber  string
		caseName    string
		description string
		eventDate   *time.Time
	}

	var notifications []notification
	for rows.Next() {
		var notif notification
		if err := rows.Scan(&notif.eventID, &notif.caseID, &notif.caseNumber,
			&notif.caseName, &notif.description, &notif.eventDate); err != nil {
			continue
		}
		notifications = append(notifications, notif)
	}

	if len(notifications) == 0 {
		return
	}

	for _, notif := range notifications {
		n.sendNotification(ctx, notif.eventID, notif.caseID, notif.caseNumber, notif.caseName, notif.description)
	}
}

func (n *EmailNotifier) sendNotification(ctx context.Context, eventID, caseID int, caseNumber, caseName, description string) {
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
		caseURL := fmt.Sprintf("%s/cases/%d", n.appURL, caseID)

		textBody := fmt.Sprintf(
			"New court activity detected:\n\nCase: %s - %s\n\nEvent: %s\n\nView in DocketWatch: %s",
			caseNumber, caseName, description, caseURL,
		)

		htmlBody := fmt.Sprintf(`<div style="font-family: Arial, sans-serif; max-width: 600px;">
<h2 style="color: #1a237e;">DocketWatch Alert</h2>
<p>New court activity detected:</p>
<table style="border-collapse: collapse; width: 100%%;">
  <tr><td style="padding: 8px; font-weight: bold;">Case:</td><td style="padding: 8px;">%s - %s</td></tr>
  <tr><td style="padding: 8px; font-weight: bold;">Event:</td><td style="padding: 8px;">%s</td></tr>
</table>
<p style="margin-top: 20px;"><a href="%s" style="background: #1a237e; color: white; padding: 10px 20px; text-decoration: none; border-radius: 4px;">View in DocketWatch</a></p>
</div>`, caseNumber, caseName, description, caseURL)

		if n.sesClient == nil {
			log.Info().
				Str("to", email).
				Str("subject", subject).
				Msg("Would send email notification (SES not configured)")
			continue
		}

		_, err := n.sesClient.SendEmail(ctx, &sesv2.SendEmailInput{
			FromEmailAddress: aws.String(n.sender),
			Destination: &types.Destination{
				ToAddresses: []string{email},
			},
			Content: &types.EmailContent{
				Simple: &types.Message{
					Subject: &types.Content{
						Data:    aws.String(subject),
						Charset: aws.String("UTF-8"),
					},
					Body: &types.Body{
						Text: &types.Content{
							Data:    aws.String(textBody),
							Charset: aws.String("UTF-8"),
						},
						Html: &types.Content{
							Data:    aws.String(htmlBody),
							Charset: aws.String("UTF-8"),
						},
					},
				},
			},
		})
		if err != nil {
			log.Error().Err(err).
				Str("to", email).
				Str("case_number", caseNumber).
				Msg("Failed to send email via SES")
			continue
		}

		log.Info().
			Str("to", email).
			Str("case_number", caseNumber).
			Msg("Email notification sent")
	}

	// Mark the event as acknowledged after notifying
	_, err = n.pool.Exec(ctx, "UPDATE case_events SET acknowledged = TRUE WHERE id = $1", eventID)
	if err != nil {
		log.Error().Err(err).Int("event_id", eventID).Msg("Failed to mark event as acknowledged")
	}
}
