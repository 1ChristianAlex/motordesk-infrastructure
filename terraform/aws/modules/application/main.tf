terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "6.37.0"
    }
    random = {
      source  = "hashicorp/random"
      version = "3.7.2"
    }
  }
}

data "aws_partition" "current" {}
data "aws_caller_identity" "current" {}
data "aws_availability_zones" "available" {
  state = "available"
}

locals {
  availability_zones = slice(data.aws_availability_zones.available.names, 0, 2)
  eks_cluster_name   = "${var.project_name}-${var.environment}"
  eks_node_scaling = {
    min_size      = 1
    max_size      = 4
    desired_size  = 4
    instance_type = "m7i-flex.large"
  }
}

resource "aws_ecr_repository" "api" {
  name                 = "${var.project_name}/${var.environment}/api"
  image_tag_mutability = "IMMUTABLE"

  image_scanning_configuration {
    scan_on_push = true
  }

  encryption_configuration {
    encryption_type = "AES256"
  }
}

resource "aws_ecr_lifecycle_policy" "api" {
  repository = aws_ecr_repository.api.name
  policy = jsonencode({
    rules = [{
      rulePriority = 1
      description  = "Retain the most recent 2 images"
      selection = {
        tagStatus   = "any"
        countType   = "imageCountMoreThan"
        countNumber = 2
      }


      action = {
        type = "expire"
      }
    }]
  })
}

resource "aws_secretsmanager_secret" "redis_auth_token" {
  name                    = "${var.project_name}/${var.environment}/redis-auth-token"
  recovery_window_in_days = 7
}

resource "random_password" "redis_auth_token" {
  length  = 32
  special = false
}

resource "aws_secretsmanager_secret_version" "redis_auth_token" {
  secret_id     = aws_secretsmanager_secret.redis_auth_token.id
  secret_string = random_password.redis_auth_token.result
}

resource "aws_secretsmanager_secret" "jwt_secret" {
  name                    = "${var.project_name}/${var.environment}/jwt-secret"
  recovery_window_in_days = 7
}

resource "aws_secretsmanager_secret" "mongo_credentials" {
  name                    = "${var.project_name}/${var.environment}/mongo-credentials"
  recovery_window_in_days = 7
}

resource "random_password" "jwt_secret" {
  length  = 64
  special = false
}

resource "random_password" "mongo_root_password" {
  length  = 40
  special = false
}

resource "random_password" "mongo_app_password" {
  length  = 40
  special = false
}

resource "aws_secretsmanager_secret_version" "jwt_secret" {
  secret_id     = aws_secretsmanager_secret.jwt_secret.id
  secret_string = random_password.jwt_secret.result
}

resource "aws_secretsmanager_secret_version" "mongo_credentials" {
  secret_id = aws_secretsmanager_secret.mongo_credentials.id
  secret_string = jsonencode({
    root_username = "motordesk_admin"
    root_password = random_password.mongo_root_password.result
    username      = "motordesk_app"
    password      = random_password.mongo_app_password.result
  })
}

resource "aws_ssm_parameter" "aws_region" {
  name  = "/${var.project_name}/${var.environment}/aws-region"
  type  = "String"
  value = var.aws_region
}

resource "aws_ssm_parameter" "ses_from_address" {
  name  = "/${var.project_name}/${var.environment}/ses-from-address"
  type  = "String"
  value = var.ses_from_address
}

resource "aws_ssm_parameter" "jwt_issuer" {
  name  = "/${var.project_name}/${var.environment}/jwt-issuer"
  type  = "String"
  value = var.jwt_issuer
}

resource "aws_ssm_parameter" "jwt_audience" {
  name  = "/${var.project_name}/${var.environment}/jwt-audience"
  type  = "String"
  value = var.jwt_audience
}

resource "aws_ssm_parameter" "jwt_realm" {
  name  = "/${var.project_name}/${var.environment}/jwt-realm"
  type  = "String"
  value = var.jwt_realm
}

resource "aws_ssm_parameter" "postgres_jdbc_url" {
  name  = "/${var.project_name}/${var.environment}/database-url"
  type  = "String"
  value = "jdbc:postgresql://${aws_db_instance.postgres.address}:5432/${var.postgres_database_name}"
}

resource "aws_ssm_parameter" "postgres_username" {
  name  = "/${var.project_name}/${var.environment}/database-user"
  type  = "String"
  value = var.postgres_admin_username
}

