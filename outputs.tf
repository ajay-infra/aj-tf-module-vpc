output "eks_deployment_mode" {
  description = "Deployment mode this module is configured for"
  value       = var.eks_deployment_mode
}

output "azs_used" {
  description = "Availability zones used"
  value       = local.azs
}

# ── standalone outputs ───────────────────────────────────────────────────────

output "vpc_id" {
  description = "VPC ID — standalone mode only"
  value       = local.is_standalone ? module.standalone[0].vpc_id : null
}

output "vpc_cidr" {
  description = "VPC CIDR — standalone mode only"
  value       = local.is_standalone ? module.standalone[0].vpc_cidr : null
}

output "igw_id" {
  description = "Internet Gateway ID — standalone mode only"
  value       = local.is_standalone ? module.standalone[0].igw_id : null
}

output "public_subnet_ids" {
  description = "Public subnet IDs — standalone mode only"
  value       = local.is_standalone ? module.standalone[0].public_subnet_ids : []
}

output "private_subnet_ids" {
  description = "Private subnet IDs — standalone mode only"
  value       = local.is_standalone ? module.standalone[0].private_subnet_ids : []
}

output "data_subnet_ids" {
  description = "Data subnet IDs — standalone mode only"
  value       = local.is_standalone ? module.standalone[0].data_subnet_ids : []
}

output "nat_gateway_ids" {
  description = "NAT Gateway IDs — standalone mode only"
  value       = local.is_standalone ? module.standalone[0].nat_gateway_ids : []
}

output "nat_public_ips" {
  description = "NAT Gateway public IPs — standalone mode only"
  value       = local.is_standalone ? module.standalone[0].nat_public_ips : []
}

output "private_route_table_ids" {
  description = "Private route table IDs — standalone mode only"
  value       = local.is_standalone ? module.standalone[0].private_route_table_ids : []
}

output "data_route_table_id" {
  description = "Data route table ID — standalone mode only"
  value       = local.is_standalone ? module.standalone[0].data_route_table_id : null
}

# ── blue VPC outputs ─────────────────────────────────────────────────────────

output "blue_vpc_id" {
  description = "Blue VPC ID — blue_green mode only"
  value       = local.is_blue_green ? module.blue_vpc[0].vpc_id : null
}

output "blue_vpc_cidr" {
  description = "Blue VPC CIDR — blue_green mode only"
  value       = local.is_blue_green ? module.blue_vpc[0].vpc_cidr : null
}

output "blue_igw_id" {
  description = "Blue Internet Gateway ID — blue_green mode only"
  value       = local.is_blue_green ? module.blue_vpc[0].igw_id : null
}

output "blue_public_subnet_ids" {
  description = "Blue public subnet IDs — blue_green mode only"
  value       = local.is_blue_green ? module.blue_vpc[0].public_subnet_ids : []
}

output "blue_private_subnet_ids" {
  description = "Blue private subnet IDs (EKS nodes) — blue_green mode only"
  value       = local.is_blue_green ? module.blue_vpc[0].private_subnet_ids : []
}

output "blue_nat_gateway_ids" {
  description = "Blue NAT Gateway IDs — blue_green mode only"
  value       = local.is_blue_green ? module.blue_vpc[0].nat_gateway_ids : []
}

output "blue_nat_public_ips" {
  description = "Blue NAT Gateway public IPs — blue_green mode only"
  value       = local.is_blue_green ? module.blue_vpc[0].nat_public_ips : []
}

output "blue_private_route_table_ids" {
  description = "Blue private route table IDs — blue_green mode only"
  value       = local.is_blue_green ? module.blue_vpc[0].private_route_table_ids : []
}

output "blue_data_peering_id" {
  description = "Blue ↔ Data VPC peering connection ID"
  value       = local.is_blue_green ? module.blue_data_peering[0].peering_connection_id : null
}

# ── green VPC outputs ────────────────────────────────────────────────────────

output "green_vpc_id" {
  description = "Green VPC ID — populated only when green_enabled = true"
  value       = local.is_blue_green && var.green_enabled ? module.green_vpc[0].vpc_id : null
}

output "green_vpc_cidr" {
  description = "Green VPC CIDR — populated only when green_enabled = true"
  value       = local.is_blue_green && var.green_enabled ? module.green_vpc[0].vpc_cidr : null
}

output "green_igw_id" {
  description = "Green Internet Gateway ID — populated only when green_enabled = true"
  value       = local.is_blue_green && var.green_enabled ? module.green_vpc[0].igw_id : null
}

output "green_public_subnet_ids" {
  description = "Green public subnet IDs — populated only when green_enabled = true"
  value       = local.is_blue_green && var.green_enabled ? module.green_vpc[0].public_subnet_ids : []
}

output "green_private_subnet_ids" {
  description = "Green private subnet IDs (EKS nodes) — populated only when green_enabled = true"
  value       = local.is_blue_green && var.green_enabled ? module.green_vpc[0].private_subnet_ids : []
}

output "green_nat_gateway_ids" {
  description = "Green NAT Gateway IDs — populated only when green_enabled = true"
  value       = local.is_blue_green && var.green_enabled ? module.green_vpc[0].nat_gateway_ids : []
}

output "green_nat_public_ips" {
  description = "Green NAT Gateway public IPs — populated only when green_enabled = true"
  value       = local.is_blue_green && var.green_enabled ? module.green_vpc[0].nat_public_ips : []
}

output "green_private_route_table_ids" {
  description = "Green private route table IDs — populated only when green_enabled = true"
  value       = local.is_blue_green && var.green_enabled ? module.green_vpc[0].private_route_table_ids : []
}

output "green_data_peering_id" {
  description = "Green ↔ Data VPC peering connection ID — populated only when green_enabled = true"
  value       = local.is_blue_green && var.green_enabled ? module.green_data_peering[0].peering_connection_id : null
}

# ── data VPC outputs ─────────────────────────────────────────────────────────

output "data_vpc_id" {
  description = "Shared data VPC ID — blue_green mode only"
  value       = local.is_blue_green ? module.data_vpc[0].vpc_id : null
}

output "data_vpc_cidr" {
  description = "Shared data VPC CIDR — blue_green mode only"
  value       = local.is_blue_green ? module.data_vpc[0].vpc_cidr : null
}

output "data_vpc_subnet_ids" {
  description = "Shared data subnet IDs (RDS/Redis) — blue_green mode only"
  value       = local.is_blue_green ? module.data_vpc[0].data_subnet_ids : []
}

output "data_vpc_route_table_id" {
  description = "Shared data VPC route table ID — blue_green mode only"
  value       = local.is_blue_green ? module.data_vpc[0].data_route_table_id : null
}
