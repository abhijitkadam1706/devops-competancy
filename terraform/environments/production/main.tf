# =============================================================================
# Production Environment — Root Module (main.tf)
#
# Composes ALL modules into a complete production environment.
# Module dependency order (implicit via input/output wiring):
#   vpc → eks → (iam, alb, documentdb) → monitoring → argocd → jenkins
#
# ZERO hardcoded values:
#   - Account ID:  locals.account_id  (from data.aws_caller_identity)
#   - Region:      locals.aws_region  (from data.aws_region)
#   - ECR URLs:    locals.ecr_*       (computed in locals.tf)
# =============================================================================

# ── VPC ──────────────────────────────────────────────────────────────────────

module "vpc" {
  source       = "../../modules/vpc"
  vpc_cidr     = var.vpc_cidr
  cluster_name = local.cluster_name
  environment  = local.environment
}

# ── EKS ──────────────────────────────────────────────────────────────────────

module "eks" {
  source                  = "../../modules/eks"
  cluster_name            = local.cluster_name
  kubernetes_version      = var.kubernetes_version
  vpc_id                  = module.vpc.vpc_id
  vpc_cidr                = module.vpc.vpc_cidr_block
  private_subnet_ids      = module.vpc.private_subnet_ids
  desired_nodes           = var.desired_nodes
  min_nodes               = var.min_nodes
  max_nodes               = var.max_nodes
  instance_types          = var.instance_types
  capacity_type           = "ON_DEMAND"
  environment             = local.environment
  eks_public_access_cidrs = var.eks_public_access_cidrs
}

# ── IAM (IRSA for app service accounts) ──────────────────────────────────────

module "iam" {
  source            = "../../modules/iam"
  cluster_name      = local.cluster_name
  oidc_provider_arn = module.eks.oidc_provider_arn
  oidc_issuer_url   = module.eks.cluster_oidc_issuer_url
  ecr_repository_arns = [
    aws_ecr_repository.stage.arn,
    aws_ecr_repository.prod.arn,
  ]
  docdb_secret_arn = module.documentdb.secret_arn
  environment      = local.environment

  service_accounts = {
    "mern-auth-app" = {
      namespace   = "mern-auth-production"
      policy_json = jsonencode({
        Version = "2012-10-17"
        Statement = [{
          Effect   = "Allow"
          Action   = ["secretsmanager:GetSecretValue"]
          Resource = module.documentdb.secret_arn
        }]
      })
    }
  }
}

# ── Auto-update kubeconfig after every EKS creation/recreation ───────────────
#
# PERMANENT FIX: After `terraform destroy`, the local kubeconfig still holds the
# OLD cluster endpoint (different hash). The new cluster gets a NEW endpoint.
# Without this, kubectl/Helm providers silently use the stale host → 'no such host'.
#
# This null_resource triggers on cluster endpoint changes (guaranteed after any
# destroy+recreate) and runs BEFORE any Kubernetes resource attempts a connection.
# All k8s-touching resources depend on it via depends_on.

resource "null_resource" "update_kubeconfig" {
  triggers = {
    # Fires whenever the cluster endpoint changes — always true after destroy+recreate
    cluster_endpoint = module.eks.cluster_endpoint
  }

  provisioner "local-exec" {
    interpreter = ["PowerShell", "-Command"]
    command     = <<-EOT
      # ── Step 1: Update kubeconfig ────────────────────────────────────────────
      Write-Host "Updating kubeconfig for cluster ${local.cluster_name}..."
      aws eks update-kubeconfig --region ${var.aws_region} --name ${local.cluster_name}
      if ($LASTEXITCODE -ne 0) { throw "aws eks update-kubeconfig failed" }

      # ── Step 2: Flush Windows DNS cache ─────────────────────────────────────
      # CRITICAL: After destroy+recreate, the EKS endpoint hostname may resolve
      # to a NEW IP (even if the hostname looks the same). The old IP is cached
      # in the Windows DNS resolver. Clear it to force a fresh DNS lookup.
      Write-Host "Flushing Windows DNS cache..."
      Clear-DnsClientCache
      Write-Host "DNS cache cleared."

      # ── Step 3: Wait for cluster API to be reachable ─────────────────────────
      # After a fresh EKS creation the API server takes 30-90 seconds to accept
      # connections. Wait here (before returning) so all depends_on resources
      # connect to a LIVE cluster, not a starting-up one.
      $maxAttempts = 24   # 24 x 15s = 6 minutes max wait
      $attempt     = 0
      $ready       = $false

      Write-Host "Waiting for Kubernetes API to become ready..."
      do {
        $attempt++
        Write-Host "  Attempt $attempt/$maxAttempts — kubectl get nodes..."
        $out = kubectl get nodes --request-timeout=10s 2>&1
        if ($LASTEXITCODE -eq 0) {
          Write-Host "  Cluster API is ready! Nodes:"
          Write-Host $out
          $ready = $true
          break
        }
        Write-Host "  Not ready yet: $($out | Select-Object -First 1)"
        if ($attempt -lt $maxAttempts) { Start-Sleep 15 }
      } while ($attempt -lt $maxAttempts)

      if (-not $ready) {
        Write-Host "WARNING: Could not confirm cluster readiness after $(($maxAttempts * 15) / 60) minutes. Proceeding — resources may retry."
      }
    EOT
  }

  depends_on = [module.eks]
}

