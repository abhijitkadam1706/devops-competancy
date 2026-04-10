# =============================================================================
# Jenkins Module — Variables (Updated)
# Added: aws_region, ecr_* variables so no values are hardcoded in user_data
# =============================================================================

variable "cluster_name" {
  description = "Used to prefix all resource names"
  type        = string
}

variable "environment" {
  description = "Deployment environment (production, staging, dev)"
  type        = string
}

variable "vpc_id" {
  description = "VPC to launch all Jenkins nodes into"
  type        = string
}

variable "aws_region" {
  description = "AWS region — injected into user_data scripts (replaces hardcoded region)"
  type        = string
}

variable "public_subnet_id" {
  description = "Public subnet for the Jenkins Master (needs HTTP access for the UI)"
  type        = string
}

variable "private_subnet_id" {
  description = "Private subnet for all agent nodes (they never need public IPs)"
  type        = string
}

variable "allowed_cidr_blocks" {
  description = "CIDR blocks allowed to reach Jenkins Master UI on port 8080"
  type        = list(string)
}

# ── Instance Types ─────────────────────────────────────────────────────────────

variable "master_instance_type" {
  description = "EC2 type for Jenkins Master Controller"
  type        = string
  default     = "t3.medium"
}

variable "build_agent_instance_type" {
  description = "EC2 type for build-agent (Node.js compile, lint, GitOps commit)"
  type        = string
  default     = "t3.large"
}

variable "security_agent_instance_type" {
  description = "EC2 type for security-agent (Kaniko build, Trivy scan)"
  type        = string
  default     = "t3.large"
}

variable "test_agent_instance_type" {
  description = "EC2 type for test-agent (Docker networking, Newman, ZAP DAST)"
  type        = string
  default     = "t3.large"
}

# ── IAM Instance Profiles ─────────────────────────────────────────────────────

variable "master_instance_profile" {
  description = "IAM instance profile for Jenkins Master (SSM read + describe EKS)"
  type        = string
}

variable "build_agent_instance_profile" {
  description = "IAM instance profile for build-agent (SSM read, ECR read)"
  type        = string
}

variable "security_agent_instance_profile" {
  description = "IAM instance profile for security-agent (SSM read, ECR push, Cosign)"
  type        = string
}

variable "test_agent_instance_profile" {
  description = "IAM instance profile for test-agent (SSM read, ECR pull)"
  type        = string
}

# NOTE: ECR URLs are stored in SSM by the root module.
# Jenkins reads them via Global Environment Variables configured in the UI.
# No ECR variables needed at the module level.

# ── Tool Versions (pinned — bump in tfvars to upgrade) ────────────────────────

variable "sonar_scanner_version" {
  description = "SonarScanner CLI version to install on build-agent"
  type        = string
  default     = "5.0.1.3006"
}

variable "trivy_version" {
  description = "Trivy version to install on security-agent"
  type        = string
  default     = "0.50.2"
}

variable "cosign_version" {
  description = "Cosign version to install on security-agent"
  type        = string
  default     = "v2.2.2"
}

variable "kustomize_version" {
  description = "Kustomize version to install on build-agent and master"
  type        = string
  default     = "v5.3.0"
}

# ── AMI ───────────────────────────────────────────────────────────────────────

variable "ami_id" {
  description = "Amazon Linux 2023 AMI. Leave blank to auto-resolve the latest."
  type        = string
  default     = ""
}
