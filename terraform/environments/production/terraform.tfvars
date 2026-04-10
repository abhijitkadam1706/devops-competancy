# =============================================================================
# Production Environment — terraform.tfvars
#
# NON-SECRET configuration only. All secrets flow via AWS SSM Parameter Store.
# This file IS safe to commit to Git (no passwords, keys, or tokens here).
#
# After running `terraform/global`, replace the backend bucket name in
# versions.tf with the output value of `state_bucket_name`.
# =============================================================================

# ── Identity ──────────────────────────────────────────────────────────────────
aws_region   = "ap-southeast-1"
project_name = "mern-auth"

# ── Network ───────────────────────────────────────────────────────────────────
vpc_cidr = "10.0.0.0/16"

# ── EKS ───────────────────────────────────────────────────────────────────────
kubernetes_version      = "1.30"
desired_nodes           = 3
min_nodes               = 2
max_nodes               = 6
instance_types          = ["t3.medium"]
eks_public_access_cidrs = ["0.0.0.0/0"] # Open during deployment. Your Wi-Fi IP 10.252.94.244 is RFC-1918 private — cannot restrict a public AWS endpoint with it.


# ── DocumentDB ────────────────────────────────────────────────────────────────
docdb_instance_class = "db.r6g.large"
docdb_instance_count = 3

# ── Jenkins ───────────────────────────────────────────────────────────────────
# Restrict to VPN/office CIDR in real production. Open for initial setup only.
jenkins_allowed_cidr_blocks          = ["0.0.0.0/0"]
jenkins_master_instance_type         = "t3.medium"
jenkins_build_agent_instance_type    = "t3.large"
jenkins_security_agent_instance_type = "t3.large"
jenkins_test_agent_instance_type     = "t3.large"

# ── Monitoring ────────────────────────────────────────────────────────────────
alert_email              = "kadamabhijit1706@gmail.com"
prometheus_chart_version = "61.3.2"

# ── ArgoCD ────────────────────────────────────────────────────────────────────
argocd_chart_version = "7.3.3"
gitops_repo_url      = "https://github.com/abhijitkadam1706/devops-competancy.git"
gitops_branch        = "main"

# ── Domain ────────────────────────────────────────────────────────────────────
# Empty = use raw ALB DNS (as confirmed). Set a Route53 domain name to enable ACM + HTTPS.
domain_name = ""