# ── Storage Class Fix for EKS 1.30+ ──────────────────────────────────────────
# EKS 1.30 no longer marks 'gp2' as default automatically.
# Without a default StorageClass, Helm charts (Prometheus, ArgoCD) fail to bind PVCs.
resource "kubernetes_annotations" "gp2_default" {
  api_version = "storage.k8s.io/v1"
  kind        = "StorageClass"
  metadata {
    name = "gp2"
  }
  annotations = {
    "storageclass.kubernetes.io/is-default-class" = "true"
  }
  force = true

  # Depends on update_kubeconfig: kubeconfig MUST point to the live cluster
  # before the kubernetes provider attempts to connect.
  depends_on = [module.eks, null_resource.update_kubeconfig]
}

# ── DocumentDB ────────────────────────────────────────────────────────────────

module "documentdb" {
  source                     = "../../modules/documentdb"
  cluster_identifier         = "${local.cluster_name}-docdb"
  vpc_id                     = module.vpc.vpc_id
  database_subnet_ids        = module.vpc.database_subnet_ids
  eks_node_security_group_id = module.eks.node_security_group_id
  instance_class             = var.docdb_instance_class
  instance_count             = var.docdb_instance_count
  backup_retention_days      = 30
  deletion_protection        = true
  environment                = local.environment
}

# ── ALB Ingress Controller ────────────────────────────────────────────────────

module "alb" {
  source            = "../../modules/alb"
  cluster_name      = local.cluster_name
  vpc_id            = module.vpc.vpc_id
  vpc_cidr          = module.vpc.vpc_cidr_block
  oidc_provider_arn = module.eks.oidc_provider_arn
  oidc_issuer_url   = module.eks.cluster_oidc_issuer_url
  domain_name       = var.domain_name
  environment       = local.environment
}

# ── Monitoring (CloudWatch + kube-prometheus-stack) ───────────────────────────

module "monitoring" {
  source                   = "../../modules/monitoring"
  cluster_name             = local.cluster_name
  environment              = local.environment
  alert_email              = var.alert_email
  docdb_cluster_id         = "${local.cluster_name}-docdb"
  prometheus_chart_version = var.prometheus_chart_version

  depends_on = [module.eks, null_resource.update_kubeconfig]
}

# ── Jenkins Enterprise Cluster ────────────────────────────────────────────────

module "jenkins" {
  source       = "../../modules/jenkins"
  cluster_name = local.cluster_name
  environment  = local.environment
  vpc_id       = module.vpc.vpc_id
  aws_region   = local.aws_region

  public_subnet_id  = module.vpc.public_subnet_ids[0]
  private_subnet_id = module.vpc.private_subnet_ids[0]

  allowed_cidr_blocks = var.jenkins_allowed_cidr_blocks

  master_instance_type         = var.jenkins_master_instance_type
  build_agent_instance_type    = var.jenkins_build_agent_instance_type
  security_agent_instance_type = var.jenkins_security_agent_instance_type
  test_agent_instance_type     = var.jenkins_test_agent_instance_type

  master_instance_profile         = module.iam.jenkins_master_profile
  build_agent_instance_profile    = module.iam.jenkins_build_agent_profile
  security_agent_instance_profile = module.iam.jenkins_security_agent_profile
  test_agent_instance_profile     = module.iam.jenkins_test_agent_profile

