variable "aws_region" {
  description = "AWS region for application infrastructure."
  type        = string
  default     = "us-east-2"
}

variable "project_name" {
  type    = string
  default = "motordesk"
}

variable "environment" {
  type    = string
  default = "dev"

  validation {
    condition     = contains(["dev-cli", "qa", "prod"], var.environment)
    error_message = "environment must be dev, qa, or prod."
  }
}

variable "terraform_state_bucket" {
  description = "S3 state bucket used by the environment-specific Kubernetes Terraform roots."
  type        = string
}

variable "terraform_state_prefix" {
  description = "Prefix of the environment-specific Terraform state objects."
  type        = string
}

variable "vpc_cidr" {
  type    = string
  default = "10.40.0.0/16"
}

variable "public_subnet_cidrs" {
  type    = list(string)
  default = ["10.40.0.0/24", "10.40.1.0/24"]
}

variable "app_subnet_cidrs" {
  type    = list(string)
  default = ["10.40.10.0/24", "10.40.11.0/24"]
}

variable "data_subnet_cidrs" {
  type    = list(string)
  default = ["10.40.20.0/24", "10.40.21.0/24"]
}

variable "postgres_instance_class" {
  type    = string
  default = "db.t4g.micro"
}

variable "postgres_admin_username" {
  type    = string
  default = "motordesk_admin"
}

variable "postgres_database_name" {
  type    = string
  default = "motordesk"
}

variable "mongo_database" {
  type    = string
  default = "motordesk"
}

variable "mongo_options" {
  description = "Optional MongoDB connection options, for example tls=true."
  type        = string
  default     = ""
}

variable "redis_engine_version" {
  type    = string
  default = "7.1"
}

variable "redis_node_type" {
  type    = string
  default = "cache.t4g.micro"
}

variable "backup_retention_days" {
  type    = number
  default = 7
}

variable "apply_database_changes_immediately" {
  type    = bool
  default = false
}

variable "eks_kubernetes_version" {
  description = "Kubernetes minor version for the EKS cluster. Upgrade the control plane and managed node group deliberately."
  type        = string
  default     = "1.35"
}

variable "ses_from_address" {
  description = "Email identity verified in Amazon SES for this AWS account and region."
  type        = string
}

variable "api_domain_name" {
  description = "Optional DNS name used for the API and its ACM certificate."
  type        = string
  default     = ""
}

variable "route53_zone_id" {
  description = "Optional Route 53 hosted zone ID for API certificate validation and DNS management."
  type        = string
  default     = ""
}

variable "jwt_issuer" {
  type    = string
  default = "motordesk"
}

variable "jwt_audience" {
  type    = string
  default = "motordesk"
}

variable "jwt_realm" {
  type    = string
  default = "motordesk"
}
