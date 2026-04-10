# =============================================================================
# Monitoring Module — Variables (Updated)
# =============================================================================

variable "cluster_name" {
  description = "EKS cluster name — used in resource naming"
  type        = string
}

variable "environment" {
  description = "Deployment environment label"
  type        = string
}

variable "alert_email" {
  description = "Email address for CloudWatch alarm SNS notifications"
  type        = string
  default     = ""
}

variable "docdb_cluster_id" {
  description = "DocumentDB cluster identifier for CloudWatch alarm dimensions"
  type        = string
}

variable "prometheus_chart_version" {
  description = "Pinned version of the kube-prometheus-stack Helm chart"
  type        = string
  default     = "61.3.2"
}
