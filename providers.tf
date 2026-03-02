terraform {
  required_version = ">= 1.5"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
  
  # Backend configured dynamically by pipelines via -backend-config
  # terraform {
  #   backend "s3" {
  #     bucket         = "tf-state-central-123456789012"
  #     key            = "cust/${local.vpc_id_prefix}/${var.environment}/vpc/terraform.tfstate"
  #     region         = "us-east-1" 
  #     dynamodb_table = "tf-locks-central"
  #     role_arn       = "arn:aws:iam::ACCOUNT_ID:role/GitHubActions-Terraform"
  #   }
  # }
}

# Local dev: AWS_PROFILE=default ~/.aws/credentials
provider "aws" {
  region                          = var.aws_region
  skip_credentials_validation     = true
  skip_metadata_api_check         = true
  skip_requesting_account_id      = true
  skip_region_validation          = true

  default_tags {
    tags = local.full_tags
  }
}

# Pipeline: GitHub OIDC → assume_role (uncomment if needed)
# provider "aws" {
#   region                          = var.aws_region
#   skip_credentials_validation     = true
#   
#   assume_role {
#     role_arn = var.aws_assume_role_arn
#   }
#   
#   default_tags {
#     tags = local.full_tags
#   }
# }

# Debug: Who am I?
#data "aws_caller_identity" "current" {}
#data "aws_region" "current" {}

