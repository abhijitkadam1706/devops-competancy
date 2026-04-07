variable "vpc_cidr" {
  description = "CIDR block for the VPC (e.g. 10.0.0.0/16 for production)"
  type        = string
  default     = "10.0.0.0/16"
}

variable "kubernetes_version" {
  description = "Kubernetes version for the EKS cluster"
  type        = string
  default     = "1.32"
}

variable "desired_nodes" {
  description = "Default number of EKS worker nodes"
  type        = number
  default     = 3
}

variable "min_nodes" {
  description = "Minimum number of EKS worker nodes"
  type        = number
  default     = 3
}

variable "max_nodes" {
  description = "Maximum number of EKS worker nodes (used by autoscaler)"
  type        = number
  default     = 10
}

variable "instance_types" {
  description = "EC2 instance types for EKS worker nodes"
  type        = list(string)
  default     = ["t3.large"]
}

variable "docdb_instance_class" {
  description = "DocumentDB instance class"
  type        = string
  default     = "db.r6g.large"
}

variable "domain_name" {
  description = "Your custom domain (e.g. mern-auth.example.com). Set to empty string if you don't have one."
  type        = string
  default     = ""
}

variable "alert_email" {
  description = "Email for CloudWatch alarm alerts. Leave empty to skip."
  type        = string
  default     = ""
}

variable "ecr_repository_arns" {
  description = "List of ECR repository ARNs. Leave as empty list — they are created by this environment and passed back."
  type        = list(string)
  default     = []
}
