variable "aws_region" {
  description = "AWS region"
  type        = string
  default     = "us-west-2"
}

variable "environment" {
  description = "Environment name (production, staging)"
  type        = string
  default     = "production"
}

variable "project_name" {
  description = "Project name used for resource naming"
  type        = string
  default     = "docketwatch"
}

# VPC
variable "vpc_cidr" {
  description = "CIDR block for VPC"
  type        = string
  default     = "10.0.0.0/16"
}

variable "availability_zones" {
  description = "Availability zones"
  type        = list(string)
  default     = ["us-west-2a", "us-west-2b"]
}

# RDS
variable "db_instance_class" {
  description = "RDS instance class"
  type        = string
  default     = "db.t4g.medium"
}

variable "db_name" {
  description = "Database name"
  type        = string
  default     = "docketwatch"
}

variable "db_username" {
  description = "Database master username"
  type        = string
  default     = "docketwatch_admin"
  sensitive   = true
}

# ECS
variable "api_cpu" {
  description = "CPU units for API task (1024 = 1 vCPU)"
  type        = number
  default     = 512
}

variable "api_memory" {
  description = "Memory (MiB) for API task"
  type        = number
  default     = 1024
}

variable "api_desired_count" {
  description = "Desired number of API tasks"
  type        = number
  default     = 2
}

variable "worker_cpu" {
  description = "CPU units for Go worker task"
  type        = number
  default     = 256
}

variable "worker_memory" {
  description = "Memory (MiB) for Go worker task"
  type        = number
  default     = 512
}

variable "python_worker_cpu" {
  description = "CPU units for Python worker task"
  type        = number
  default     = 1024
}

variable "python_worker_memory" {
  description = "Memory (MiB) for Python worker task"
  type        = number
  default     = 2048
}

# Domain
variable "domain_name" {
  description = "Domain name for the application"
  type        = string
  default     = "docketwatch.tmz.tv"
}

variable "certificate_arn" {
  description = "ARN of ACM certificate for HTTPS"
  type        = string
  default     = ""
}

# SES
variable "ses_sender_email" {
  description = "Verified SES sender email address"
  type        = string
  default     = "alerts@docketwatch.tmz.tv"
}
