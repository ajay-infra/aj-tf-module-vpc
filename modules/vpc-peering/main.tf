# VPC Peering — same account, same region (auto_accept = true)
# Used to connect blue or green cluster VPC to the shared data VPC
resource "aws_vpc_peering_connection" "this" {
  vpc_id      = var.requester_vpc_id
  peer_vpc_id = var.accepter_vpc_id
  auto_accept = true

  tags = merge(var.tags, {
    Name = "${var.name_prefix}-peering"
  })
}

# Routes in requester (cluster) private route tables → data VPC CIDR
resource "aws_route" "requester_to_accepter" {
  count                     = length(var.requester_private_route_table_ids)
  route_table_id            = var.requester_private_route_table_ids[count.index]
  destination_cidr_block    = var.accepter_vpc_cidr
  vpc_peering_connection_id = aws_vpc_peering_connection.this.id
}

# Route in accepter (data) route table → cluster VPC CIDR
resource "aws_route" "accepter_to_requester" {
  route_table_id            = var.accepter_route_table_id
  destination_cidr_block    = var.requester_vpc_cidr
  vpc_peering_connection_id = aws_vpc_peering_connection.this.id
}
