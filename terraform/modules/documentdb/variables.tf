variable "cluster_identifier" {
  description = "Unique identifier for the DocumentDB cluster"
  type        = string
}

variable "vpc_id" {
  description = "VPC ID where DocumentDB will be deployed"
  type        = string
}

variable "database_subnet_ids" {
  description = "List of isolated database subnet IDs for DocumentDB"
  type        = list(string)
}

variable "eks_node_security_group_id" {
  description = "Security group ID of EKS nodes — only source allowed to connect to DocumentDB"
  type        = string
}

variable "master_username" {
  description = "Master username for the DocumentDB cluster"
  type        = string
  default     = "mernadmin"
}

variable "database_name" {
  description = "Initial database name inside DocumentDB"
  type        = string
  default     = "mernauth"
}

variable "instance_class" {
  description = "DocumentDB instance type (e.g. db.t3.medium, db.r6g.large)"
  type        = string
  default     = "db.t3.medium"
}

variable "instance_count" {
  description = "Number of DocumentDB instances (1 for dev/staging, 3 for production)"
  type        = number
  default     = 3
}

variable "backup_retention_days" {
  description = "Number of days to retain automated backups"
  type        = number
  default     = 7
}

variable "deletion_protection" {
  description = "Prevent accidental deletion (true for production, false for dev/staging)"
  type        = bool
  default     = true
}

variable "environment" {
  description = "Deployment environment (dev/staging/production)"
  type        = string
}
