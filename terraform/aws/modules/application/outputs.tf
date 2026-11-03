output "api_url" {
  value = var.api_domain_name == "" ? "" : "https://${var.api_domain_name}"
}

output "api_domain_name" {
  value = var.api_domain_name
}

output "api_waf_web_acl_arn" {
  value = aws_wafv2_web_acl.api.arn
}

output "api_certificate_arn" {
  value = var.api_domain_name == "" ? "" : aws_acm_certificate_validation.api[0].certificate_arn
}

output "certificate_validation_records" {
  value = var.api_domain_name == "" ? {} : {
    for option in aws_acm_certificate.api[0].domain_validation_options :
    option.domain_name => {
      name  = option.resource_record_name
      type  = option.resource_record_type
      value = option.resource_record_value
    }
  }
}

output "ecr_repository_url" {
  value = aws_ecr_repository.api.repository_url
}

output "efs_file_system_id" {
  value = aws_efs_file_system.mongo.id
}

output "efs_access_point_id" {
  value = aws_efs_access_point.mongo.id
}

output "eks_cluster_name" {
  value = aws_eks_cluster.main.name
}

output "eks_cluster_version" {
  value = aws_eks_cluster.main.version
}

output "eks_vpc_id" {
  value = aws_vpc.main.id
}

output "github_deploy_user_name" {
  value = aws_iam_user.github_deploy.name
}

output "postgres_endpoint" {
  value = aws_db_instance.postgres.address
}

output "postgres_database_name" {
  value = var.postgres_database_name
}

output "postgres_admin_username" {
  value = var.postgres_admin_username
}

output "postgres_secret_arn" {
  value = aws_db_instance.postgres.master_user_secret[0].secret_arn
}

output "redis_endpoint" {
  value = aws_elasticache_replication_group.redis.primary_endpoint_address
}

output "redis_auth_token_secret_arn" {
  value = aws_secretsmanager_secret.redis_auth_token.arn
}

output "jwt_secret_arn" {
  value = aws_secretsmanager_secret.jwt_secret.arn
}

output "mongo_credentials_secret_arn" {
  value = aws_secretsmanager_secret.mongo_credentials.arn
}

output "mongo_database_name" {
  value = var.mongo_database
}

output "mongo_options" {
  value = var.mongo_options
}

output "parameter_store_prefix" {
  value = "/${var.project_name}/${var.environment}"
}

output "aws_region" {
  value = var.aws_region
}

output "environment" {
  value = var.environment
}

output "ses_identity_verification_status" {
  value = aws_sesv2_email_identity.sender.verified_for_sending_status
}
