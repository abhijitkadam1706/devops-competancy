# =============================================================================
# ArgoCD Module — Outputs
# =============================================================================

output "argocd_namespace" {
  description = "Kubernetes namespace where ArgoCD is deployed"
  value       = var.argocd_namespace
}

output "argocd_admin_password_ssm_path" {
  description = "SSM Parameter Store path for the ArgoCD admin password (SecureString)"
  value       = aws_ssm_parameter.argocd_admin_password.name
}

output "staging_app_name" {
  description = "ArgoCD Application name for staging"
  value       = "${var.cluster_name}-staging"
}

output "production_app_name" {
  description = "ArgoCD Application name for production"
  value       = "${var.cluster_name}-production"
}