resource "aws_ssm_parameter" "redis_endpoint" {
  name  = "/${var.project_name}/${var.environment}/redis-host"
  type  = "String"
  value = aws_elasticache_replication_group.redis.primary_endpoint_address
}

resource "aws_ssm_parameter" "mongo_database" {
  name  = "/${var.project_name}/${var.environment}/mongo-database"
  type  = "String"
  value = var.mongo_database
}

resource "aws_db_subnet_group" "postgres" {
  name       = "${var.project_name}-${var.environment}-postgres"
  subnet_ids = aws_subnet.data[*].id
}

resource "aws_security_group" "postgres" {
  name        = "${var.project_name}-${var.environment}-postgres"
  description = "PostgreSQL access only from EKS worker nodes."
  vpc_id      = aws_vpc.main.id

  egress = []
}

resource "aws_db_instance" "postgres" {
  identifier                  = "${var.project_name}-${var.environment}-postgres"
  engine                      = "postgres"
  instance_class              = var.postgres_instance_class
  allocated_storage           = 20
  max_allocated_storage       = 100
  storage_encrypted           = true
  db_name                     = var.postgres_database_name
  username                    = var.postgres_admin_username
  manage_master_user_password = true
  db_subnet_group_name        = aws_db_subnet_group.postgres.name
  vpc_security_group_ids      = [aws_security_group.postgres.id]
  publicly_accessible         = false
  multi_az                    = false
  backup_retention_period     = var.backup_retention_days
  deletion_protection         = var.environment == "prod"
  skip_final_snapshot         = var.environment != "prod"
  final_snapshot_identifier   = var.environment == "prod" ? "${var.project_name}-${var.environment}-final" : null
  apply_immediately           = var.apply_database_changes_immediately

  lifecycle {
    prevent_destroy = false
  }
}

resource "aws_efs_file_system" "mongo" {
  encrypted        = true
  performance_mode = "generalPurpose"
  throughput_mode  = "bursting"

  lifecycle {
    prevent_destroy = false
  }
}

resource "aws_efs_backup_policy" "mongo" {
  file_system_id = aws_efs_file_system.mongo.id

  backup_policy {
    status = "ENABLED"
  }
}

resource "aws_efs_access_point" "mongo" {
  file_system_id = aws_efs_file_system.mongo.id

  posix_user {
    uid = 999
    gid = 999
  }

  root_directory {
    path = "/mongo"

    creation_info {
      owner_uid   = 999
      owner_gid   = 999
      permissions = "0750"
    }

  }

  lifecycle {
    prevent_destroy = false
  }
}

resource "aws_efs_mount_target" "mongo" {
  count           = length(aws_subnet.data)
  file_system_id  = aws_efs_file_system.mongo.id
  subnet_id       = aws_subnet.data[count.index].id
  security_groups = [aws_security_group.mongo_efs.id]
}

removed {
  from = aws_dynamodb_table.history

  lifecycle {
    destroy = false
  }
}

resource "aws_elasticache_subnet_group" "main" {
  name       = "${var.project_name}-${var.environment}-redis"
  subnet_ids = aws_subnet.data[*].id
}

resource "aws_security_group" "redis" {
  name        = "${var.project_name}-${var.environment}-redis"
  description = "Redis access only from EKS worker nodes."
  vpc_id      = aws_vpc.main.id

  egress = []
}

resource "aws_elasticache_replication_group" "redis" {
  replication_group_id       = "${var.project_name}-${var.environment}"
  description                = "Motor Desk Redis Streams"
  engine                     = "redis"
  engine_version             = var.redis_engine_version
  node_type                  = var.environment == "prod" ? "cache.t4g.small" : var.redis_node_type
  port                       = 6379
  num_cache_clusters         = var.environment == "prod" ? 2 : 1
  parameter_group_name       = "default.redis7"
  subnet_group_name          = aws_elasticache_subnet_group.main.name
  security_group_ids         = [aws_security_group.redis.id]
  at_rest_encryption_enabled = true
  transit_encryption_enabled = true
  auth_token                 = random_password.redis_auth_token.result
  automatic_failover_enabled = false
  multi_az_enabled           = false
  apply_immediately          = var.apply_database_changes_immediately
  snapshot_retention_limit   = var.backup_retention_days
  snapshot_window            = "02:00-03:00"
  maintenance_window         = "sun:05:00-sun:06:00"

  lifecycle {
    prevent_destroy = false
  }
}
