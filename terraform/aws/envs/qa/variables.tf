variable "aws_region" {
  description = "AWS region for the QA environment."
  type        = string
  default     = "us-east-2"
}

variable "terraform_state_bucket" {
  description = "S3 bucket used to store AWS and Kubernetes Terraform state."
  type        = string
}

variable "ses_from_address" {
  description = "Sender identity verified in Amazon SES."
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

variable "mongo_database" {
  type    = string
  default = "motordesk"
}

variable "mongo_options" {
  type    = string
  default = ""
}
