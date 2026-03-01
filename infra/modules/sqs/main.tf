variable "name_prefix" {
  type = string
}

# ─── Dead Letter Queues ──────────────────────────────────────────────────────

resource "aws_sqs_queue" "summarize_dlq" {
  name                      = "${var.name_prefix}-summarize-dlq"
  message_retention_seconds = 1209600 # 14 days

  tags = {
    Name = "${var.name_prefix}-summarize-dlq"
  }
}

resource "aws_sqs_queue" "qa_dlq" {
  name                      = "${var.name_prefix}-qa-dlq"
  message_retention_seconds = 1209600

  tags = {
    Name = "${var.name_prefix}-qa-dlq"
  }
}

resource "aws_sqs_queue" "pacer_dlq" {
  name                      = "${var.name_prefix}-pacer-dlq"
  message_retention_seconds = 1209600

  tags = {
    Name = "${var.name_prefix}-pacer-dlq"
  }
}

# ─── Main Queues ─────────────────────────────────────────────────────────────

resource "aws_sqs_queue" "summarize" {
  name                       = "${var.name_prefix}-summarize"
  visibility_timeout_seconds = 600 # 10 min - OCR + Gemini can be slow
  message_retention_seconds  = 345600 # 4 days
  receive_wait_time_seconds  = 20 # long polling

  redrive_policy = jsonencode({
    deadLetterTargetArn = aws_sqs_queue.summarize_dlq.arn
    maxReceiveCount     = 3
  })

  tags = {
    Name = "${var.name_prefix}-summarize"
  }
}

resource "aws_sqs_queue" "qa" {
  name                       = "${var.name_prefix}-qa"
  visibility_timeout_seconds = 120 # 2 min
  message_retention_seconds  = 86400 # 1 day
  receive_wait_time_seconds  = 20

  redrive_policy = jsonencode({
    deadLetterTargetArn = aws_sqs_queue.qa_dlq.arn
    maxReceiveCount     = 3
  })

  tags = {
    Name = "${var.name_prefix}-qa"
  }
}

resource "aws_sqs_queue" "pacer" {
  name                       = "${var.name_prefix}-pacer"
  visibility_timeout_seconds = 300 # 5 min
  message_retention_seconds  = 345600 # 4 days
  receive_wait_time_seconds  = 20

  redrive_policy = jsonencode({
    deadLetterTargetArn = aws_sqs_queue.pacer_dlq.arn
    maxReceiveCount     = 3
  })

  tags = {
    Name = "${var.name_prefix}-pacer"
  }
}

# ─── Outputs ─────────────────────────────────────────────────────────────────

output "summarize_queue_url" {
  value = aws_sqs_queue.summarize.url
}

output "summarize_queue_arn" {
  value = aws_sqs_queue.summarize.arn
}

output "qa_queue_url" {
  value = aws_sqs_queue.qa.url
}

output "qa_queue_arn" {
  value = aws_sqs_queue.qa.arn
}

output "pacer_queue_url" {
  value = aws_sqs_queue.pacer.url
}

output "pacer_queue_arn" {
  value = aws_sqs_queue.pacer.arn
}

output "summarize_dlq_arn" {
  value = aws_sqs_queue.summarize_dlq.arn
}

output "qa_dlq_arn" {
  value = aws_sqs_queue.qa_dlq.arn
}

output "pacer_dlq_arn" {
  value = aws_sqs_queue.pacer_dlq.arn
}
