variable "aws_region" {
  description = "AWS region used for the Terraform state bucket."
  type        = string
  default     = "us-east-2"
}

variable "state_bucket_name" {
  description = "Globally unique S3 bucket name for encrypted, versioned Terraform state."
  type        = string
}
