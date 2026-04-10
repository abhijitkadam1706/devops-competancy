# =============================================================================
# Production Environment — Outputs
# All critical connection details are surfaced here and stored in SSM.
# After `terraform apply`, run `terraform output` to see all values.
# =============================================================================

# ── EKS ───────────────────────────────────────────────────────────────────────

output "eks_cluster_name" {
  description = "EKS cluster name — use with: aws eks update-kubeconfig --name <value>"
  value       = module.eks.cluster_name
}

output "eks_cluster_endpoint" {
  description = "EKS API server endpoint"
  value       = module.eks.cluster_endpoint
  sensitive   = true
}

output "eks_oidc_provider_arn" {
  description = "OIDC provider ARN for IRSA"
  value       = module.eks.oidc_provider_arn
}

# ── ECR ───────────────────────────────────────────────────────────────────────

output "ecr_registry" {
  description = "ECR registry base URL"
  value       = local.ecr_registry
}

output "ecr_stage_repo_url" {
  description = "Full URI of the staging ECR repository"
  value       = local.ecr_stage_repo
}

output "ecr_prod_repo_url" {
  description = "Full URI of the production ECR repository"
  value       = local.ecr_prod_repo
}

# ── Jenkins ───────────────────────────────────────────────────────────────────

output "jenkins_master_public_ip" {
  description = "Public IP of Jenkins master — access UI at http://<ip>:8080"
  value       = module.jenkins.master_public_ip
}

output "jenkins_initial_admin_password_ssm_path" {
  description = "SSM path to retrieve Jenkins initial admin password"
  value       = "/${local.cluster_name}/jenkins/initial-admin-password"
}

# ── ArgoCD ────────────────────────────────────────────────────────────────────

output "argocd_admin_password_ssm_path" {
  description = "SSM path for ArgoCD admin password — retrieve with: aws ssm get-parameter --name <path> --with-decryption"
  value       = module.argocd.argocd_admin_password_ssm_path
}

# ── DocumentDB ────────────────────────────────────────────────────────────────

output "documentdb_endpoint" {
  description = "DocumentDB cluster endpoint"
  value       = module.documentdb.cluster_endpoint
  sensitive   = true
}

output "documentdb_secret_arn" {
  description = "Secrets Manager ARN for the DocumentDB master password"
  value       = module.documentdb.secret_arn
}

# ── Quick-reference commands ──────────────────────────────────────────────────

output "kubeconfig_command" {
  description = "Run this command to configure kubectl for this cluster"
  value       = "aws eks update-kubeconfig --name ${local.cluster_name} --region ${local.aws_region}"
}

output "argocd_password_command" {
  description = "Run this command to retrieve the ArgoCD admin password"
  value       = "aws ssm get-parameter --name ${module.argocd.argocd_admin_password_ssm_path} --with-decryption --query Parameter.Value --output text"
}
