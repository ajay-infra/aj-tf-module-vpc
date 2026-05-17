# envs/dev.tfvars — dev workload cluster (blue, az_count=2, standalone or blue_green)

vpc_name            = "ai-platform-dev"
environment         = "dev"
eks_deployment_mode = "blue_green"
az_count            = 2

availability_zones = ["us-east-1a", "us-east-1b"]

eks_blue_cluster_name = "ai-platform-dev-blue"

blue_vpc_cidr             = "10.100.0.0/16"
blue_public_subnet_cidrs  = ["10.100.0.0/27", "10.100.0.32/27"]
blue_private_subnet_cidrs = ["10.100.0.128/25", "10.100.1.0/25"]

data_vpc_cidr     = "10.102.0.0/16"
data_subnet_cidrs = ["10.102.0.0/26", "10.102.0.64/26"]

green_enabled = false
# green_vpc_cidr             = "10.101.0.0/16"
# green_public_subnet_cidrs  = ["10.101.0.0/27", "10.101.0.32/27"]
# green_private_subnet_cidrs = ["10.101.0.128/25", "10.101.1.0/25"]

team        = "infra-core"
cost_center = "infra-2026-q1"
tags = {
  Owner = "ajay"
}
