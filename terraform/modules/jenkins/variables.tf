# =============================================================================
# Jenkins Module — Variables
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

variable "public_subnet_id" {
  description = "Public subnet for the Jenkins Master (needs HTTP access for the UI)"
  type        = string
}

variable "private_subnet_id" {
  description = "Private subnet for all agent nodes (they never need public IPs)"
  type        = string
}

variable "allowed_cidr_blocks" {
  description = "CIDR blocks allowed to reach Jenkins Master UI on port 8080 (restrict to your office/VPN IP)"
  type        = list(string)
  default     = ["0.0.0.0/0"]   # Restrict this to your IP in production!
}

# ── Instance Types ─────────────────────────────────────────────────────────── 
variable "master_instance_type" {
  description = "EC2 type for Jenkins Master Controller"
  type        = string
  default     = "t3.large"
}

variable "build_agent_instance_type" {
  description = "EC2 type for build-agent (Node.js compile, lint, GitOps commit)"
  type        = string
  default     = "t3.medium"
}

variable "security_agent_instance_type" {
  description = "EC2 type for security-agent (Kaniko build, Trivy scan) — needs extra RAM"
  type        = string
  default     = "t3.large"
}

variable "test_agent_instance_type" {
  description = "EC2 type for test-agent (Docker networking, Newman, ZAP DAST)"
  type        = string
  default     = "t3.medium"
}

# ── IAM Instance Profiles ────────────────────────────────────────────────────
variable "master_instance_profile" {
  description = "IAM instance profile for Jenkins Master (SSM only)"
  type        = string
}

variable "build_agent_instance_profile" {
  description = "IAM instance profile for build-agent (SSM + read Git)"
  type        = string
}

variable "security_agent_instance_profile" {
  description = "IAM instance profile for security-agent (SSM + ECR push)"
  type        = string
}

variable "test_agent_instance_profile" {
  description = "IAM instance profile for test-agent (SSM + ECR pull, Docker)"
  type        = string
}

# ── AMI ───────────────────────────────────────────────────────────────────────
variable "ami_id" {
  description = "Amazon Linux 2023 AMI. Leave blank to auto-resolve the latest."
  type        = string
  default     = ""
}
