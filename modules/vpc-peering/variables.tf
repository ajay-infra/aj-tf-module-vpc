variable "name_prefix" {
  type        = string
  description = "Resource name prefix for the peering connection"
}

variable "requester_vpc_id" {
  type = string
}

variable "requester_vpc_cidr" {
  type = string
}

variable "requester_private_route_table_ids" {
  type        = list(string)
  description = "Private route table IDs in the requester VPC to add data VPC routes to"
}

variable "accepter_vpc_id" {
  type = string
}

variable "accepter_vpc_cidr" {
  type = string
}

variable "accepter_route_table_id" {
  type        = string
  description = "Route table ID in the accepter (data) VPC to add requester VPC routes to"
}

variable "tags" {
  type    = map(string)
  default = {}
}
