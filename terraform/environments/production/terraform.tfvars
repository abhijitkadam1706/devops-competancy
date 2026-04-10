# =============================================================================
# Production Environment — terraform.tfvars
#
# AWS DevOps Competency Case Study: MERN-Auth Application
#
# NON-SECRET configuration only. All secrets (GitHub PAT, SonarCloud token,
# JWT secret, MongoDB password) are stored in AWS SSM Parameter Store.
# This file IS safe to commit to version control.
#
# Cost Optimization (AWS Well-Architected COST-001):
#   Resources are right-sized for a MERN application case study.
#   Auto-scaling policies handle production traffic spikes.
# =============================================================================

# ── Identity ──────────────────────────────────────────────────────────────────
aws_region   = "ap-southeast-1"
project_name = "mern-auth"

# ── Network (PRIAC-001: Templated Infrastructure) ─────────────────────────────
vpc_cidr = "10.0.0.0/16"

# ── EKS (PRMSC-001: Container Services) ──────────────────────────────────────
# Right-sized for MERN app: 2 nodes handle normal load, scales to 4 on demand.
kubernetes_version      = "1.30"
desired_nodes           = 2
min_nodes               = 1
max_nodes               = 4
instance_types          = ["t3.medium"]
eks_public_access_cidrs = ["0.0.0.0/0"]

# ── DocumentDB (Application Database) ────────────────────────────────────────
# Single-node t3.medium is sufficient for the MERN-Auth case study.
# Production multi-AZ can be enabled by increasing docdb_instance_count.
docdb_instance_class = "db.t3.medium"
docdb_instance_count = 1

# ── Jenkins (PRCICD-001/002: CI/CD Pipeline) ─────────────────────────────────
# Master: t3.medium (orchestration only, no builds)
# Agents: t3.medium (adequate for Node.js builds, Docker, scanning)
jenkins_allowed_cidr_blocks          = ["0.0.0.0/0"]
jenkins_master_instance_type         = "t3.medium"
jenkins_build_agent_instance_type    = "t3.medium"
jenkins_security_agent_instance_type = "t3.medium"
jenkins_test_agent_instance_type     = "t3.medium"

# ── Monitoring (PRMLO-001: Cloud Monitoring) ─────────────────────────────────
alert_email              = "kadamabhijit1706@gmail.com"
prometheus_chart_version = "61.3.2"

# ── ArgoCD (PRCICD-001: Release Workflows / GitOps) ──────────────────────────
argocd_chart_version = "7.3.3"
gitops_repo_url      = "https://github.com/abhijitkadam1706/devops-competancy.git"
gitops_branch        = "master"

# ── Domain ────────────────────────────────────────────────────────────────────
# Empty = use raw ALB DNS name. Set a Route53 domain to enable ACM + HTTPS.
domain_name = ""
