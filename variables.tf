# Core
variable "vpc_name" {
  type        = string
  description = "VPC display name — drives all resource naming"
}

variable "aws_region" {
  type    = string
  default = "us-east-1"
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
    Project    = "ai-search"
    ManagedBy  = "Terraform"
    Repository = "aj-tf-module-vpc"
  }
}

variable "tags" {
  type    = map(string)
  default = {}
}

# Deployment Mode
variable "eks_deployment_mode" {
  type        = string
  description = "standalone = single VPC for in-place EKS upgrades; blue_green = separate blue/green/data VPCs for zero-downtime cluster swap"
  default     = "blue_green"
  validation {
    condition     = contains(["standalone", "blue_green"], var.eks_deployment_mode)
    error_message = "eks_deployment_mode must be 'standalone' or 'blue_green'."
  }
}

# AZ config (shared across modes)
variable "az_count" {
  type        = number
  description = <<-EOT
    Number of Availability Zones to spread subnets across.
      2 = cost-optimised dev/staging  (lower cross-AZ data-transfer costs, relaxed SLO)
      3 = standard HA production       (default — balanced cost vs resilience, 99.9% SLA)
      4 = high-resilience / regulated  (financial, healthcare, strict 99.99% SLA)
    Must match the az_count used in aj-tf-module-eks.
  EOT
  default     = 3
  validation {
    condition     = contains([2, 3, 4], var.az_count)
    error_message = "az_count must be 2, 3, or 4."
  }
}

variable "availability_zones" {
  type        = list(string)
  description = "Availability zones for subnets. Must provide at least az_count entries, ordered consistently."
  default     = ["us-east-1a", "us-east-1b", "us-east-1c", "us-east-1d"]
  validation {
    condition     = length(var.availability_zones) >= 2 && length(var.availability_zones) <= 4
    error_message = "Must provide 2-4 AZs."
  }
}

# ── standalone mode ──────────────────────────────────────────────────────────

variable "eks_cluster_name" {
  type        = string
  description = "EKS cluster name — standalone mode only"
  default     = ""
}

variable "standalone_vpc_cidr" {
  type        = string
  description = "VPC CIDR — standalone mode only"
  default     = ""
}

variable "standalone_public_subnet_cidrs" {
  type        = list(string)
  description = "Public subnet CIDRs — standalone mode only"
  default     = []
}

variable "standalone_private_subnet_cidrs" {
  type        = list(string)
  description = "Private subnet CIDRs — standalone mode only"
  default     = []
}

variable "standalone_data_subnet_cidrs" {
  type        = list(string)
  description = "Data subnet CIDRs — standalone mode only"
  default     = []
}

# ── blue_green mode ──────────────────────────────────────────────────────────

variable "green_enabled" {
  type        = bool
  description = "Provision the green VPC. Set to true when starting a cluster upgrade. False = only blue + data VPCs exist."
  default     = false
}

variable "eks_blue_cluster_name" {
  type        = string
  description = "EKS blue cluster name — blue_green mode only"
  default     = ""
}

variable "eks_green_cluster_name" {
  type        = string
  description = "EKS green cluster name — blue_green mode only"
  default     = ""
}

variable "blue_vpc_cidr" {
  type        = string
  description = "Blue VPC CIDR — blue_green mode only"
  default     = ""
}

variable "blue_public_subnet_cidrs" {
  type        = list(string)
  description = "Blue public subnet CIDRs — blue_green mode only"
  default     = []
}

variable "blue_private_subnet_cidrs" {
  type        = list(string)
  description = "Blue private subnet CIDRs (EKS nodes) — blue_green mode only"
  default     = []
}

variable "green_vpc_cidr" {
  type        = string
  description = "Green VPC CIDR — blue_green mode only, required when green_enabled = true"
  default     = ""
}

variable "green_public_subnet_cidrs" {
  type        = list(string)
  description = "Green public subnet CIDRs — blue_green mode only, required when green_enabled = true"
  default     = []
}

variable "green_private_subnet_cidrs" {
  type        = list(string)
  description = "Green private subnet CIDRs (EKS nodes) — blue_green mode only, required when green_enabled = true"
  default     = []
}

variable "data_vpc_cidr" {
  type        = string
  description = "Shared data VPC CIDR (RDS/Redis) — blue_green mode only"
  default     = ""
}

variable "data_subnet_cidrs" {
  type        = list(string)
  description = "Data subnet CIDRs — blue_green mode only"
  default     = []
}
