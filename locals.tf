locals {
  name_prefix   = "${lower(replace(var.vpc_name, " ", "-"))}-${var.environment}"
  azs           = slice(var.availability_zones, 0, var.az_count)
  is_standalone = var.eks_deployment_mode == "standalone"
  is_blue_green = var.eks_deployment_mode == "blue_green"

  full_tags = merge(var.common_tags, {
    Environment = var.environment
    Team        = var.team
    CostCenter  = var.cost_center
  }, var.tags)
}
