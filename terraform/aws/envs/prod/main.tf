terraform {
  required_version = ">= 1.10.0"

  backend "s3" {
    key          = "motordesk/prod/terraform.tfstate"
    encrypt      = true
    use_lockfile = true
  }

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

provider "aws" {
  region = var.aws_region

  default_tags {
    tags = {
      Project     = "motordesk"
      Environment = "prod"
      ManagedBy   = "terraform"
    }
  }
}

module "application" {
  source = "../../modules/application"

  environment            = "prod"
  aws_region             = var.aws_region
  terraform_state_bucket = var.terraform_state_bucket
  terraform_state_prefix = "prod"
  ses_from_address       = var.ses_from_address
  api_domain_name        = var.api_domain_name
  route53_zone_id        = var.route53_zone_id
  mongo_database         = var.mongo_database
  mongo_options          = var.mongo_options
}
