variable "vpc_cidr" {
  description = "CIDR block for the staging VPC"
  type        = string
  default     = "10.1.0.0/16"
}

variable "kubernetes_version" {
  description = "Kubernetes version for the EKS cluster"
  type        = string
  default     = "1.32"
}

variable "desired_nodes" {
  description = "Default number of EKS worker nodes"
  type        = number
  default     = 2
}

variable "min_nodes" {
  description = "Minimum number of EKS worker nodes"
  type        = number
  default     = 1
}

variable "max_nodes" {
  description = "Maximum number of EKS worker nodes"
  type        = number
  default     = 5
}

variable "instance_types" {
  description = "EC2 instance types for EKS worker nodes"
  type        = list(string)
  default     = ["t3.medium"]
}

variable "docdb_instance_class" {
  description = "DocumentDB instance class"
  type        = string
  default     = "db.t3.medium"
}

variable "base_domain" {
  description = "Base domain name. Leave empty string if you don't have one."
  type        = string
  default     = ""
}

variable "alert_email" {
  description = "Email for CloudWatch alarm alerts. Leave empty to skip."
  type        = string
  default     = ""
}

variable "ecr_repository_arns" {
  description = "List of ECR repository ARNs"
  type        = list(string)
  default     = []
}
