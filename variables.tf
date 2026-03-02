# Core
variable "vpc_name" {
  type        = string
  description = "VPC display name → generates consistent naming"
}

variable "aws_region" {
  type    = string
  default = "us-east-1"
}

variable "vpc_cidr" {
  type    = string
}

variable "environment" {
  type    = string
  default = "dev"
}

# Cost/Team (CI/CD overrides)
variable "team" {
  type    = string
  default = "infra-core"
}

variable "cost_center" {
  type    = string
  default = "infra-2026-q1"
}

variable "common_tags" {
  type    = map(string)
  default = {
    Project     = "ai-search"
    ManagedBy   = "Terraform"
    Repository  = "tf-module-vpc"
  }
}

# Subnets (Flexible CIDRs)
variable "az_count" {
  type        = number
  description = "Number of AZs (2-3)"
  default     = 3
  validation {
    condition     = var.az_count >= 2 && var.az_count <= 3
    error_message = "AZ count must be 2-3."
  }
}

variable "availability_zones" {
  type        = list(string)
  description = "Availability zones for subnets"
  default     = ["us-east-1a", "us-east-1b", "us-east-1c"]
  validation {
    condition     = length(var.availability_zones) >= 2 && length(var.availability_zones) <= 3
    error_message = "Must provide 2-3 AZs."
  }
}

variable "public_subnet_cidrs" {
  type    = list(string)
}

variable "private_blue_subnet_cidrs" {
  type    = list(string)
}

variable "private_green_subnet_cidrs" {
  type    = list(string)
}

variable "data_subnet_cidrs" {
  type    = list(string)
}

variable "tags" {
  type    = map(string)
  default = {}
}