# VPC (default_tags handles base tags)
resource "aws_vpc" "main" {
  cidr_block           = var.vpc_cidr
  enable_dns_hostnames = true
  enable_dns_support   = true
  # tags = local.full_tags  ← REMOVED (use default_tags)
}

# Internet Gateway
resource "aws_internet_gateway" "main" {
  vpc_id = aws_vpc.main.id
  
  tags = {
    Name = "${local.vpc_name_prefix}-igw"
  }
}

# Public Subnets (ALB/NAT)
resource "aws_subnet" "public" {
  count                   = var.az_count
  vpc_id                  = aws_vpc.main.id
  cidr_block              = var.public_subnet_cidrs[count.index]
  availability_zone       = local.azs[count.index]
  map_public_ip_on_launch = true

  tags = {
    Name = "${local.vpc_name_prefix}-public-${count.index + 1}"
    Type = "public"
  }
}

# Private Blue (EKS Blue)
resource "aws_subnet" "private_blue" {
  count             = var.az_count
  vpc_id            = aws_vpc.main.id
  cidr_block        = var.private_blue_subnet_cidrs[count.index]
  availability_zone = local.azs[count.index]

  tags = {
    Name       = "${local.vpc_name_prefix}-private-blue-${count.index + 1}"
    Type       = "private"
    ClusterEnv = "blue"
  }
}

# Private Green (EKS Green)
resource "aws_subnet" "private_green" {
  count             = var.az_count
  vpc_id            = aws_vpc.main.id
  cidr_block        = var.private_green_subnet_cidrs[count.index]
  availability_zone = local.azs[count.index]

  tags = {
    Name       = "${local.vpc_name_prefix}-private-green-${count.index + 1}"
    Type       = "private"
    ClusterEnv = "green"
  }
}

# Data Subnets (RDS/Redis)
resource "aws_subnet" "data" {
  count             = var.az_count
  vpc_id            = aws_vpc.main.id
  cidr_block        = var.data_subnet_cidrs[count.index]
  availability_zone = local.azs[count.index]

  tags = {
    Name = "${local.vpc_name_prefix}-data-${count.index + 1}"
    Type = "data"
  }
}

# EIPs (default_tags auto-applied)
resource "aws_eip" "nat" {
  count  = var.az_count
  domain = "vpc"

  tags = {
    Name = "${local.vpc_name_prefix}-nat-eip-${count.index + 1}"
  }

  depends_on = [aws_internet_gateway.main]
}

# NAT Gateways
resource "aws_nat_gateway" "main" {
  count         = var.az_count
  allocation_id = aws_eip.nat[count.index].id
  subnet_id     = aws_subnet.public[count.index].id

  tags = {
    Name = "${local.vpc_name_prefix}-nat-${count.index + 1}"
  }

  depends_on = [aws_internet_gateway.main]
}

# Public Route Table
resource "aws_route_table" "public" {
  vpc_id = aws_vpc.main.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.main.id
  }

  tags = {
    Name = "${local.vpc_name_prefix}-public-rt"
  }
}

resource "aws_route_table_association" "public" {
  count          = var.az_count
  subnet_id      = aws_subnet.public[count.index].id
  route_table_id = aws_route_table.public.id
}

# Private Blue Route Tables (NAT per AZ)
resource "aws_route_table" "private_blue" {
  count  = var.az_count
  vpc_id = aws_vpc.main.id

  route {
    cidr_block     = "0.0.0.0/0"
    nat_gateway_id = aws_nat_gateway.main[count.index].id
  }

  tags = {
    Name = "${local.vpc_name_prefix}-private-blue-rt-${count.index + 1}"
  }
}

resource "aws_route_table_association" "private_blue" {
  count          = var.az_count
  subnet_id      = aws_subnet.private_blue[count.index].id
  route_table_id = aws_route_table.private_blue[count.index].id
}

# Data Route Table (isolated - NO internet)
resource "aws_route_table" "data" {
  vpc_id = aws_vpc.main.id

  tags = {
    Name = "${local.vpc_name_prefix}-data-rt"
  }
}

resource "aws_route_table_association" "data" {
  count          = var.az_count
  subnet_id      = aws_subnet.data[count.index].id
  route_table_id = aws_route_table.data.id
}