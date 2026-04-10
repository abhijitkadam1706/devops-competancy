# =============================================================================
# Production Environment — Variables
# All values with sensitive defaults are declared without defaults
# so Terraform forces them to be in terraform.tfvars (not hardcoded here).
# =============================================================================

# ── Identity ─────────────────────────────────────────────────────────────────

variable "aws_region" {
  description = "AWS region to deploy all resources into"
  type        = string
}

variable "project_name" {
  description = "Short project name used in resource naming (e.g. mern-auth)"
  type        = string
}

# ── Network ───────────────────────────────────────────────────────────────────

variable "vpc_cidr" {
  description = "CIDR block for the VPC"
  type        = string
}

# ── EKS ───────────────────────────────────────────────────────────────────────

variable "kubernetes_version" {
  description = "EKS Kubernetes control plane version"
  type        = string
}

variable "desired_nodes" {
  description = "Desired number of EKS worker nodes"
  type        = number
}

variable "min_nodes" {
  description = "Minimum number of EKS worker nodes (autoscaling floor)"
  type        = number
}

variable "max_nodes" {
  description = "Maximum number of EKS worker nodes (autoscaling ceiling)"
  type        = number
}

variable "instance_types" {
  description = "EC2 instance types for the EKS node group"
  type        = list(string)
}

variable "eks_public_access_cidrs" {
  description = "CIDRs allowed to reach the EKS public API endpoint. Set to your office/VPN IP for security. Use [\"0.0.0.0/0\"] only temporarily during initial deploy."
  type        = list(string)
  default     = ["0.0.0.0/0"]
}

# ── DocumentDB ────────────────────────────────────────────────────────────────

variable "docdb_instance_class" {
  description = "DocumentDB instance class"
  type        = string
}

variable "docdb_instance_count" {
  description = "Number of DocumentDB instances (1 primary + N replicas)"
  type        = number
  default     = 3
}

# ── Jenkins ───────────────────────────────────────────────────────────────────

variable "jenkins_allowed_cidr_blocks" {
  description = "CIDR blocks allowed to reach the Jenkins UI (port 8080). Restrict to VPN/office IP in production."
  type        = list(string)
}

variable "jenkins_master_instance_type" {
  description = "EC2 instance type for the Jenkins master"
  type        = string
  default     = "t3.medium"
}

variable "jenkins_build_agent_instance_type" {
  description = "EC2 instance type for the Jenkins build agent"
  type        = string
  default     = "t3.large"
}

variable "jenkins_security_agent_instance_type" {
  description = "EC2 instance type for the Jenkins security agent (Kaniko + Trivy)"
  type        = string
  default     = "t3.large"
}

variable "jenkins_test_agent_instance_type" {
  description = "EC2 instance type for the Jenkins test agent (Newman + ZAP)"
  type        = string
  default     = "t3.large"
}

# ── Monitoring ────────────────────────────────────────────────────────────────

variable "alert_email" {
  description = "Email address for CloudWatch alarm notifications"
  type        = string
}

variable "prometheus_chart_version" {
  description = "Pinned version of the kube-prometheus-stack Helm chart"
  type        = string
  default     = "61.3.2"
}

# ── ArgoCD ────────────────────────────────────────────────────────────────────

variable "argocd_chart_version" {
  description = "Pinned version of the argo-cd Helm chart"
  type        = string
  default     = "7.3.3"
}

variable "gitops_repo_url" {
  description = "HTTPS URL of the GitOps repository that ArgoCD monitors"
  type        = string
}

variable "gitops_branch" {
  description = "Branch in the GitOps repo that ArgoCD tracks"
  type        = string
  default     = "main"
}

# ── Domain ────────────────────────────────────────────────────────────────────

variable "domain_name" {
  description = "Optional custom domain name. Leave empty to use raw ALB DNS."
  type        = string
  default     = ""
}
