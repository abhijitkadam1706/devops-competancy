variable "cluster_name" {
  description = "Name prefix for all monitoring resources"
  type        = string
}

variable "environment" {
  description = "Deployment environment (dev/staging/production)"
  type        = string
}

variable "alert_email" {
  description = "Email address for CloudWatch alarm notifications. Leave empty to skip SNS email subscription."
  type        = string
  default     = ""
}

variable "docdb_cluster_id" {
  description = "DocumentDB cluster identifier for database-specific CloudWatch alarms"
  type        = string
}
