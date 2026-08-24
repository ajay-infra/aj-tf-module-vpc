# envs/staging.tfvars — staging workload cluster (blue, az_count=2)

vpc_name            = "ai-search-staging"
environment         = "staging"
eks_deployment_mode = "blue_green"
az_count            = 2

availability_zones = ["us-east-1a", "us-east-1b"]

eks_blue_cluster_name = "ai-search-staging-blue"

blue_vpc_cidr             = "10.110.0.0/16"
blue_public_subnet_cidrs  = ["10.110.0.0/27", "10.110.0.32/27"]
blue_private_subnet_cidrs = ["10.110.0.128/25", "10.110.1.0/25"]

data_vpc_cidr     = "10.112.0.0/16"
data_subnet_cidrs = ["10.112.0.0/26", "10.112.0.64/26"]

green_enabled = false

team        = "infra-core"
cost_center = "infra-2026-q1"
tags = {
  Owner = "ajay"
}
