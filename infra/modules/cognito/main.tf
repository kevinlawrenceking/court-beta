variable "name_prefix" {
  type = string
}

variable "ses_sender_email" {
  type = string
}

# ─── User Pool ───────────────────────────────────────────────────────────────

resource "aws_cognito_user_pool" "main" {
  name = "${var.name_prefix}-users"

  username_attributes      = ["email"]
  auto_verified_attributes = ["email"]

  password_policy {
    minimum_length                   = 12
    require_lowercase                = true
    require_uppercase                = true
    require_numbers                  = true
    require_symbols                  = true
    temporary_password_validity_days = 7
  }

  account_recovery_setting {
    recovery_mechanism {
      name     = "verified_email"
      priority = 1
    }
  }

  admin_create_user_config {
    allow_admin_create_user_only = true

    invite_message_template {
      email_subject = "DocketWatch - Your Account"
      email_message = "Your DocketWatch username is {username} and temporary password is {####}."
      sms_message   = "Your DocketWatch username is {username} and temporary password is {####}."
    }
  }

  email_configuration {
    email_sending_account = "DEVELOPER"
    from_email_address    = var.ses_sender_email
    source_arn            = "arn:aws:ses:us-west-2:${data.aws_caller_identity.current.account_id}:identity/${var.ses_sender_email}"
  }

  schema {
    name                = "department"
    attribute_data_type = "String"
    mutable             = true
    string_attribute_constraints {
      max_length = 100
    }
  }

  tags = {
    Name = "${var.name_prefix}-users"
  }
}

data "aws_caller_identity" "current" {}

# ─── User Pool Groups ───────────────────────────────────────────────────────

resource "aws_cognito_user_group" "admin" {
  name         = "admin"
  user_pool_id = aws_cognito_user_pool.main.id
  description  = "Administrators with full access"
}

resource "aws_cognito_user_group" "editor" {
  name         = "editor"
  user_pool_id = aws_cognito_user_pool.main.id
  description  = "Editors who can manage cases and summaries"
}

resource "aws_cognito_user_group" "viewer" {
  name         = "viewer"
  user_pool_id = aws_cognito_user_pool.main.id
  description  = "Read-only viewers"
}

# ─── App Client (Flutter Web) ───────────────────────────────────────────────

resource "aws_cognito_user_pool_client" "web" {
  name         = "${var.name_prefix}-web-client"
  user_pool_id = aws_cognito_user_pool.main.id

  generate_secret                      = false
  explicit_auth_flows                  = ["ALLOW_USER_SRP_AUTH", "ALLOW_REFRESH_TOKEN_AUTH"]
  supported_identity_providers         = ["COGNITO"]
  prevent_user_existence_errors        = "ENABLED"

  access_token_validity  = 1  # hours
  id_token_validity      = 1  # hours
  refresh_token_validity = 30 # days

  token_validity_units {
    access_token  = "hours"
    id_token      = "hours"
    refresh_token = "days"
  }
}

# ─── Outputs ─────────────────────────────────────────────────────────────────

output "user_pool_id" {
  value = aws_cognito_user_pool.main.id
}

output "user_pool_arn" {
  value = aws_cognito_user_pool.main.arn
}

output "client_id" {
  value = aws_cognito_user_pool_client.web.id
}
