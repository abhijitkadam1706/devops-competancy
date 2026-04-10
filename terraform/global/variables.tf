# =============================================================================
# Global Bootstrap — Variables
# All configurable values are declared here; defaults are sane but overridable.
# =============================================================================

variable "aws_region" {
  description = "AWS region for the remote state bucket and DynamoDB table"
  type        = string
  default     = "ap-southeast-1"
}

variable "project_name" {
  description = "Short project name used to name all bootstrap resources"
  type        = string
  default     = "mern-auth"
}

variable "environment" {
  description = "Logical environment label (used in tags)"
  type        = string
  default     = "production"
}

variable "state_bucket_force_destroy" {
  description = "Allow Terraform to destroy the state bucket even if it has objects (set true only in dev)"
  type        = bool
  default     = false
}
