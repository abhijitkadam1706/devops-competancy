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
# PART 1: Jenkins Enterprise Master/Slave IAM Roles
#
# Each node gets its own distinct least-privilege role:
#   jenkins-master-role        → SSM access + read SSH key from SSM Parameter Store
#   jenkins-build-agent-role   → SSM + read Secrets Manager (for GitOps creds)
#   jenkins-security-agent-role→ SSM + ECR push (Kaniko needs this)
#   jenkins-test-agent-role    → SSM + ECR pull (to pull staging image for testing)
# =============================================================================

# ── Shared assume-role policy: all Jenkins nodes are EC2 instances ────────────
locals {
  ec2_assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = { Service = "ec2.amazonaws.com" }
      Action    = "sts:AssumeRole"
    }]
  })
}

# ─────────────────────────────────────────────────────────────────────────────
# MASTER — Controller node. Serves the UI. No build tools needed.
# Permissions: SSM (no SSH) + read SSH private key from SSM Parameter Store
# ─────────────────────────────────────────────────────────────────────────────
resource "aws_iam_role" "jenkins_master" {
  name               = "${var.cluster_name}-jenkins-master"
  description        = "Jenkins Master Controller — SSM access + read agent SSH key"
  assume_role_policy = local.ec2_assume_role_policy
  tags               = { Name = "${var.cluster_name}-jenkins-master", Role = "jenkins-master" }
}

resource "aws_iam_role_policy" "jenkins_master_ssm_key_read" {
  name = "${var.cluster_name}-jenkins-master-policy"
  role = aws_iam_role.jenkins_master.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Sid      = "ReadAgentSSHKey"
      Effect   = "Allow"
      Action   = ["ssm:GetParameter", "ssm:GetParameters"]
      Resource = "arn:aws:ssm:*:*:parameter/${var.cluster_name}/jenkins/*"
    }]
  })
}

resource "aws_iam_role_policy_attachment" "jenkins_master_ssm" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
  role       = aws_iam_role.jenkins_master.name
}

resource "aws_iam_instance_profile" "jenkins_master" {
  name = "${var.cluster_name}-jenkins-master-profile"
  role = aws_iam_role.jenkins_master.name
  tags = { Name = "${var.cluster_name}-jenkins-master-profile" }
}

# ─────────────────────────────────────────────────────────────────────────────
# BUILD AGENT — Stages 1 (Checkout/Build), 2 (Lint/SAST), 7 (GitOps Commit)
# Permissions: SSM + read GitOps credentials from Secrets Manager
# Does NOT have ECR access — it does not build or push images
# ─────────────────────────────────────────────────────────────────────────────
resource "aws_iam_role" "jenkins_build_agent" {
  name               = "${var.cluster_name}-jenkins-build-agent"
  description        = "Jenkins build-agent — Node.js build, lint, GitOps commit"
  assume_role_policy = local.ec2_assume_role_policy
  tags               = { Name = "${var.cluster_name}-jenkins-build-agent", AgentLabel = "build-agent" }
}

resource "aws_iam_role_policy" "jenkins_build_agent_policy" {
  name = "${var.cluster_name}-jenkins-build-agent-policy"
  role = aws_iam_role.jenkins_build_agent.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Sid      = "ReadGitOpsCredentials"
      Effect   = "Allow"
      Action   = ["secretsmanager:GetSecretValue"]
      Resource = "arn:aws:secretsmanager:*:*:secret:${var.cluster_name}/jenkins/gitops-*"
    }]
  })
}

resource "aws_iam_role_policy_attachment" "jenkins_build_agent_ssm" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
  role       = aws_iam_role.jenkins_build_agent.name
}

resource "aws_iam_instance_profile" "jenkins_build_agent" {
  name = "${var.cluster_name}-jenkins-build-agent-profile"
  role = aws_iam_role.jenkins_build_agent.name
  tags = { Name = "${var.cluster_name}-jenkins-build-agent-profile" }
}

# ─────────────────────────────────────────────────────────────────────────────
# SECURITY AGENT — Stages 3 (Quality Gate), 4 (Kaniko Build + Trivy)
# Permissions: SSM + ECR push (Kaniko must push the built image to ECR)
# Also allowed: ECR GetAuthorizationToken (needed by both Docker login and Kaniko)
# ─────────────────────────────────────────────────────────────────────────────
resource "aws_iam_role" "jenkins_security_agent" {
  name               = "${var.cluster_name}-jenkins-security-agent"
  description        = "Jenkins security-agent — Kaniko build + ECR push + Trivy scan"
  assume_role_policy = local.ec2_assume_role_policy
  tags               = { Name = "${var.cluster_name}-jenkins-security-agent", AgentLabel = "security-agent" }
}

