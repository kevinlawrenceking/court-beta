variable "domain_name" {
  type = string
}

variable "ses_sender_email" {
  type = string
}

# ─── Domain Identity ────────────────────────────────────────────────────────

resource "aws_ses_domain_identity" "main" {
  domain = var.domain_name
}

resource "aws_ses_domain_dkim" "main" {
  domain = aws_ses_domain_identity.main.domain
}

# ─── Email Identity ─────────────────────────────────────────────────────────

resource "aws_ses_email_identity" "sender" {
  email = var.ses_sender_email
}

# ─── Configuration Set ──────────────────────────────────────────────────────

resource "aws_ses_configuration_set" "main" {
  name = "docketwatch-alerts"

  delivery_options {
    tls_policy = "Require"
  }
}

# ─── SNS Topic for Bounces/Complaints ───────────────────────────────────────

resource "aws_sns_topic" "ses_bounces" {
  name = "docketwatch-ses-bounces"
}

resource "aws_sns_topic" "ses_complaints" {
  name = "docketwatch-ses-complaints"
}

resource "aws_ses_identity_notification_topic" "bounces" {
  topic_arn                = aws_sns_topic.ses_bounces.arn
  notification_type        = "Bounce"
  identity                 = aws_ses_domain_identity.main.domain
  include_original_headers = true
}

resource "aws_ses_identity_notification_topic" "complaints" {
  topic_arn                = aws_sns_topic.ses_complaints.arn
  notification_type        = "Complaint"
  identity                 = aws_ses_domain_identity.main.domain
  include_original_headers = true
}

# ─── Outputs ─────────────────────────────────────────────────────────────────

output "domain_identity_arn" {
  value = aws_ses_domain_identity.main.arn
}

output "dkim_tokens" {
  description = "DKIM CNAME records to add to DNS"
  value       = aws_ses_domain_dkim.main.dkim_tokens
}

output "verification_token" {
  description = "TXT record value for domain verification"
  value       = aws_ses_domain_identity.main.verification_token
}
