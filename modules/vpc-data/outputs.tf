output "vpc_id" {
  value = aws_vpc.main.id
}

output "vpc_cidr" {
  value = aws_vpc.main.cidr_block
}

output "data_subnet_ids" {
  value = aws_subnet.data[*].id
}

output "data_route_table_id" {
  value = aws_route_table.data.id
}
