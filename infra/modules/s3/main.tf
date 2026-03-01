variable "name_prefix" {
  type = string
}

variable "environment" {
  type = string
}

# ─── Documents Bucket ────────────────────────────────────────────────────────

resource "aws_s3_bucket" "documents" {
  bucket = "${var.name_prefix}-documents"

  tags = {
    Name = "${var.name_prefix}-documents"
  }
}

resource "aws_s3_bucket_versioning" "documents" {
  bucket = aws_s3_bucket.documents.id
  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "documents" {
  bucket = aws_s3_bucket.documents.id
  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "aws:kms"
    }
  }
}

resource "aws_s3_bucket_public_access_block" "documents" {
  bucket = aws_s3_bucket.documents.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_s3_bucket_lifecycle_configuration" "documents" {
  bucket = aws_s3_bucket.documents.id

  rule {
    id     = "archive-old-documents"
    status = "Enabled"

    transition {
      days          = 365
      storage_class = "GLACIER_IR"
    }
  }
}

# ─── Uploads Bucket (temporary) ─────────────────────────────────────────────

resource "aws_s3_bucket" "uploads" {
  bucket = "${var.name_prefix}-uploads"

  tags = {
    Name = "${var.name_prefix}-uploads"
  }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "uploads" {
  bucket = aws_s3_bucket.uploads.id
  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

resource "aws_s3_bucket_public_access_block" "uploads" {
  bucket = aws_s3_bucket.uploads.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_s3_bucket_lifecycle_configuration" "uploads" {
  bucket = aws_s3_bucket.uploads.id

  rule {
    id     = "expire-temp-uploads"
    status = "Enabled"

    expiration {
      days = 7
    }
  }
}

# ─── SPA Bucket (Flutter Web) ───────────────────────────────────────────────

resource "aws_s3_bucket" "spa" {
  bucket = "${var.name_prefix}-spa"

  tags = {
    Name = "${var.name_prefix}-spa"
  }
}

resource "aws_s3_bucket_public_access_block" "spa" {
  bucket = aws_s3_bucket.spa.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

# ─── Outputs ─────────────────────────────────────────────────────────────────

output "documents_bucket_name" {
  value = aws_s3_bucket.documents.bucket
}

output "documents_bucket_arn" {
  value = aws_s3_bucket.documents.arn
}

output "uploads_bucket_name" {
  value = aws_s3_bucket.uploads.bucket
}

output "uploads_bucket_arn" {
  value = aws_s3_bucket.uploads.arn
}

output "spa_bucket_name" {
  value = aws_s3_bucket.spa.bucket
}

output "spa_bucket_arn" {
  value = aws_s3_bucket.spa.arn
}

output "spa_bucket_regional_domain" {
  value = aws_s3_bucket.spa.bucket_regional_domain_name
}
