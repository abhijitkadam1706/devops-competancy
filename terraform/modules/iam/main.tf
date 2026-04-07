# =============================================================================
# IAM Module — IRSA Roles for Application Workloads
# Zero-Trust: Each Kubernetes ServiceAccount gets its own minimal IAM role
# No shared roles. No wildcard permissions. Namespace-scoped.
#
# NEW (v2): Also creates the Jenkins EC2 agent role + instance profile
# from scratch — no manual AWS Console steps required.
# =============================================================================

locals {
  oidc_host = replace(var.oidc_issuer_url, "https://", "")
}

# =============================================================================
# PART 1: Jenkins EC2 Agent Role (Created Fully by Terraform)
# This is the IAM Identity that the Jenkins EC2 server assumes.
# It can ONLY push images to ECR. Zero Kubernetes access.
# =============================================================================

# EC2 Instance Role — allows the Jenkins EC2 machine to call AWS APIs
resource "aws_iam_role" "jenkins_ec2_agent" {
  name        = "${var.cluster_name}-jenkins-agent-ec2"
  description = "Role assumed by the Jenkins EC2 agent instance. Least-privilege."

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = { Service = "ec2.amazonaws.com" }
      Action    = "sts:AssumeRole"
    }]
  })

  tags = { Name = "${var.cluster_name}-jenkins-agent-ec2" }
}

# Allow Jenkins EC2 to push images to ECR ONLY
resource "aws_iam_role_policy" "jenkins_ecr_push" {
  name = "${var.cluster_name}-jenkins-ecr-push-policy"
  role = aws_iam_role.jenkins_ec2_agent.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        # Step 1: Get a temporary login token for ECR
        Sid      = "GetAuthorizationToken"
        Effect   = "Allow"
        Action   = ["ecr:GetAuthorizationToken"]
        Resource = "*"
      },
      {
        # Step 2: Push image layers and tags — ONLY to our specific repos
        Sid    = "PushImagesToECR"
        Effect = "Allow"
        Action = [
          "ecr:BatchCheckLayerAvailability",
          "ecr:InitiateLayerUpload",
          "ecr:UploadLayerPart",
          "ecr:CompleteLayerUpload",
          "ecr:PutImage"
        ]
        # This will be populated with the ECR repo ARNs after they are created
        Resource = var.ecr_repository_arns
      },
      {
        # Allow Jenkins to read the git-ops secret for GitOps commit step
        Sid      = "ReadGitOpsSecret"
        Effect   = "Allow"
        Action   = ["secretsmanager:GetSecretValue"]
        Resource = "arn:aws:secretsmanager:*:*:secret:${var.cluster_name}/jenkins/*"
      }
    ]
  })
}

# SSM Session Manager — allows secure shell access WITHOUT SSH keys or open port 22
# This replaces the need for a bastion host or open inbound SSH rules
resource "aws_iam_role_policy_attachment" "jenkins_ssm" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
  role       = aws_iam_role.jenkins_ec2_agent.name
}

# EC2 Instance Profile — this is what you attach to an EC2 machine in the Console or Terraform
# Think of it as a "badge holder" that wraps the IAM role for EC2 to use
resource "aws_iam_instance_profile" "jenkins_ec2_agent" {
  name = "${var.cluster_name}-jenkins-agent-profile"
  role = aws_iam_role.jenkins_ec2_agent.name
  tags = { Name = "${var.cluster_name}-jenkins-agent-profile" }
}

# =============================================================================
# PART 2: IRSA Roles (Per Kubernetes Service Account)
# These roles are assumed by PODS running inside EKS — not EC2 machines.
# =============================================================================

# Generates a unique assume-role policy for each Kubernetes ServiceAccount
data "aws_iam_policy_document" "irsa_assume" {
  for_each = var.service_accounts

  statement {
    effect = "Allow"
    principals {
      type        = "Federated"
      identifiers = [var.oidc_provider_arn]
    }
    actions = ["sts:AssumeRoleWithWebIdentity"]
    condition {
      test     = "StringEquals"
      variable = "${local.oidc_host}:sub"
      values   = ["system:serviceaccount:${each.value.namespace}:${each.key}"]
    }
    condition {
      test     = "StringEquals"
      variable = "${local.oidc_host}:aud"
      values   = ["sts.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "irsa" {
  for_each           = var.service_accounts
  name               = "${var.cluster_name}-irsa-${each.key}"
  assume_role_policy = data.aws_iam_policy_document.irsa_assume[each.key].json
  tags               = { ServiceAccount = each.key, Namespace = each.value.namespace }
}

resource "aws_iam_role_policy" "irsa" {
  for_each = var.service_accounts
  name     = "${var.cluster_name}-irsa-${each.key}-policy"
  role     = aws_iam_role.irsa[each.key].id
  policy   = each.value.policy_json
}

# =============================================================================
# PART 3: ArgoCD Role — Read ECR to verify images exist
# =============================================================================

resource "aws_iam_role" "argocd_ecr_readonly" {
  name = "${var.cluster_name}-argocd-ecr-readonly"
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Principal = { Federated = var.oidc_provider_arn }
      Action    = "sts:AssumeRoleWithWebIdentity"
      Condition = {
        StringEquals = {
          "${local.oidc_host}:sub" = "system:serviceaccount:argocd:argocd-application-controller"
          "${local.oidc_host}:aud" = "sts.amazonaws.com"
        }
      }
    }]
  })
}

resource "aws_iam_role_policy_attachment" "argocd_ecr_readonly" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEC2ContainerRegistryReadOnly"
  role       = aws_iam_role.argocd_ecr_readonly.name
}

# =============================================================================
# PART 4: App pods → Secrets Manager (DocumentDB credentials)
# =============================================================================

resource "aws_iam_role_policy" "app_secrets_read" {
  name = "${var.cluster_name}-app-secrets-read"
  role = aws_iam_role.irsa["mern-auth-app"].id
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect   = "Allow"
      Action   = ["secretsmanager:GetSecretValue", "secretsmanager:DescribeSecret"]
      Resource = var.docdb_secret_arn
    }]
  })
}
