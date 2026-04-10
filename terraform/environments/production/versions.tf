# =============================================================================
# Production Environment — Version Constraints
# =============================================================================

terraform {
  required_version = ">= 1.8.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.50"
    }
    helm = {
      source  = "hashicorp/helm"
      version = "~> 2.13"
    }
    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = "~> 2.30"
    }
    kubectl = {
      source  = "gavinbunney/kubectl"
      version = "~> 1.14"
    }
    tls = {
      source  = "hashicorp/tls"
      version = "~> 4.0"
    }
    null = {
      source  = "hashicorp/null"
      version = "~> 3.0"
    }
  }

  backend "s3" {
    # Values here cannot use variables — they are set at `terraform init` time.
    # After running terraform/global, copy the bucket name and region here.
    # OR use: terraform init -backend-config="bucket=<name>" etc.
    bucket         = "mern-auth-terraform-state-203848753188"
    key            = "production/terraform.tfstate"
    region         = "ap-southeast-1"
    dynamodb_table = "mern-auth-terraform-locks"
    encrypt        = true
  }
}
