locals {
  name_prefix = "${var.project_name}-${var.environment}"
}

# ─── VPC ──────────────────────────────────────────────────────────────────────

module "vpc" {
  source = "./modules/vpc"

  name_prefix        = local.name_prefix
  vpc_cidr           = var.vpc_cidr
  availability_zones = var.availability_zones
}

# ─── S3 Buckets ───────────────────────────────────────────────────────────────

module "s3" {
  source = "./modules/s3"

  name_prefix = local.name_prefix
  environment = var.environment
}

# ─── SQS Queues ──────────────────────────────────────────────────────────────

module "sqs" {
  source = "./modules/sqs"

  name_prefix = local.name_prefix
}

# ─── RDS PostgreSQL ──────────────────────────────────────────────────────────

module "rds" {
  source = "./modules/rds"

  name_prefix        = local.name_prefix
  vpc_id             = module.vpc.vpc_id
  private_subnet_ids = module.vpc.private_subnet_ids
  db_instance_class  = var.db_instance_class
  db_name            = var.db_name
  db_username        = var.db_username
  ecs_security_group_id = module.ecs.ecs_security_group_id
}

# ─── Cognito ─────────────────────────────────────────────────────────────────

module "cognito" {
  source = "./modules/cognito"

  name_prefix      = local.name_prefix
  ses_sender_email = var.ses_sender_email
}

# ─── ALB ─────────────────────────────────────────────────────────────────────

module "alb" {
  source = "./modules/alb"

  name_prefix       = local.name_prefix
  vpc_id            = module.vpc.vpc_id
  public_subnet_ids = module.vpc.public_subnet_ids
  certificate_arn   = var.certificate_arn
}

# ─── ECS Cluster & Services ─────────────────────────────────────────────────

module "ecs" {
  source = "./modules/ecs"

  name_prefix        = local.name_prefix
  aws_region         = var.aws_region
  vpc_id             = module.vpc.vpc_id
  private_subnet_ids = module.vpc.private_subnet_ids
  alb_target_group_arn = module.alb.api_target_group_arn

  # API service
  api_cpu           = var.api_cpu
  api_memory        = var.api_memory
  api_desired_count = var.api_desired_count

  # Go worker service
  worker_cpu    = var.worker_cpu
  worker_memory = var.worker_memory

  # Python worker service
  python_worker_cpu    = var.python_worker_cpu
  python_worker_memory = var.python_worker_memory

  # Dependencies
  db_endpoint           = module.rds.endpoint
  db_name               = var.db_name
  db_username           = var.db_username
  db_password_secret_arn = module.rds.password_secret_arn
  documents_bucket      = module.s3.documents_bucket_name
  uploads_bucket        = module.s3.uploads_bucket_name
  cognito_user_pool_id  = module.cognito.user_pool_id
  cognito_client_id     = module.cognito.client_id
  sqs_summarize_url     = module.sqs.summarize_queue_url
  sqs_qa_url            = module.sqs.qa_queue_url
  sqs_pacer_url         = module.sqs.pacer_queue_url
  alb_security_group_id = module.alb.security_group_id
}

# ─── CloudFront ──────────────────────────────────────────────────────────────

module "cloudfront" {
  source = "./modules/cloudfront"

  name_prefix     = local.name_prefix
  domain_name     = var.domain_name
  certificate_arn = var.certificate_arn
  alb_dns_name    = module.alb.dns_name
  spa_bucket_name = module.s3.spa_bucket_name
  spa_bucket_arn  = module.s3.spa_bucket_arn
  spa_bucket_regional_domain = module.s3.spa_bucket_regional_domain
}

# ─── SES ─────────────────────────────────────────────────────────────────────

module "ses" {
  source = "./modules/ses"

  domain_name      = var.domain_name
  ses_sender_email = var.ses_sender_email
}
