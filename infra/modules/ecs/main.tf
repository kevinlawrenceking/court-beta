variable "name_prefix" {
  type = string
}

variable "aws_region" {
  type = string
}

variable "vpc_id" {
  type = string
}

variable "private_subnet_ids" {
  type = list(string)
}

variable "alb_target_group_arn" {
  type = string
}

variable "alb_security_group_id" {
  type = string
}

variable "api_cpu" {
  type = number
}

variable "api_memory" {
  type = number
}

variable "api_desired_count" {
  type = number
}

variable "worker_cpu" {
  type = number
}

variable "worker_memory" {
  type = number
}

variable "python_worker_cpu" {
  type = number
}

variable "python_worker_memory" {
  type = number
}

variable "db_endpoint" {
  type = string
}

variable "db_name" {
  type = string
}

variable "db_username" {
  type      = string
  sensitive = true
}

variable "db_password_secret_arn" {
  type = string
}

variable "documents_bucket" {
  type = string
}

variable "uploads_bucket" {
  type = string
}

variable "cognito_user_pool_id" {
  type = string
}

variable "cognito_client_id" {
  type = string
}

variable "sqs_summarize_url" {
  type = string
}

variable "sqs_qa_url" {
  type = string
}

variable "sqs_pacer_url" {
  type = string
}

# ─── ECS Cluster ─────────────────────────────────────────────────────────────

resource "aws_ecs_cluster" "main" {
  name = "${var.name_prefix}-cluster"

  setting {
    name  = "containerInsights"
    value = "enabled"
  }

  tags = {
    Name = "${var.name_prefix}-cluster"
  }
}

# ─── ECR Repositories ───────────────────────────────────────────────────────

resource "aws_ecr_repository" "api" {
  name                 = "${var.name_prefix}-api"
  image_tag_mutability = "MUTABLE"
  force_delete         = false

  image_scanning_configuration {
    scan_on_push = true
  }
}

resource "aws_ecr_repository" "worker" {
  name                 = "${var.name_prefix}-worker"
  image_tag_mutability = "MUTABLE"
  force_delete         = false

  image_scanning_configuration {
    scan_on_push = true
  }
}

resource "aws_ecr_repository" "python_worker" {
  name                 = "${var.name_prefix}-python-worker"
  image_tag_mutability = "MUTABLE"
  force_delete         = false

  image_scanning_configuration {
    scan_on_push = true
  }
}

# Lifecycle policy to keep last 10 images
resource "aws_ecr_lifecycle_policy" "cleanup" {
  for_each   = toset(["api", "worker", "python_worker"])
  repository = aws_ecr_repository[each.key].name

  policy = jsonencode({
    rules = [{
      rulePriority = 1
      description  = "Keep last 10 images"
      selection = {
        tagStatus   = "any"
        countType   = "imageCountMoreThan"
        countNumber = 10
      }
      action = {
        type = "expire"
      }
    }]
  })
}

# ─── ECS Task Execution Role ────────────────────────────────────────────────

resource "aws_iam_role" "ecs_execution" {
  name_prefix = "${var.name_prefix}-exec-"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action = "sts:AssumeRole"
      Effect = "Allow"
      Principal = {
        Service = "ecs-tasks.amazonaws.com"
      }
    }]
  })
}

resource "aws_iam_role_policy_attachment" "ecs_execution" {
  role       = aws_iam_role.ecs_execution.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy"
}

resource "aws_iam_role_policy" "ecs_execution_secrets" {
  name_prefix = "secrets-"
  role        = aws_iam_role.ecs_execution.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect   = "Allow"
      Action   = ["secretsmanager:GetSecretValue"]
      Resource = [var.db_password_secret_arn]
    }]
  })
}

# ─── ECS Task Role ──────────────────────────────────────────────────────────

resource "aws_iam_role" "ecs_task" {
  name_prefix = "${var.name_prefix}-task-"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action = "sts:AssumeRole"
      Effect = "Allow"
      Principal = {
        Service = "ecs-tasks.amazonaws.com"
      }
    }]
  })
}

