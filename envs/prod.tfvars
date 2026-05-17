# envs/prod.tfvars — prod workload cluster (blue, az_count=3)

vpc_name            = "ai-platform-prod"
environment         = "prod"
eks_deployment_mode = "blue_green"
az_count            = 3

availability_zones = ["us-east-1a", "us-east-1b", "us-east-1c"]

eks_blue_cluster_name = "ai-platform-prod-blue"

blue_vpc_cidr             = "10.120.0.0/16"
blue_public_subnet_cidrs  = ["10.120.0.0/27", "10.120.0.32/27", "10.120.0.64/27"]
blue_private_subnet_cidrs = ["10.120.0.128/25", "10.120.1.0/25", "10.120.1.128/25"]

data_vpc_cidr     = "10.122.0.0/16"
data_subnet_cidrs = ["10.122.0.0/26", "10.122.0.64/26", "10.122.0.128/26"]

green_enabled = false
# Flip to true + add green_* CIDRs during a K8s upgrade window
# green_vpc_cidr             = "10.121.0.0/16"
# green_public_subnet_cidrs  = ["10.121.0.0/27", "10.121.0.32/27", "10.121.0.64/27"]
# green_private_subnet_cidrs = ["10.121.0.128/25", "10.121.1.0/25", "10.121.1.128/25"]

team        = "infra-core"
cost_center = "infra-2026-q1"
tags = {
  Owner       = "ajay"
  Environment = "prod"
}
