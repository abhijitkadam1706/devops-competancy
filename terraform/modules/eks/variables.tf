variable "cluster_name" {
  type = string
}

variable "kubernetes_version" {
  type    = string
  default = "1.32"
}

variable "vpc_id" {
  type = string
}

variable "vpc_cidr" {
  type = string
}

variable "private_subnet_ids" {
  type = list(string)
}

variable "desired_nodes" {
  type    = number
  default = 3
}

variable "min_nodes" {
  type    = number
  default = 2
}

variable "max_nodes" {
  type    = number
  default = 8
}

variable "instance_types" {
  type    = list(string)
  default = ["t3.large"]
}

variable "capacity_type" {
  type    = string
  default = "ON_DEMAND"
}

variable "environment" {
  type = string
}
