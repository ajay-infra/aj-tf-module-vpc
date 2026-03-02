output "vpc_id" {
  description = "VPC ID"
  value       = aws_vpc.main.id
}

output "public_subnet_ids" {
  description = "Public subnet IDs (ALB/NAT)"
  value       = aws_subnet.public[*].id
}

output "private_blue_subnet_ids" {
  description = "Private Blue subnet IDs (EKS Blue)"
  value       = aws_subnet.private_blue[*].id
}

output "private_green_subnet_ids" {
  description = "Private Green subnet IDs (EKS Green)"
  value       = aws_subnet.private_green[*].id
}

output "data_subnet_ids" {
  description = "Data subnet IDs (RDS/Redis)"
  value       = aws_subnet.data[*].id
}

output "nat_public_ips" {
  description = "NAT Gateway public IPs"
  value       = aws_eip.nat[*].public_ip
}