resource "aws_iam_role_policy" "jenkins_security_agent_ecr_push" {
  name = "${var.cluster_name}-jenkins-security-agent-policy"
  role = aws_iam_role.jenkins_security_agent.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid      = "ECRLogin"
        Effect   = "Allow"
        Action   = ["ecr:GetAuthorizationToken"]
        Resource = "*"
      },
      {
        Sid    = "ECRPushOnly"
        Effect = "Allow"
        Action = [
          "ecr:BatchCheckLayerAvailability",
          "ecr:InitiateLayerUpload",
          "ecr:UploadLayerPart",
          "ecr:CompleteLayerUpload",
          "ecr:PutImage"
        ]
        # Scoped to ONLY the staging and production ECR repos — no wildcard
        Resource = var.ecr_repository_arns
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "jenkins_security_agent_ssm" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
  role       = aws_iam_role.jenkins_security_agent.name
}

resource "aws_iam_instance_profile" "jenkins_security_agent" {
  name = "${var.cluster_name}-jenkins-security-agent-profile"
  role = aws_iam_role.jenkins_security_agent.name
  tags = { Name = "${var.cluster_name}-jenkins-security-agent-profile" }
}

# ─────────────────────────────────────────────────────────────────────────────
# TEST AGENT — Stages 5 (Integration Tests + DAST), 6 (DAST Quality Gate)
# Permissions: SSM + ECR pull (to download the staging image for testing)
# Does NOT have push permissions — test results cannot modify the registry
# ─────────────────────────────────────────────────────────────────────────────
resource "aws_iam_role" "jenkins_test_agent" {
  name               = "${var.cluster_name}-jenkins-test-agent"
  description        = "Jenkins test-agent — Docker test networks, Newman API tests, ZAP DAST"
  assume_role_policy = local.ec2_assume_role_policy
  tags               = { Name = "${var.cluster_name}-jenkins-test-agent", AgentLabel = "test-agent" }
}

resource "aws_iam_role_policy" "jenkins_test_agent_ecr_pull" {
  name = "${var.cluster_name}-jenkins-test-agent-policy"
  role = aws_iam_role.jenkins_test_agent.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid      = "ECRLogin"
        Effect   = "Allow"
        Action   = ["ecr:GetAuthorizationToken"]
        Resource = "*"
      },
      {
        # Read-only — can pull images to test them, cannot push
        Sid    = "ECRPullOnly"
        Effect = "Allow"
        Action = [
          "ecr:GetDownloadUrlForLayer",
          "ecr:BatchGetImage",
          "ecr:BatchCheckLayerAvailability",
          "ecr:DescribeImages"
        ]
        Resource = var.ecr_repository_arns
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "jenkins_test_agent_ssm" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
  role       = aws_iam_role.jenkins_test_agent.name
}

resource "aws_iam_instance_profile" "jenkins_test_agent" {
  name = "${var.cluster_name}-jenkins-test-agent-profile"
  role = aws_iam_role.jenkins_test_agent.name
  tags = { Name = "${var.cluster_name}-jenkins-test-agent-profile" }
}

# ─────────────────────────────────────────────────────────────────────────────
# LEGACY SINGLE-AGENT PROFILE (kept for backward compatibility with staging/dev)
# ─────────────────────────────────────────────────────────────────────────────
resource "aws_iam_role" "jenkins_ec2_agent" {
  name               = "${var.cluster_name}-jenkins-agent-ec2"
  description        = "Legacy single-node Jenkins agent (used in staging/dev)"
  assume_role_policy = local.ec2_assume_role_policy
  tags               = { Name = "${var.cluster_name}-jenkins-agent-ec2" }
}

resource "aws_iam_role_policy" "jenkins_ecr_push" {
  name = "${var.cluster_name}-jenkins-ecr-push-policy"
  role = aws_iam_role.jenkins_ec2_agent.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid      = "GetAuthorizationToken"
        Effect   = "Allow"
        Action   = ["ecr:GetAuthorizationToken"]
        Resource = "*"
      },
      {
        Sid    = "PushImagesToECR"
        Effect = "Allow"
        Action = [
          "ecr:BatchCheckLayerAvailability",
          "ecr:InitiateLayerUpload",
          "ecr:UploadLayerPart",
          "ecr:CompleteLayerUpload",
          "ecr:PutImage"
        ]
        Resource = var.ecr_repository_arns
      },
      {
        Sid      = "ReadGitOpsSecret"
        Effect   = "Allow"
        Action   = ["secretsmanager:GetSecretValue"]
        Resource = "arn:aws:secretsmanager:*:*:secret:${var.cluster_name}/jenkins/*"
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "jenkins_ssm" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
  role       = aws_iam_role.jenkins_ec2_agent.name
}

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
