output "api_url" {
  value = module.application.api_url
}

output "certificate_validation_records" {
  value = module.application.certificate_validation_records
}

output "ecr_repository_url" {
  value = module.application.ecr_repository_url
}

output "efs_file_system_id" {
  value = module.application.efs_file_system_id
}

output "efs_access_point_id" {
  value = module.application.efs_access_point_id
}

output "eks_cluster_name" {
  value = module.application.eks_cluster_name
}

output "eks_cluster_version" {
  value = module.application.eks_cluster_version
}

output "api_certificate_arn" {
  value = module.application.api_certificate_arn
}

output "api_domain_name" {
  value = module.application.api_domain_name
}

output "api_waf_web_acl_arn" {
  value = module.application.api_waf_web_acl_arn
}

output "eks_vpc_id" {
  value = module.application.eks_vpc_id
}

output "mongo_credentials_secret_arn" {
  value = module.application.mongo_credentials_secret_arn
}

output "mongo_database_name" {
  value = module.application.mongo_database_name
}

output "mongo_options" {
  value = module.application.mongo_options
}

output "parameter_store_prefix" {
  value = module.application.parameter_store_prefix
}

output "postgres_endpoint" {
  value = module.application.postgres_endpoint
}

output "postgres_database_name" {
  value = module.application.postgres_database_name
}

output "postgres_admin_username" {
  value = module.application.postgres_admin_username
}

output "postgres_secret_arn" {
  value = module.application.postgres_secret_arn
}

output "redis_endpoint" {
  value = module.application.redis_endpoint
}

output "redis_auth_token_secret_arn" {
  value = module.application.redis_auth_token_secret_arn
}

output "jwt_secret_arn" {
  value = module.application.jwt_secret_arn
}

output "aws_region" {
  value = module.application.aws_region
}

output "environment" {
  value = module.application.environment
}

output "github_deploy_user_name" {
  value = module.application.github_deploy_user_name
}

output "ses_identity_verification_status" {
  value = module.application.ses_identity_verification_status
}
