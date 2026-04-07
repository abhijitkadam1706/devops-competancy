# =============================================================================
# Dev Environment — Root Module
# Minimal footprint — smallest instances, auto-destroy friendly
# No ALB, no monitoring, no WAF — use "kubectl port-forward" to access locally
# =============================================================================
terraform {
  backend "s3" {
    # Replace 203848753188 with your 12-digit AWS Account ID
    bucket         = "mern-auth-terraform-state-203848753188"
    key            = "dev/terraform.tfstate"
    region         = "ap-southeast-1"
    dynamodb_table = "mern-auth-terraform-locks"
    encrypt        = true
  }
}

locals {
  cluster_name = "mern-auth-dev"
  environment  = "dev"
}

# ── VPC ──────────────────────────────────────────────────────────────────────
module "vpc" {
  source       = "../../modules/vpc"
  vpc_cidr     = var.vpc_cidr
  cluster_name = local.cluster_name
  environment  = local.environment
}

# ── EKS (single SPOT node — absolute minimum cost) ───────────────────────────
module "eks" {
  source             = "../../modules/eks"
  cluster_name       = local.cluster_name
  kubernetes_version = var.kubernetes_version
  vpc_id             = module.vpc.vpc_id
  vpc_cidr           = module.vpc.vpc_cidr_block
  private_subnet_ids = module.vpc.private_subnet_ids
  desired_nodes      = 1
  min_nodes          = 1
  max_nodes          = 3
  instance_types     = ["t3.medium"]
  capacity_type      = "SPOT"
  environment        = local.environment
}

# ── DocumentDB (single instance, 1-day backup, no deletion protection) ───────
module "documentdb" {
  source                     = "../../modules/documentdb"
  cluster_identifier         = "${local.cluster_name}-docdb"
  vpc_id                     = module.vpc.vpc_id
  database_subnet_ids        = module.vpc.database_subnet_ids
  eks_node_security_group_id = module.eks.node_security_group_id
  instance_class             = "db.t3.medium"
  instance_count             = 1
  backup_retention_days      = 1
  deletion_protection        = false
  environment                = local.environment
}

# ── IAM (Jenkins EC2 role auto-created here — no manual steps needed) ────────
module "iam" {
  source              = "../../modules/iam"
  cluster_name        = local.cluster_name
  oidc_provider_arn   = module.eks.oidc_provider_arn
  oidc_issuer_url     = module.eks.cluster_oidc_issuer_url
  ecr_repository_arns = var.ecr_repository_arns
  docdb_secret_arn    = module.documentdb.secret_arn
  environment         = local.environment

  service_accounts = {
    "mern-auth-app" = {
      namespace   = "mern-auth-dev"
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

# No ALB in dev — access the app via: kubectl port-forward svc/mern-auth 3000:3000 -n mern-auth-dev
