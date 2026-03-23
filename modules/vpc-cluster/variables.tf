variable "name_prefix" {
  type        = string
  description = "Resource name prefix (e.g. myapp-prod)"
}

variable "color" {
  type        = string
  description = "Cluster color: 'blue' or 'green'"
  validation {
    condition     = contains(["blue", "green"], var.color)
    error_message = "color must be 'blue' or 'green'."
  }
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

variable "public_subnet_cidrs" {
  type = list(string)
}

variable "private_subnet_cidrs" {
  type = list(string)
}

variable "eks_cluster_name" {
  type        = string
  description = "EKS cluster name for kubernetes.io/cluster/ subnet tags"
  default     = ""
}

variable "tags" {
  type    = map(string)
  default = {}
}
