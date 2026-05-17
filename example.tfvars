# example.tfvars — CI dry-run plan (no real AWS credentials required)
# providers.tf skips credential/region validation so plan works in CI without a role

vpc_name            = "example"
environment         = "dev"
eks_deployment_mode = "blue_green"
az_count            = 2

eks_blue_cluster_name = "example-dev-blue"

blue_vpc_cidr             = "10.100.0.0/16"
blue_public_subnet_cidrs  = ["10.100.0.0/27",   "10.100.0.32/27"]
blue_private_subnet_cidrs = ["10.100.0.128/25",  "10.100.1.0/25"]

data_vpc_cidr     = "10.102.0.0/16"
data_subnet_cidrs = ["10.102.0.0/26", "10.102.0.64/26"]

green_enabled = false