resource "aws_iam_role_policy" "ecs_task" {
  name_prefix = "task-"
  role        = aws_iam_role.ecs_task.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "s3:GetObject",
          "s3:PutObject",
          "s3:DeleteObject",
          "s3:ListBucket"
        ]
        Resource = [
          "arn:aws:s3:::${var.documents_bucket}",
          "arn:aws:s3:::${var.documents_bucket}/*",
          "arn:aws:s3:::${var.uploads_bucket}",
          "arn:aws:s3:::${var.uploads_bucket}/*"
        ]
      },
      {
        Effect = "Allow"
        Action = [
          "sqs:SendMessage",
          "sqs:ReceiveMessage",
          "sqs:DeleteMessage",
          "sqs:GetQueueAttributes",
          "sqs:ChangeMessageVisibility"
        ]
        Resource = ["arn:aws:sqs:*:*:${var.name_prefix}-*"]
      },
      {
        Effect = "Allow"
        Action = [
          "ses:SendEmail",
          "ses:SendRawEmail"
        ]
        Resource = ["*"]
      },
      {
        Effect = "Allow"
        Action = ["logs:CreateLogStream", "logs:PutLogEvents"]
        Resource = ["*"]
      }
    ]
  })
}

# ─── Security Group ─────────────────────────────────────────────────────────

resource "aws_security_group" "ecs" {
  name_prefix = "${var.name_prefix}-ecs-"
  vpc_id      = var.vpc_id
  description = "Security group for ECS tasks"

  ingress {
    from_port       = 8080
    to_port         = 8080
    protocol        = "tcp"
    security_groups = [var.alb_security_group_id]
    description     = "API from ALB"
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
    description = "All outbound"
  }

  tags = {
    Name = "${var.name_prefix}-ecs-sg"
  }

  lifecycle {
    create_before_destroy = true
  }
}

# ─── CloudWatch Log Groups ──────────────────────────────────────────────────

resource "aws_cloudwatch_log_group" "api" {
  name              = "/ecs/${var.name_prefix}-api"
  retention_in_days = 30
}

resource "aws_cloudwatch_log_group" "worker" {
  name              = "/ecs/${var.name_prefix}-worker"
  retention_in_days = 30
}

resource "aws_cloudwatch_log_group" "python_worker" {
  name              = "/ecs/${var.name_prefix}-python-worker"
  retention_in_days = 30
}

# ─── API Task Definition ────────────────────────────────────────────────────

resource "aws_ecs_task_definition" "api" {
  family                   = "${var.name_prefix}-api"
  network_mode             = "awsvpc"
  requires_compatibilities = ["FARGATE"]
  cpu                      = var.api_cpu
  memory                   = var.api_memory
  execution_role_arn       = aws_iam_role.ecs_execution.arn
  task_role_arn            = aws_iam_role.ecs_task.arn

  container_definitions = jsonencode([{
    name      = "api"
    image     = "${aws_ecr_repository.api.repository_url}:latest"
    essential = true

    portMappings = [{
      containerPort = 8080
      protocol      = "tcp"
    }]

    environment = [
      { name = "PORT", value = "8080" },
      { name = "DB_HOST", value = split(":", var.db_endpoint)[0] },
      { name = "DB_PORT", value = "5432" },
      { name = "DB_NAME", value = var.db_name },
      { name = "DB_USER", value = var.db_username },
      { name = "DB_SSL_MODE", value = "require" },
      { name = "AWS_REGION", value = var.aws_region },
      { name = "S3_DOCUMENTS_BUCKET", value = var.documents_bucket },
      { name = "S3_UPLOADS_BUCKET", value = var.uploads_bucket },
      { name = "COGNITO_USER_POOL_ID", value = var.cognito_user_pool_id },
      { name = "COGNITO_CLIENT_ID", value = var.cognito_client_id },
      { name = "SQS_SUMMARIZE_QUEUE_URL", value = var.sqs_summarize_url },
      { name = "SQS_QA_QUEUE_URL", value = var.sqs_qa_url },
      { name = "SQS_PACER_QUEUE_URL", value = var.sqs_pacer_url },
    ]

    secrets = [{
      name      = "DB_PASSWORD"
      valueFrom = var.db_password_secret_arn
    }]

    logConfiguration = {
      logDriver = "awslogs"
      options = {
        "awslogs-group"         = aws_cloudwatch_log_group.api.name
        "awslogs-region"        = var.aws_region
        "awslogs-stream-prefix" = "api"
      }
    }
  }])
}

