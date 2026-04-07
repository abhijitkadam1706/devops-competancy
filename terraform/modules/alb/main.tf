# =============================================================================
# ALB Module — AWS Load Balancer Controller + IRSA
# Only public entry point into the system
# Zero-Trust: No direct node exposure, WAF-ready
#
# DOMAIN-OPTIONAL DESIGN:
# If you don't own a domain name yet, set domain_name = "" in your .tfvars
# The ALB will still be created and accessible via its free AWS DNS hostname
# (e.g. mern-auth-prod-1234567.ap-southeast-1.elb.amazonaws.com)
# ACM certificate and WAF are only provisioned when domain_name is supplied.
# =============================================================================

# ── Security Group — HTTPS only, no SSH, no HTTP ─────────────────────────────
resource "aws_security_group" "alb" {
  name        = "${var.cluster_name}-alb-sg"
  description = "ALB security group - public HTTPS only"
  vpc_id      = var.vpc_id

  ingress {
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
    description = "HTTPS from internet"
  }

  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
    description = "HTTP - redirects to HTTPS (no content served)"
  }

  egress {
    from_port   = var.app_port
    to_port     = var.app_port
    protocol    = "tcp"
    cidr_blocks = [var.vpc_cidr]
    description = "Forward to app port on EKS nodes only"
  }

  tags = { Name = "${var.cluster_name}-alb-sg" }
}

# ── IRSA: IAM Role for AWS Load Balancer Controller ──────────────────────────
data "aws_iam_policy_document" "alb_controller_assume" {
  statement {
    effect = "Allow"
    principals {
      type        = "Federated"
      identifiers = [var.oidc_provider_arn]
    }
    actions = ["sts:AssumeRoleWithWebIdentity"]
    condition {
      test     = "StringEquals"
      variable = "${replace(var.oidc_issuer_url, "https://", "")}:sub"
      values   = ["system:serviceaccount:kube-system:aws-load-balancer-controller"]
    }
    condition {
      test     = "StringEquals"
      variable = "${replace(var.oidc_issuer_url, "https://", "")}:aud"
      values   = ["sts.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "alb_controller" {
  name               = "${var.cluster_name}-alb-controller"
  assume_role_policy = data.aws_iam_policy_document.alb_controller_assume.json
  tags               = { Name = "${var.cluster_name}-alb-controller" }
}

# Minimal IAM policy for the ALB Controller (least privilege)
resource "aws_iam_policy" "alb_controller" {
  name        = "${var.cluster_name}-alb-controller-policy"
  description = "Least-privilege policy for AWS Load Balancer Controller"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "elasticloadbalancing:CreateLoadBalancer",
          "elasticloadbalancing:CreateTargetGroup",
          "elasticloadbalancing:CreateListener",
          "elasticloadbalancing:DeleteListener",
          "elasticloadbalancing:CreateRule",
          "elasticloadbalancing:DeleteRule",
          "elasticloadbalancing:AddTags",
          "elasticloadbalancing:RemoveTags",
          "elasticloadbalancing:ModifyLoadBalancerAttributes",
          "elasticloadbalancing:ModifyTargetGroup",
          "elasticloadbalancing:ModifyTargetGroupAttributes",
          "elasticloadbalancing:RegisterTargets",
          "elasticloadbalancing:DeregisterTargets",
          "elasticloadbalancing:SetWebAcl",
          "ec2:DescribeVpcs",
          "ec2:DescribeSubnets",
          "ec2:DescribeSecurityGroups",
          "ec2:DescribeInstances",
          "ec2:DescribeNetworkInterfaces",
          "ec2:CreateSecurityGroup",
          "ec2:AuthorizeSecurityGroupIngress",
          "ec2:RevokeSecurityGroupIngress",
          "ec2:DeleteSecurityGroup",
          "acm:ListCertificates",
          "acm:DescribeCertificate",
          "iam:CreateServiceLinkedRole"
        ]
        Resource = "*"
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "alb_controller" {
  policy_arn = aws_iam_policy.alb_controller.arn
  role       = aws_iam_role.alb_controller.name
}

# ── ACM Certificate (OPTIONAL — only created when domain_name is set) ─────────
# If you don't have a domain, leave domain_name = "" and this is skipped.
# Your app will be reachable via the ALB's auto-generated AWS DNS name instead.
resource "aws_acm_certificate" "main" {
  count             = var.domain_name != "" ? 1 : 0
  domain_name       = var.domain_name
  validation_method = "DNS"

  subject_alternative_names = [
    "*.${var.domain_name}",
    "api.${var.domain_name}",
  ]

  lifecycle {
    create_before_destroy = true
  }

  tags = { Name = "${var.cluster_name}-cert" }
}

# ── AWS WAF (OPTIONAL — only created when domain_name is set) ─────────────────
# WAF is only useful when you have a stable domain to point it at.
resource "aws_wafv2_web_acl" "main" {
  count = var.domain_name != "" ? 1 : 0
  name  = "${var.cluster_name}-waf"
  scope = "REGIONAL"

  default_action {
    allow {}
  }

  # Block known bad bots (AWS Managed Rule — no config needed)
  rule {
    name     = "AWSManagedRulesCommonRuleSet"
    priority = 1
    override_action {
      none {}
    }
    statement {
      managed_rule_group_statement {
        name        = "AWSManagedRulesCommonRuleSet"
        vendor_name = "AWS"
      }
    }
    visibility_config {
      cloudwatch_metrics_enabled = true
      metric_name                = "CommonRuleSetMetric"
      sampled_requests_enabled   = true
    }
  }

  # Block SQL injection attacks
  rule {
    name     = "AWSManagedRulesSQLiRuleSet"
    priority = 2
    override_action {
      none {}
    }
    statement {
      managed_rule_group_statement {
        name        = "AWSManagedRulesSQLiRuleSet"
        vendor_name = "AWS"
      }
    }
    visibility_config {
      cloudwatch_metrics_enabled = true
      metric_name                = "SQLiRuleSetMetric"
      sampled_requests_enabled   = true
    }
  }

  visibility_config {
    cloudwatch_metrics_enabled = true
    metric_name                = "${var.cluster_name}-waf"
    sampled_requests_enabled   = true
  }

  tags = { Name = "${var.cluster_name}-waf" }
}
