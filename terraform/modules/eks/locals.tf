# =============================================================================
# EKS Module — Locals
# =============================================================================

locals {
  # Common tag set applied to all EKS-related resources
  common_tags = {
    Cluster     = var.cluster_name
    Environment = var.environment
    ManagedBy   = "Terraform"
  }
}
