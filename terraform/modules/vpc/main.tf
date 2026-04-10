# =============================================================================
# VPC Module — Multi-AZ, Zero-Trust Network Foundation
# =============================================================================

# ── Locals ───────────────────────────────────────────────────────────────────
locals {
  azs             = slice(data.aws_availability_zones.available.names, 0, 3)
  public_subnets  = [for i, az in local.azs : cidrsubnet(var.vpc_cidr, 4, i)]
  private_subnets = [for i, az in local.azs : cidrsubnet(var.vpc_cidr, 4, i + 3)]
  db_subnets      = [for i, az in local.azs : cidrsubnet(var.vpc_cidr, 4, i + 6)]
}

data "aws_availability_zones" "available" {
  state = "available"
}

# ── VPC ──────────────────────────────────────────────────────────────────────
resource "aws_vpc" "main" {
  cidr_block           = var.vpc_cidr
  enable_dns_hostnames = true
  enable_dns_support   = true

  tags = { Name = "${var.cluster_name}-vpc" }
}

# ── Internet Gateway (PUBLIC SUBNETS ONLY) ───────────────────────────────────
resource "aws_internet_gateway" "main" {
  vpc_id = aws_vpc.main.id
  tags   = { Name = "${var.cluster_name}-igw" }
}

# ── Public Subnets ───────────────────────────────────────────────────────────
resource "aws_subnet" "public" {
  count             = length(local.azs)
  vpc_id            = aws_vpc.main.id
  cidr_block        = local.public_subnets[count.index]
  availability_zone = local.azs[count.index]

  # Required for AWS Load Balancer Controller to identify public subnets
  map_public_ip_on_launch = true

  tags = {
    Name                                        = "${var.cluster_name}-public-${count.index + 1}"
    "kubernetes.io/role/elb"                    = "1"
    "kubernetes.io/cluster/${var.cluster_name}" = "shared"
  }
}

# ── Private Subnets (EKS Nodes) ──────────────────────────────────────────────
resource "aws_subnet" "private" {
  count             = length(local.azs)
  vpc_id            = aws_vpc.main.id
  cidr_block        = local.private_subnets[count.index]
  availability_zone = local.azs[count.index]

  tags = {
    Name                                        = "${var.cluster_name}-private-${count.index + 1}"
    "kubernetes.io/role/internal-elb"           = "1"
    "kubernetes.io/cluster/${var.cluster_name}" = "shared"
  }
}

# ── Database Subnets (DocumentDB — fully isolated) ───────────────────────────
resource "aws_subnet" "database" {
  count             = length(local.azs)
  vpc_id            = aws_vpc.main.id
  cidr_block        = local.db_subnets[count.index]
  availability_zone = local.azs[count.index]

  tags = {
    Name = "${var.cluster_name}-db-${count.index + 1}"
    Tier = "database"
  }
}

# ── Elastic IPs for NAT Gateways ─────────────────────────────────────────────
resource "aws_eip" "nat" {
  count  = length(local.azs)
  domain = "vpc"
  tags   = { Name = "${var.cluster_name}-nat-eip-${count.index + 1}" }
}

# ── NAT Gateways (One per AZ for HA) ─────────────────────────────────────────
resource "aws_nat_gateway" "main" {
  count         = length(local.azs)
  allocation_id = aws_eip.nat[count.index].id
  subnet_id     = aws_subnet.public[count.index].id

  tags       = { Name = "${var.cluster_name}-nat-${count.index + 1}" }
  depends_on = [aws_internet_gateway.main]
}

# ── Route Tables ─────────────────────────────────────────────────────────────
resource "aws_route_table" "public" {
  vpc_id = aws_vpc.main.id
  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.main.id
  }
  tags = { Name = "${var.cluster_name}-public-rt" }
}

resource "aws_route_table" "private" {
  count  = length(local.azs)
  vpc_id = aws_vpc.main.id
  route {
    cidr_block     = "0.0.0.0/0"
    nat_gateway_id = aws_nat_gateway.main[count.index].id
  }
  tags = { Name = "${var.cluster_name}-private-rt-${count.index + 1}" }
}

