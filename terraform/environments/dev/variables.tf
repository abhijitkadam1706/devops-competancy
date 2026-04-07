variable "vpc_cidr" {
  description = "CIDR block for the dev VPC"
  type        = string
  default     = "10.2.0.0/16"
}

variable "kubernetes_version" {
  description = "Kubernetes version for the EKS cluster"
  type        = string
  default     = "1.32"
}

variable "ecr_repository_arns" {
  description = "List of ECR repository ARNs"
  type        = list(string)
  default     = []
}