# ─── API Service ─────────────────────────────────────────────────────────────

resource "aws_ecs_service" "api" {
  name            = "${var.name_prefix}-api"
  cluster         = aws_ecs_cluster.main.id
  task_definition = aws_ecs_task_definition.api.arn
  desired_count   = var.api_desired_count
  launch_type     = "FARGATE"

  network_configuration {
    subnets          = var.private_subnet_ids
    security_groups  = [aws_security_group.ecs.id]
    assign_public_ip = false
  }

  load_balancer {
    target_group_arn = var.alb_target_group_arn
    container_name   = "api"
    container_port   = 8080
  }

  deployment_circuit_breaker {
    enable   = true
    rollback = true
  }

  deployment_minimum_healthy_percent = 50
  deployment_maximum_percent         = 200

  lifecycle {
    ignore_changes = [task_definition]
  }
}

# ─── Go Worker Task Definition ───────────────────────────────────────────────

resource "aws_ecs_task_definition" "worker" {
  family                   = "${var.name_prefix}-worker"
  network_mode             = "awsvpc"
  requires_compatibilities = ["FARGATE"]
  cpu                      = var.worker_cpu
  memory                   = var.worker_memory
  execution_role_arn       = aws_iam_role.ecs_execution.arn
  task_role_arn            = aws_iam_role.ecs_task.arn

  container_definitions = jsonencode([{
    name      = "worker"
    image     = "${aws_ecr_repository.worker.repository_url}:latest"
    essential = true

    environment = [
      { name = "DB_HOST", value = split(":", var.db_endpoint)[0] },
      { name = "DB_PORT", value = "5432" },
      { name = "DB_NAME", value = var.db_name },
      { name = "DB_USER", value = var.db_username },
      { name = "DB_SSL_MODE", value = "require" },
      { name = "AWS_REGION", value = var.aws_region },
      { name = "S3_DOCUMENTS_BUCKET", value = var.documents_bucket },
      { name = "SQS_SUMMARIZE_QUEUE_URL", value = var.sqs_summarize_url },
    ]

    secrets = [{
      name      = "DB_PASSWORD"
      valueFrom = var.db_password_secret_arn
    }]

    logConfiguration = {
      logDriver = "awslogs"
      options = {
        "awslogs-group"         = aws_cloudwatch_log_group.worker.name
        "awslogs-region"        = var.aws_region
        "awslogs-stream-prefix" = "worker"
      }
    }
  }])
}

# ─── Go Worker Service ──────────────────────────────────────────────────────

resource "aws_ecs_service" "worker" {
  name            = "${var.name_prefix}-worker"
  cluster         = aws_ecs_cluster.main.id
  task_definition = aws_ecs_task_definition.worker.arn
  desired_count   = 1
  launch_type     = "FARGATE"

  network_configuration {
    subnets          = var.private_subnet_ids
    security_groups  = [aws_security_group.ecs.id]
    assign_public_ip = false
  }

  deployment_circuit_breaker {
    enable   = true
    rollback = true
  }

  lifecycle {
    ignore_changes = [task_definition]
  }
}

# ─── Python Worker Task Definition ──────────────────────────────────────────

resource "aws_ecs_task_definition" "python_worker" {
  family                   = "${var.name_prefix}-python-worker"
  network_mode             = "awsvpc"
  requires_compatibilities = ["FARGATE"]
  cpu                      = var.python_worker_cpu
  memory                   = var.python_worker_memory
  execution_role_arn       = aws_iam_role.ecs_execution.arn
  task_role_arn            = aws_iam_role.ecs_task.arn

  container_definitions = jsonencode([{
    name      = "python-worker"
    image     = "${aws_ecr_repository.python_worker.repository_url}:latest"
    essential = true

    environment = [
      { name = "DB_HOST", value = split(":", var.db_endpoint)[0] },
      { name = "DB_PORT", value = "5432" },
      { name = "DB_NAME", value = var.db_name },
      { name = "DB_USER", value = var.db_username },
      { name = "DB_SSL_MODE", value = "require" },
      { name = "AWS_REGION", value = var.aws_region },
      { name = "S3_DOCUMENTS_BUCKET", value = var.documents_bucket },
      { name = "S3_UPLOADS_BUCKET", value = var.uploads_bucket },
      { name = "SQS_SUMMARIZE_QUEUE_URL", value = var.sqs_summarize_url },
      { name = "SQS_QA_QUEUE_URL", value = var.sqs_qa_url },
      { name = "SQS_PACER_QUEUE_URL", value = var.sqs_pacer_url },
    ]

    secrets = [{
      name      = "DB_PASSWORD"
      valueFrom = var.db_password_secret_arn
    }]

    logConfiguration = {
      logDriver = "awslogs"
      options = {
        "awslogs-group"         = aws_cloudwatch_log_group.python_worker.name
        "awslogs-region"        = var.aws_region
        "awslogs-stream-prefix" = "python"
      }
    }
  }])
}

