# =============================================================================
# Production Environment — Root Module
# Composes all modules for the production AWS infrastructure
# =============================================================================
terraform {
  backend "s3" {
    bucket         = "mern-auth-terraform-state-203848753188"
    key            = "production/terraform.tfstate"
    region         = "ap-southeast-1"
    dynamodb_table = "mern-auth-terraform-locks"
    encrypt        = true
  }
}

locals {
  cluster_name = "mern-auth-prod"
  environment  = "production"
}

# ── VPC ──────────────────────────────────────────────────────────────────────
module "vpc" {
  source       = "../../modules/vpc"
  vpc_cidr     = var.vpc_cidr
  cluster_name = local.cluster_name
  environment  = local.environment
}

# ── EKS ──────────────────────────────────────────────────────────────────────
module "eks" {
  source              = "../../modules/eks"
  cluster_name        = local.cluster_name
  kubernetes_version  = var.kubernetes_version
  vpc_id              = module.vpc.vpc_id
  vpc_cidr            = module.vpc.vpc_cidr_block
  private_subnet_ids  = module.vpc.private_subnet_ids
  desired_nodes       = var.desired_nodes
  min_nodes           = var.min_nodes
  max_nodes           = var.max_nodes
  instance_types      = var.instance_types
  capacity_type       = "ON_DEMAND"
  environment         = local.environment
}

# ── DocumentDB ────────────────────────────────────────────────────────────────
module "documentdb" {
  source                     = "../../modules/documentdb"
  cluster_identifier         = "${local.cluster_name}-docdb"
  vpc_id                     = module.vpc.vpc_id
  database_subnet_ids        = module.vpc.database_subnet_ids
  eks_node_security_group_id = module.eks.node_security_group_id
  instance_class             = var.docdb_instance_class
  instance_count             = 3
  backup_retention_days      = 30
  deletion_protection        = true
  environment                = local.environment
}

# ── ALB ──────────────────────────────────────────────────────────────────────
module "alb" {
  source             = "../../modules/alb"
  cluster_name       = local.cluster_name
  vpc_id             = module.vpc.vpc_id
  vpc_cidr           = module.vpc.vpc_cidr_block
  public_subnet_ids  = module.vpc.public_subnet_ids
  oidc_provider_arn  = module.eks.oidc_provider_arn
  oidc_issuer_url    = module.eks.cluster_oidc_issuer_url
  domain_name        = var.domain_name != "" ? var.domain_name : ""
  environment        = local.environment
}

# ── IAM ────────────────────────────────────────────────────────────────────
module "iam" {
  source            = "../../modules/iam"
  cluster_name      = local.cluster_name
  oidc_provider_arn = module.eks.oidc_provider_arn
  oidc_issuer_url   = module.eks.cluster_oidc_issuer_url
  # ECR repo ARNs are created in this environment and wired in here
  ecr_repository_arns = [
    aws_ecr_repository.stage.arn,
    aws_ecr_repository.prod.arn,
  ]
  docdb_secret_arn  = module.documentdb.secret_arn
  environment       = local.environment

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

# ── Monitoring ────────────────────────────────────────────────────────────────
module "monitoring" {
  source           = "../../modules/monitoring"
  cluster_name     = local.cluster_name
  environment      = local.environment
  alert_email      = var.alert_email
  docdb_cluster_id = "${local.cluster_name}-docdb"
}

# ── Jenkins Enterprise Cluster (1 Master + 3 Typed Agents) ───────────────────
# All nodes are bootstrapped automatically via user_data — no manual setup.
# Agents register themselves to the master on first boot using SSH keys from SSM.
module "jenkins" {
  source      = "../../modules/jenkins"
  cluster_name = local.cluster_name
  environment  = local.environment
  vpc_id       = module.vpc.vpc_id

  # Master gets a public subnet (needs to serve the UI on port 8080)
  public_subnet_id  = module.vpc.public_subnet_ids[0]

  # Agents are in private subnets — no direct internet exposure
  private_subnet_id = module.vpc.private_subnet_ids[0]

  # Restrict UI access to your office/VPN IP for security
  # To allow all (for demos): ["0.0.0.0/0"]
  allowed_cidr_blocks = ["0.0.0.0/0"]

  # Wire each node to its own least-privilege IAM profile
  master_instance_profile         = module.iam.jenkins_master_profile
  build_agent_instance_profile    = module.iam.jenkins_build_agent_profile
  security_agent_instance_profile = module.iam.jenkins_security_agent_profile
  test_agent_instance_profile     = module.iam.jenkins_test_agent_profile

  depends_on = [module.iam, module.vpc]
}

# ── ECR Repositories ──────────────────────────────────────────────────────────
resource "aws_ecr_repository" "stage" {
  name                 = "mern-auth/stage"
  image_tag_mutability = "IMMUTABLE"
  force_delete         = false

  image_scanning_configuration { scan_on_push = true }
  encryption_configuration     { encryption_type = "KMS" }
  tags = { Name = "mern-auth/stage" }
}

resource "aws_ecr_repository" "prod" {
  name                 = "mern-auth/prod"
  image_tag_mutability = "IMMUTABLE"
  force_delete         = false

  image_scanning_configuration { scan_on_push = true }
  encryption_configuration     { encryption_type = "KMS" }
  tags = { Name = "mern-auth/prod" }
}

# ECR lifecycle: retain last 30 tagged images only
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
