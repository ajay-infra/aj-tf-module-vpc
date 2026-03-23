variable "name_prefix" {
  type        = string
  description = "Resource name prefix (e.g. myapp-prod)"
}

variable "vpc_cidr" {
  type = string
}

variable "az_count" {
  type = number
}

variable "azs" {
  type = list(string)
}

variable "data_subnet_cidrs" {
  type = list(string)
}

variable "tags" {
  type    = map(string)
  default = {}
}
