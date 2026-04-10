# =============================================================================
# Production Environment — Data Sources
# All dynamic values (account ID, region, cluster auth) are resolved here.
# NOTHING is hardcoded in main.tf or variables.
# =============================================================================

# Current AWS account and region — used to compute ECR URLs, ARNs, etc.
data "aws_caller_identity" "current" {}
data "aws_region" "current" {}

# EKS cluster auth — required by Helm, Kubernetes, and kubectl providers.
# These data sources pull live cluster metadata after EKS is created.
data "aws_eks_cluster" "main" {
  name = local.cluster_name
  # Depends on the cluster being created by the eks module in main.tf
  depends_on = [module.eks]
}

data "aws_eks_cluster_auth" "main" {
  name = local.cluster_name
  depends_on = [module.eks]
}