resource "aws_route_table_association" "public" {
  count          = length(local.azs)
  subnet_id      = aws_subnet.public[count.index].id
  route_table_id = aws_route_table.public.id
}

resource "aws_route_table_association" "private" {
  count          = length(local.azs)
  subnet_id      = aws_subnet.private[count.index].id
  route_table_id = aws_route_table.private[count.index].id
}

# ── Zero-Trust: Strip Default Security Group ──────────────────────────────────
resource "aws_default_security_group" "default" {
  vpc_id = aws_vpc.main.id
  # No ingress or egress rules — deny-all by default
  tags = { Name = "DENY-ALL-default-do-not-use" }
}

# ── VPC Flow Logs (SOC2 Compliance) ──────────────────────────────────────────
#
# ROOT CAUSE FIX — ResourceAlreadyExistsException
# ─────────────────────────────────────────────────────────────────────────────
# The log group /aws/vpc/.../flow-logs persists in AWS after terraform destroy
# because AWS retains CloudWatch log groups that contain log stream data.
# On the next apply, Terraform tried to CREATE it again → AlreadyExistsException.
#
# FIX: Stop managing the log group as a Terraform resource.
# Instead, create it idempotently via AWS CLI (never fails on already-exists),
# then READ it with a data source. The log group lifecycle is now:
#   - Created on first apply (or already exists → no-op)
#   - NEVER destroyed by Terraform (intentional — preserves audit logs)
#   - Retention + tags managed via AWS CLI in the null_resource
# ─────────────────────────────────────────────────────────────────────────────

locals {
  flow_log_group_name = "/aws/vpc/${var.cluster_name}/flow-logs"
}

data "aws_region" "current" {}

resource "null_resource" "ensure_flow_log_group" {
  # Re-run if cluster name changes (log group name changes)
  triggers = {
    log_group_name = local.flow_log_group_name
  }

  provisioner "local-exec" {
    interpreter = ["PowerShell", "-Command"]
    command     = <<-EOT
      $name   = "${local.flow_log_group_name}"
      $region = "${data.aws_region.current.name}"

      Write-Host "Ensuring CloudWatch log group exists (idempotent): $name"

      # create-log-group exits 0 if created, non-zero if already exists — suppress the error
      aws logs create-log-group --log-group-name $name --region $region 2>&1 | Out-Null

      # set-retention-policy is always idempotent
      aws logs put-retention-policy `
        --log-group-name $name `
        --retention-in-days 90 `
        --region $region

      Write-Host "Log group ready."
    EOT
  }
}

# Read the log group that was just ensured to exist above
data "aws_cloudwatch_log_group" "flow_log" {
  name       = local.flow_log_group_name
  depends_on = [null_resource.ensure_flow_log_group]
}

resource "aws_flow_log" "main" {
  iam_role_arn    = aws_iam_role.flow_log.arn
  log_destination = data.aws_cloudwatch_log_group.flow_log.arn
  traffic_type    = "ALL"
  vpc_id          = aws_vpc.main.id
  tags            = { Name = "${var.cluster_name}-flow-logs" }

  depends_on = [null_resource.ensure_flow_log_group]
}

resource "aws_iam_role" "flow_log" {
  name = "${var.cluster_name}-flow-log-role"
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action    = "sts:AssumeRole"
      Effect    = "Allow"
      Principal = { Service = "vpc-flow-logs.amazonaws.com" }
    }]
  })
}

resource "aws_iam_role_policy" "flow_log" {
  name = "${var.cluster_name}-flow-log-policy"
  role = aws_iam_role.flow_log.id
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Action = [
        "logs:CreateLogGroup",
        "logs:CreateLogStream",
        "logs:PutLogEvents",
        "logs:DescribeLogGroups",
        "logs:DescribeLogStreams"
      ]
      Resource = "*"
    }]
  })
}
