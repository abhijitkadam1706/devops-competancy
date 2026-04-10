# =============================================================================
# EKS Module — Variables (Updated)
# Existing variables preserved + addon version variables added
# =============================================================================

variable "cluster_name" {
  description = "EKS cluster name — used in all resource names"
  type        = string
}

variable "environment" {
  description = "Deployment environment label"
  type        = string
}

variable "kubernetes_version" {
  description = "EKS Kubernetes control plane version"
  type        = string
  default     = "1.30"
}

variable "vpc_id" {
  description = "VPC ID to deploy the EKS cluster into"
  type        = string
}

variable "vpc_cidr" {
  description = "VPC CIDR block — used in security group ingress rules"
  type        = string
}

variable "private_subnet_ids" {
  description = "List of private subnet IDs for EKS node groups (no public IPs)"
  type        = list(string)
}

variable "desired_nodes" {
  description = "Desired number of worker nodes at steady state"
  type        = number
  default     = 3
}

variable "min_nodes" {
  description = "Minimum worker nodes (autoscaling floor)"
  type        = number
  default     = 2
}

variable "max_nodes" {
  description = "Maximum worker nodes (autoscaling ceiling)"
  type        = number
  default     = 8
}

variable "instance_types" {
  description = "EC2 instance types for the managed node group"
  type        = list(string)
  default     = ["t3.medium"]
}

variable "capacity_type" {
  description = "ON_DEMAND or SPOT for the node group"
  type        = string
  default     = "ON_DEMAND"
}

variable "eks_public_access_cidrs" {
  description = "List of CIDRs that can reach the EKS public API endpoint (e.g. your office IP). Restrict after initial deploy."
  type        = list(string)
  default     = ["0.0.0.0/0"]
}

# ── EKS Managed Addon Versions ─────────────────────────────────────────────
# Pin these to a specific version and bump in tfvars to upgrade.
# Find latest compatible versions:
#   aws eks describe-addon-versions --kubernetes-version 1.30 --addon-name <name>

variable "addon_vpc_cni_version" {
  description = "Pinned version of the vpc-cni EKS addon"
  type        = string
  default     = "v1.18.3-eksbuild.1"
}

variable "addon_coredns_version" {
  description = "Pinned version of the coredns EKS addon"
  type        = string
  default     = "v1.11.3-eksbuild.1"
}

variable "addon_kube_proxy_version" {
  description = "Pinned version of the kube-proxy EKS addon"
  type        = string
  default     = "v1.30.3-eksbuild.5"
}

variable "addon_ebs_csi_version" {
  description = "Pinned version of the aws-ebs-csi-driver EKS addon"
  type        = string
  default     = "v1.33.0-eksbuild.1"
}
