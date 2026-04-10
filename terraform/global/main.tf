# =============================================================================
# Global Bootstrap — Main
#
# PURPOSE: One-time setup that must be run BEFORE any environment.
# Creates:
#   - S3 bucket for Terraform remote state (versioned, encrypted, private)
#   - DynamoDB table for state locking (prevents concurrent applies)
#
# HOW TO RUN:
#   cd terraform/global
#   terraform init           # Uses local state for this module only
#   terraform apply -var-file="terraform.tfvars.example"
#
# IMPORTANT: This module intentionally uses LOCAL state (no backend block).
#   The S3 bucket it creates is used by all other environment modules.
# =============================================================================

provider "aws" {
  region = var.aws_region

  default_tags {
    tags = {
      Project     = var.project_name
      ManagedBy   = "Terraform"
      Environment = "global"
    }
  }
}

# ---------------------------------------------------------------------------
# Data Sources
# ---------------------------------------------------------------------------

data "aws_caller_identity" "current" {}

# ---------------------------------------------------------------------------
# Locals
# ---------------------------------------------------------------------------

locals {
  # Unique bucket name includes account ID to prevent global collisions
  state_bucket_name = "${var.project_name}-terraform-state-${data.aws_caller_identity.current.account_id}"
  lock_table_name   = "${var.project_name}-terraform-locks"
}

# ---------------------------------------------------------------------------
# S3 Bucket — Remote State
# ---------------------------------------------------------------------------

resource "aws_s3_bucket" "terraform_state" {
  bucket        = local.state_bucket_name
  force_destroy = var.state_bucket_force_destroy

  tags = { Name = local.state_bucket_name }
}

resource "aws_s3_bucket_versioning" "terraform_state" {
  bucket = aws_s3_bucket.terraform_state.id
  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "terraform_state" {
  bucket = aws_s3_bucket.terraform_state.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "aws:kms"
    }
    bucket_key_enabled = true
  }
}

resource "aws_s3_bucket_public_access_block" "terraform_state" {
  bucket                  = aws_s3_bucket.terraform_state.id
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_s3_bucket_lifecycle_configuration" "terraform_state" {
  bucket = aws_s3_bucket.terraform_state.id

  rule {
    id     = "expire-old-noncurrent-versions"
    status = "Enabled"

    noncurrent_version_expiration {
      noncurrent_days = 90
    }

    abort_incomplete_multipart_upload {
      days_after_initiation = 7
    }
  }
}

# ---------------------------------------------------------------------------
# DynamoDB Table — State Locking
# ---------------------------------------------------------------------------

resource "aws_dynamodb_table" "terraform_locks" {
  name         = local.lock_table_name
  billing_mode = "PAY_PER_REQUEST"
  hash_key     = "LockID"

  attribute {
    name = "LockID"
    type = "S"
  }

  point_in_time_recovery {
    enabled = true
  }

  tags = { Name = local.lock_table_name }
}
