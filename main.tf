# ── standalone mode ──────────────────────────────────────────────────────────
# Single VPC: public + private + data subnets. In-place EKS upgrades only.

module "standalone" {
  count  = local.is_standalone ? 1 : 0
  source = "./modules/vpc-standalone"

  name_prefix          = local.name_prefix
  vpc_cidr             = var.standalone_vpc_cidr
  az_count             = var.az_count
  azs                  = local.azs
  public_subnet_cidrs  = var.standalone_public_subnet_cidrs
  private_subnet_cidrs = var.standalone_private_subnet_cidrs
  data_subnet_cidrs    = var.standalone_data_subnet_cidrs
  eks_cluster_name     = var.eks_cluster_name
}

# ── blue_green mode ──────────────────────────────────────────────────────────
# Three separate VPCs: blue cluster, green cluster (on demand), shared data.
# Blue and green are isolated; both peer to the shared data VPC.

module "blue_vpc" {
  count  = local.is_blue_green ? 1 : 0
  source = "./modules/vpc-cluster"

  name_prefix          = local.name_prefix
  color                = "blue"
  vpc_cidr             = var.blue_vpc_cidr
  az_count             = var.az_count
  azs                  = local.azs
  public_subnet_cidrs  = var.blue_public_subnet_cidrs
  private_subnet_cidrs = var.blue_private_subnet_cidrs
  eks_cluster_name     = var.eks_blue_cluster_name
}

# Green VPC — provisioned only when green_enabled = true (i.e. during an upgrade)
module "green_vpc" {
  count  = local.is_blue_green && var.green_enabled ? 1 : 0
  source = "./modules/vpc-cluster"

  name_prefix          = local.name_prefix
  color                = "green"
  vpc_cidr             = var.green_vpc_cidr
  az_count             = var.az_count
  azs                  = local.azs
  public_subnet_cidrs  = var.green_public_subnet_cidrs
  private_subnet_cidrs = var.green_private_subnet_cidrs
  eks_cluster_name     = var.eks_green_cluster_name
}

# Shared data VPC — RDS/Redis, no internet, peered to cluster VPCs
module "data_vpc" {
  count  = local.is_blue_green ? 1 : 0
  source = "./modules/vpc-data"

  name_prefix       = local.name_prefix
  vpc_cidr          = var.data_vpc_cidr
  az_count          = var.az_count
  azs               = local.azs
  data_subnet_cidrs = var.data_subnet_cidrs
}

# Blue ↔ Data peering (always present in blue_green mode)
module "blue_data_peering" {
  count  = local.is_blue_green ? 1 : 0
  source = "./modules/vpc-peering"

  name_prefix                       = "${local.name_prefix}-blue-data"
  requester_vpc_id                  = module.blue_vpc[0].vpc_id
  requester_vpc_cidr                = var.blue_vpc_cidr
  requester_private_route_table_ids = module.blue_vpc[0].private_route_table_ids
  accepter_vpc_id                   = module.data_vpc[0].vpc_id
  accepter_vpc_cidr                 = var.data_vpc_cidr
  accepter_route_table_id           = module.data_vpc[0].data_route_table_id
}

# Green ↔ Data peering (only when green VPC is provisioned)
module "green_data_peering" {
  count  = local.is_blue_green && var.green_enabled ? 1 : 0
  source = "./modules/vpc-peering"

  name_prefix                       = "${local.name_prefix}-green-data"
  requester_vpc_id                  = module.green_vpc[0].vpc_id
  requester_vpc_cidr                = var.green_vpc_cidr
  requester_private_route_table_ids = module.green_vpc[0].private_route_table_ids
  accepter_vpc_id                   = module.data_vpc[0].vpc_id
  accepter_vpc_cidr                 = var.data_vpc_cidr
  accepter_route_table_id           = module.data_vpc[0].data_route_table_id
}
