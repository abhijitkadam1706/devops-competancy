# =============================================================================
# Global Bootstrap — Version Constraints
# Purpose: Creates S3 backend + DynamoDB lock table (one-time setup)
# NOTE: This module intentionally uses LOCAL state — it cannot bootstrap
#       itself into S3 because the bucket doesn't yet exist.
# =============================================================================

terraform {
  required_version = ">= 1.8.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.50"
    }
  }
}