  depends_on = [module.iam, module.vpc]
}

# ── ArgoCD (Terraform-managed — no manual kubectl steps) ─────────────────────

module "argocd" {
  source = "../../modules/argocd"

  cluster_name         = local.cluster_name
  environment          = local.environment
  argocd_chart_version = var.argocd_chart_version
  gitops_repo_url      = local.gitops_repo_url
  gitops_branch        = local.gitops_branch

  staging_namespace    = "mern-auth-staging"
  production_namespace = "mern-auth-production"
  gitops_staging_path  = "gitops/staging"
  gitops_production_path = "gitops/production"

  tags = local.common_tags

  depends_on = [module.eks, module.alb, module.monitoring]
}

# ── ECR Repositories ──────────────────────────────────────────────────────────

resource "aws_ecr_repository" "stage" {
  name                 = "${var.project_name}/stage"
  image_tag_mutability = "IMMUTABLE"
  force_delete         = false

  image_scanning_configuration { scan_on_push = true }
  encryption_configuration     { encryption_type = "KMS" }

  tags = { Name = "${var.project_name}/stage" }
}

resource "aws_ecr_repository" "prod" {
  name                 = "${var.project_name}/prod"
  image_tag_mutability = "IMMUTABLE"
  force_delete         = false

  image_scanning_configuration { scan_on_push = true }
  encryption_configuration     { encryption_type = "KMS" }

  tags = { Name = "${var.project_name}/prod" }
}

resource "aws_ecr_repository" "kaniko_cache" {
  name                 = "kaniko-cache"
  image_tag_mutability = "MUTABLE"   # Cache layers must be overwritable
  force_delete         = false

  image_scanning_configuration { scan_on_push = false }
  encryption_configuration     { encryption_type = "AES256" }

  tags = { Name = "kaniko-cache" }
}

# Lifecycle: retain last 30 tagged images in stage repo
resource "aws_ecr_lifecycle_policy" "stage" {
  repository = aws_ecr_repository.stage.name
  policy = jsonencode({
    rules = [{
      rulePriority = 1
      description  = "Keep last 30 images"
      selection    = { tagStatus = "any", countType = "imageCountMoreThan", countNumber = 30 }
      action       = { type = "expire" }
    }]
  })
}

# Lifecycle: retain last 30 tagged images in prod repo
resource "aws_ecr_lifecycle_policy" "prod" {
  repository = aws_ecr_repository.prod.name
  policy = jsonencode({
    rules = [{
      rulePriority = 1
      description  = "Keep last 30 images"
      selection    = { tagStatus = "any", countType = "imageCountMoreThan", countNumber = 30 }
      action       = { type = "expire" }
    }]
  })
}

# Lifecycle: retain last 50 kaniko cache layers (older ones auto-expire)
resource "aws_ecr_lifecycle_policy" "kaniko_cache" {
  repository = aws_ecr_repository.kaniko_cache.name
  policy = jsonencode({
    rules = [{
      rulePriority = 1
      description  = "Keep last 50 cache layers"
      selection    = { tagStatus = "any", countType = "imageCountMoreThan", countNumber = 50 }
      action       = { type = "expire" }
    }]
  })
}

# ── SSM: Store computed ECR URLs for Jenkins to read ──────────────────────────
# Jenkins reads these via Global Environment Variables (configured in UI)

resource "aws_ssm_parameter" "ecr_registry" {
  name        = "${local.ssm_prefix}/jenkins/ecr-registry"
  description = "ECR registry base URL (account.dkr.ecr.region.amazonaws.com)"
  type        = "String"
  value       = local.ecr_registry
  overwrite   = true
}

resource "aws_ssm_parameter" "ecr_stage_repo" {
  name        = "${local.ssm_prefix}/jenkins/ecr-stage-repo"
  description = "ECR staging repository full URI"
  type        = "String"
  value       = local.ecr_stage_repo
  overwrite   = true
}

resource "aws_ssm_parameter" "ecr_prod_repo" {
  name        = "${local.ssm_prefix}/jenkins/ecr-prod-repo"
  description = "ECR production repository full URI"
  type        = "String"
  value       = local.ecr_prod_repo
  overwrite   = true
}
