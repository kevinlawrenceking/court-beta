aws_region  = "us-west-2"
environment = "production"

# VPC
vpc_cidr           = "10.0.0.0/16"
availability_zones = ["us-west-2a", "us-west-2b"]

# RDS
db_instance_class = "db.t4g.medium"
db_name           = "docketwatch"

# ECS - API
api_cpu           = 512
api_memory        = 1024
api_desired_count = 2

# ECS - Go Worker
worker_cpu    = 256
worker_memory = 512

# ECS - Python Worker (needs more resources for OCR)
python_worker_cpu    = 1024
python_worker_memory = 2048

# Domain
domain_name = "docketwatch.tmz.tv"
# certificate_arn = "arn:aws:acm:us-east-1:ACCOUNT_ID:certificate/CERT_ID"

# SES
ses_sender_email = "alerts@docketwatch.tmz.tv"
