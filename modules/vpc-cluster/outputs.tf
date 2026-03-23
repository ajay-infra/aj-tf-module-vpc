output "vpc_id" {
  value = aws_vpc.main.id
}

output "vpc_cidr" {
  value = aws_vpc.main.cidr_block
}

output "igw_id" {
  value = aws_internet_gateway.main.id
}

output "public_subnet_ids" {
  value = aws_subnet.public[*].id
}

output "private_subnet_ids" {
  value = aws_subnet.private[*].id
}

output "nat_gateway_ids" {
  value = aws_nat_gateway.main[*].id
}

output "nat_public_ips" {
  value = aws_eip.nat[*].public_ip
}

output "private_route_table_ids" {
  value = aws_route_table.private[*].id
}
