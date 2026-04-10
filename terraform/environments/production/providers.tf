# =============================================================================
# Production Environment — Providers
#
# AWS provider:        region from variable, account from data source
# Helm provider:       authenticated against EKS via cluster token
# Kubernetes provider: authenticated against EKS via cluster token
# Kubectl provider:    authenticated against EKS via cluster token
#
# NOTE: Helm/Kubernetes/Kubectl providers are configured HERE in the root,
#       not inside modules. Modules inherit them. This is the correct pattern.
# =============================================================================

provider "aws" {
  region = var.aws_region

  default_tags {
    tags = {
      Project     = var.project_name
      Environment = local.environment
      ManagedBy   = "Terraform"
      Cluster     = local.cluster_name
    }
  }
}

# ---------------------------------------------------------------------------
# EKS-authenticated providers — configured after cluster is created
# ---------------------------------------------------------------------------

# ---------------------------------------------------------------------------
# EKS-authenticated providers — reads from local kubeconfig
#
# WHY kubeconfig and NOT data sources:
#   When the EKS cluster has ANY pending change (e.g. public_access_cidrs),
#   Terraform marks data.aws_eks_cluster as "known after apply".
#   Providers initialized with null/unknown values fall back to http://localhost.
#   Reading from ~/.kube/config (pre-populated by `aws eks update-kubeconfig`)
#   breaks this dependency and works reliably across applies.
# ---------------------------------------------------------------------------

locals {
  kubeconfig_context = "arn:aws:eks:${var.aws_region}:${data.aws_caller_identity.current.account_id}:cluster/${local.cluster_name}"
}

provider "helm" {
  kubernetes {
    config_path    = "~/.kube/config"
    config_context = local.kubeconfig_context
  }
}

provider "kubernetes" {
  config_path    = "~/.kube/config"
  config_context = local.kubeconfig_context
}

provider "kubectl" {
  config_path      = "~/.kube/config"
  config_context   = local.kubeconfig_context
  load_config_file = true
}
