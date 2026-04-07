# =============================================================================
# Bootstrap: S3 Bucket + DynamoDB for Terraform Remote State
#
# RUN THIS FIRST, ONCE, before any environment deployments:
#   cd terraform/global
#   terraform init -backend=false
#   terraform apply -target=aws_s3_bucket.terraform_state \
#                   -target=aws_dynamodb_table.terraform_locks
#
# Then copy the backend.tf into each environment/ folder.
# =============================================================================

resource "aws_s3_bucket" "terraform_state" {
  bucket        = "mern-auth-terraform-state-${data.aws_caller_identity.current.account_id}"
  force_destroy = false

  lifecycle {
    prevent_destroy = true
  }

  tags = {
    Name = "mern-auth-terraform-state"
  }
}

# Enable versioning — rollback to any previous state
resource "aws_s3_bucket_versioning" "terraform_state" {
  bucket = aws_s3_bucket.terraform_state.id
  versioning_configuration {
    status = "Enabled"
  }
}

# Enforce AES256 encryption at rest
resource "aws_s3_bucket_server_side_encryption_configuration" "terraform_state" {
  bucket = aws_s3_bucket.terraform_state.id
  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

# Zero-Trust: Block ALL public access
resource "aws_s3_bucket_public_access_block" "terraform_state" {
  bucket                  = aws_s3_bucket.terraform_state.id
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

# Zero-Trust: Only allow HTTPS access
resource "aws_s3_bucket_policy" "terraform_state" {
  bucket = aws_s3_bucket.terraform_state.id
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid       = "DenyNonTLS"
        Effect    = "Deny"
        Principal = "*"
        Action    = "s3:*"
        Resource = [
          aws_s3_bucket.terraform_state.arn,
          "${aws_s3_bucket.terraform_state.arn}/*"
        ]
        Condition = {
          Bool = { "aws:SecureTransport" = "false" }
        }
      }
    ]
  })
}

# DynamoDB for state locking — prevents concurrent applies
resource "aws_dynamodb_table" "terraform_locks" {
  name         = "mern-auth-terraform-locks"
  billing_mode = "PAY_PER_REQUEST"
  hash_key     = "LockID"

  attribute {
    name = "LockID"
    type = "S"
  }

  server_side_encryption {
    enabled = true
  }

  point_in_time_recovery {
    enabled = true
  }

  tags = {
    Name = "mern-auth-terraform-locks"
  }
}

data "aws_caller_identity" "current" {}

# Output actual bucket name for backend.tf configuration
output "state_bucket_name" {
  value       = aws_s3_bucket.terraform_state.bucket
  description = "Use this in each environment's backend.tf"
}

output "dynamodb_table_name" {
  value       = aws_dynamodb_table.terraform_locks.name
  description = "Use this in each environment's backend.tf"
}