# ─── Python Worker Service ──────────────────────────────────────────────────

resource "aws_ecs_service" "python_worker" {
  name            = "${var.name_prefix}-python-worker"
  cluster         = aws_ecs_cluster.main.id
  task_definition = aws_ecs_task_definition.python_worker.arn
  desired_count   = 2
  launch_type     = "FARGATE"

  network_configuration {
    subnets          = var.private_subnet_ids
    security_groups  = [aws_security_group.ecs.id]
    assign_public_ip = false
  }

  deployment_circuit_breaker {
    enable   = true
    rollback = true
  }

  lifecycle {
    ignore_changes = [task_definition]
  }
}

# ─── Auto Scaling (API) ─────────────────────────────────────────────────────

resource "aws_appautoscaling_target" "api" {
  max_capacity       = 6
  min_capacity       = 2
  resource_id        = "service/${aws_ecs_cluster.main.name}/${aws_ecs_service.api.name}"
  scalable_dimension = "ecs:service:DesiredCount"
  service_namespace  = "ecs"
}

resource "aws_appautoscaling_policy" "api_cpu" {
  name               = "${var.name_prefix}-api-cpu-scaling"
  policy_type        = "TargetTrackingScaling"
  resource_id        = aws_appautoscaling_target.api.resource_id
  scalable_dimension = aws_appautoscaling_target.api.scalable_dimension
  service_namespace  = aws_appautoscaling_target.api.service_namespace

  target_tracking_scaling_policy_configuration {
    predefined_metric_specification {
      predefined_metric_type = "ECSServiceAverageCPUUtilization"
    }
    target_value       = 70.0
    scale_in_cooldown  = 300
    scale_out_cooldown = 60
  }
}

# ─── CloudWatch Alarms ──────────────────────────────────────────────────────

resource "aws_cloudwatch_metric_alarm" "api_high_cpu" {
  alarm_name          = "${var.name_prefix}-api-high-cpu"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 3
  metric_name         = "CPUUtilization"
  namespace           = "AWS/ECS"
  period              = 60
  statistic           = "Average"
  threshold           = 85
  alarm_description   = "API CPU utilization above 85% for 3 minutes"

  dimensions = {
    ClusterName = aws_ecs_cluster.main.name
    ServiceName = aws_ecs_service.api.name
  }
}

resource "aws_cloudwatch_metric_alarm" "python_worker_high_cpu" {
  alarm_name          = "${var.name_prefix}-python-worker-high-cpu"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 3
  metric_name         = "CPUUtilization"
  namespace           = "AWS/ECS"
  period              = 60
  statistic           = "Average"
  threshold           = 90
  alarm_description   = "Python worker CPU above 90% for 3 minutes"

  dimensions = {
    ClusterName = aws_ecs_cluster.main.name
    ServiceName = aws_ecs_service.python_worker.name
  }
}

# ─── Outputs ─────────────────────────────────────────────────────────────────

output "cluster_name" {
  value = aws_ecs_cluster.main.name
}

output "ecs_security_group_id" {
  value = aws_security_group.ecs.id
}

output "ecr_api_repo_url" {
  value = aws_ecr_repository.api.repository_url
}

output "ecr_worker_repo_url" {
  value = aws_ecr_repository.worker.repository_url
}

output "ecr_python_repo_url" {
  value = aws_ecr_repository.python_worker.repository_url
}
