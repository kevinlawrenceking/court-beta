output "vpc_id" {
  description = "VPC ID"
  value       = module.vpc.vpc_id
}

output "rds_endpoint" {
  description = "RDS PostgreSQL endpoint"
  value       = module.rds.endpoint
}

output "alb_dns_name" {
  description = "ALB DNS name for API"
  value       = module.alb.dns_name
}

output "cloudfront_domain" {
  description = "CloudFront distribution domain"
  value       = module.cloudfront.distribution_domain
}

output "cognito_user_pool_id" {
  description = "Cognito User Pool ID"
  value       = module.cognito.user_pool_id
}

output "cognito_client_id" {
  description = "Cognito App Client ID"
  value       = module.cognito.client_id
}

output "documents_bucket" {
  description = "S3 bucket for documents"
  value       = module.s3.documents_bucket_name
}

output "ecr_api_repo" {
  description = "ECR repository URL for API image"
  value       = module.ecs.ecr_api_repo_url
}

output "ecr_worker_repo" {
  description = "ECR repository URL for Go worker image"
  value       = module.ecs.ecr_worker_repo_url
}

output "ecr_python_repo" {
  description = "ECR repository URL for Python worker image"
  value       = module.ecs.ecr_python_repo_url
}

output "sqs_summarize_queue_url" {
  description = "SQS summarize queue URL"
  value       = module.sqs.summarize_queue_url
}
