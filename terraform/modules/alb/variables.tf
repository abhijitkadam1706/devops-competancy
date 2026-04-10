variable "cluster_name" {
  description = "Name prefix for all resources"
  type        = string
}

variable "vpc_id" {
  description = "VPC ID where the ALB security group will be created"
  type        = string
}

variable "vpc_cidr" {
  description = "VPC CIDR block for security group egress rules"
  type        = string
}



variable "oidc_provider_arn" {
  description = "ARN of the EKS cluster OIDC provider for IRSA"
  type        = string
}

variable "oidc_issuer_url" {
  description = "OIDC issuer URL from the EKS cluster"
  type        = string
}

variable "app_port" {
  description = "Application port that the ALB forwards traffic to"
  type        = number
  default     = 9191
}

variable "domain_name" {
  description = "Your custom domain name (e.g. mern-auth.example.com). Leave empty string if you don't have one yet — ALB will use its free AWS DNS name."
  type        = string
  default     = ""
}

variable "environment" {
  description = "Deployment environment (dev/staging/production)"
  type        = string
}
