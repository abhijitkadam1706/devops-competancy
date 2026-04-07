variable "cluster_name"       { type = string }
variable "oidc_provider_arn"  { type = string }
variable "oidc_issuer_url"    { type = string }
variable "docdb_secret_arn"   { type = string }
variable "environment"        { type = string }

# List of ECR repo ARNs the Jenkins agent is allowed to push to
variable "ecr_repository_arns" {
  description = "List of ECR repository ARNs Jenkins agent can push images to"
  type        = list(string)
  default     = []
}

# Map of Kubernetes ServiceAccounts to create IRSA roles for
variable "service_accounts" {
  description = "Map of ServiceAccount name → namespace + IAM policy JSON"
  type = map(object({
    namespace   = string
    policy_json = string
  }))
  default = {}
}
