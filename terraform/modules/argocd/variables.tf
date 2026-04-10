# =============================================================================
# ArgoCD Module — Variables
# =============================================================================

variable "cluster_name" {
  description = "EKS cluster name — used for resource naming and tags"
  type        = string
}

variable "environment" {
  description = "Deployment environment (production / staging)"
  type        = string
}

variable "argocd_chart_version" {
  description = "Pinned version of the argo-cd Helm chart"
  type        = string
  default     = "7.3.3"
}

variable "argocd_namespace" {
  description = "Kubernetes namespace where ArgoCD is installed"
  type        = string
  default     = "argocd"
}

variable "gitops_repo_url" {
  description = "HTTPS URL of the GitOps repository that ArgoCD watches"
  type        = string
}

variable "gitops_branch" {
  description = "Branch ArgoCD tracks for both staging and production paths"
  type        = string
  default     = "main"
}

variable "staging_namespace" {
  description = "Kubernetes namespace for staging workloads"
  type        = string
  default     = "mern-auth-staging"
}

variable "production_namespace" {
  description = "Kubernetes namespace for production workloads"
  type        = string
  default     = "mern-auth-production"
}

variable "gitops_staging_path" {
  description = "Path inside the GitOps repo that ArgoCD watches for staging"
  type        = string
  default     = "gitops/staging"
}

variable "gitops_production_path" {
  description = "Path inside the GitOps repo that ArgoCD watches for production"
  type        = string
  default     = "gitops/production"
}

variable "tags" {
  description = "Common tags to apply to all taggable AWS resources in this module"
  type        = map(string)
  default     = {}
}
