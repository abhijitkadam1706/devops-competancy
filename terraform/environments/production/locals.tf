# =============================================================================
# Production Environment — Locals
# All computed values derived from variables or data sources live here.
# This eliminates repetition and keeps main.tf clean.
# =============================================================================

locals {
  # ── Identity ────────────────────────────────────────────────────────────────
  environment  = "production"
  cluster_name = "${var.project_name}-prod"
  account_id   = data.aws_caller_identity.current.account_id
  aws_region   = data.aws_region.current.name

  # ── ECR URLs — computed from live account ID + region (never hardcoded) ────
  ecr_registry    = "${local.account_id}.dkr.ecr.${local.aws_region}.amazonaws.com"
  ecr_stage_repo  = "${local.ecr_registry}/${var.project_name}/stage"
  ecr_prod_repo   = "${local.ecr_registry}/${var.project_name}/prod"
  ecr_cache_repo  = "${local.ecr_registry}/kaniko-cache"

  # ── GitOps ──────────────────────────────────────────────────────────────────
  gitops_repo_url = var.gitops_repo_url
  gitops_branch   = var.gitops_branch

  # ── SSM Parameter Paths (convention: /<cluster>/<service>/<key>) ────────────
  ssm_prefix = "/${local.cluster_name}"

  # ── Common tags applied via provider default_tags (no manual tag blocks) ───
  # Additional resource-specific tags are merged at resource level
  common_tags = {
    Project     = var.project_name
    Environment = local.environment
    ManagedBy   = "Terraform"
    Cluster     = local.cluster_name
  }
}
