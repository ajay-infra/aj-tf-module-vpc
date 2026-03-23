# Shared Data VPC — RDS/Redis, no internet access
# Peered to blue and (optionally) green cluster VPCs via vpc-peering module
resource "aws_vpc" "main" {
  cidr_block           = var.vpc_cidr
  enable_dns_hostnames = true
  enable_dns_support   = true

  tags = { Name = "${var.name_prefix}-data-vpc" }
}

# Data Subnets (internet-isolated)
resource "aws_subnet" "data" {
  count             = var.az_count
  vpc_id            = aws_vpc.main.id
  cidr_block        = var.data_subnet_cidrs[count.index]
  availability_zone = var.azs[count.index]

  tags = merge(var.tags, {
    Name = "${var.name_prefix}-data-${count.index + 1}"
    Type = "data"
  })
}

# Route Table — local only, no internet route
# Peering routes are injected by the vpc-peering module
resource "aws_route_table" "data" {
  vpc_id = aws_vpc.main.id

  tags = { Name = "${var.name_prefix}-data-rt" }
}

resource "aws_route_table_association" "data" {
  count          = var.az_count
  subnet_id      = aws_subnet.data[count.index].id
  route_table_id = aws_route_table.data.id
}
