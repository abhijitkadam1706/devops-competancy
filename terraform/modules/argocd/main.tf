# =============================================================================
# ArgoCD Module — Main
#
# Installs ArgoCD via the official Helm chart and creates:
#   - ArgoCD Application: staging  (auto-sync ON  — deployed by Jenkins commit)
#   - ArgoCD Application: production (auto-sync OFF — deployed by PR merge)
#   - ArgoCD admin password stored in AWS SSM (no manual retrieval needed)
#
# PROVIDERS NOTE:
#   The helm, kubernetes, and kubectl providers are configured in the ROOT
#   module (environments/production/providers.tf) using EKS cluster outputs.
#   This module itself does NOT configure providers — it inherits them.
#   This is the correct Terraform pattern for Helm-on-EKS deployments.
# =============================================================================

# ---------------------------------------------------------------------------
# Locals
# ---------------------------------------------------------------------------

locals {
  argocd_labels = merge(var.tags, {
    "app.kubernetes.io/managed-by" = "Terraform"
    "app.kubernetes.io/part-of"    = var.cluster_name
  })
}

# ---------------------------------------------------------------------------
# Namespaces — created before Helm chart so Helm doesn't own them
# ---------------------------------------------------------------------------

resource "kubernetes_namespace" "argocd" {
  metadata {
    name   = var.argocd_namespace
    labels = local.argocd_labels
  }
}

resource "kubernetes_namespace" "staging" {
  metadata {
    name   = var.staging_namespace
    labels = merge(local.argocd_labels, { environment = "staging" })
  }
}

resource "kubernetes_namespace" "production" {
  metadata {
    name   = var.production_namespace
    labels = merge(local.argocd_labels, { environment = "production" })
  }
}

# ---------------------------------------------------------------------------
# ArgoCD — Helm Release
# ---------------------------------------------------------------------------

resource "helm_release" "argocd" {
  name             = "argocd"
  repository       = "https://argoproj.github.io/argo-helm"
  chart            = "argo-cd"
  version          = var.argocd_chart_version
  namespace        = kubernetes_namespace.argocd.metadata[0].name
  create_namespace = false   # We manage the namespace above
  wait             = true
  wait_for_jobs    = true
  timeout          = 900     # 15 min — pod-readiness only (ALB now async via Ingress)
  atomic           = true    # Rolls back on failure — prevents half-deployed state
  cleanup_on_fail  = true

  values = [
    templatefile("${path.module}/argocd-values.yaml.tpl", {
      cluster_name         = var.cluster_name
      environment          = var.environment
      staging_namespace    = var.staging_namespace
      production_namespace = var.production_namespace
    })
  ]

  depends_on = [kubernetes_namespace.argocd]
}

# ---------------------------------------------------------------------------
# ArgoCD Application — Staging (auto-sync ON)
# Jenkins commits to gitops/staging → ArgoCD deploys automatically
# ---------------------------------------------------------------------------

resource "kubectl_manifest" "argocd_app_staging" {
  yaml_body = templatefile("${path.module}/argocd-app-staging.yaml.tpl", {
    argocd_namespace  = var.argocd_namespace
    gitops_repo_url   = var.gitops_repo_url
    gitops_branch     = var.gitops_branch
    gitops_path       = var.gitops_staging_path
    dest_namespace    = var.staging_namespace
    cluster_name      = var.cluster_name
  })

  depends_on = [helm_release.argocd]
}

# ---------------------------------------------------------------------------
# ArgoCD Application — Production (auto-sync OFF)
# Promoted only via PR merge → ArgoCD syncs on operator approval
# ---------------------------------------------------------------------------

resource "kubectl_manifest" "argocd_app_production" {
  yaml_body = templatefile("${path.module}/argocd-app-production.yaml.tpl", {
    argocd_namespace  = var.argocd_namespace
    gitops_repo_url   = var.gitops_repo_url
    gitops_branch     = var.gitops_branch
    gitops_path       = var.gitops_production_path
    dest_namespace    = var.production_namespace
    cluster_name      = var.cluster_name
  })

  depends_on = [helm_release.argocd]
}

# ---------------------------------------------------------------------------
# Retrieve ArgoCD admin password and store in AWS SSM
# No manual `kubectl get secret` required after deploy
# ---------------------------------------------------------------------------

data "kubernetes_secret" "argocd_initial_admin" {
  metadata {
    name      = "argocd-initial-admin-secret"
    namespace = var.argocd_namespace
  }

  depends_on = [helm_release.argocd]
}

resource "aws_ssm_parameter" "argocd_admin_password" {
  name        = "/${var.cluster_name}/argocd/admin-password"
  description = "ArgoCD initial admin password — rotate after first login"
  type        = "SecureString"
  value       = data.kubernetes_secret.argocd_initial_admin.data["password"]
  overwrite   = true

  tags = merge(var.tags, {
    Name        = "${var.cluster_name}-argocd-admin-password"
    ManagedBy   = "Terraform"
    Environment = var.environment
  })
}
