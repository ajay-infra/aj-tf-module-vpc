locals {
  vpc_id_prefix  = lower(replace(replace(var.vpc_name, " ", "-"), "[^a-z0-9-]", ""))
  vpc_name_prefix = "${local.vpc_id_prefix}-${var.environment}"
  azs = slice(var.availability_zones, 0, var.az_count)
  
  full_tags = merge({
    Name        = "${local.vpc_name_prefix}"
    VPCName     = var.vpc_name
    Environment = var.environment
  }, var.tags)
}