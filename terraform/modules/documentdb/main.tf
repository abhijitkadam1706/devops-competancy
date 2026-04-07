# =============================================================================
# DocumentDB Module — MongoDB-Compatible, Fully Private, KMS Encrypted
# Zero-Trust: No public access, isolated DB subnets, TLS enforced
# =============================================================================

# ── KMS Key for encryption at rest ───────────────────────────────────────────
resource "aws_kms_key" "docdb" {
  description             = "KMS key for DocumentDB ${var.cluster_identifier}"
  deletion_window_in_days = 30
  enable_key_rotation     = true
  tags                    = { Name = "${var.cluster_identifier}-docdb-key" }
}

resource "aws_kms_alias" "docdb" {
  name          = "alias/${var.cluster_identifier}-docdb"
  target_key_id = aws_kms_key.docdb.key_id
}

# ── Subnet Group (DB-only subnets) ───────────────────────────────────────────
resource "aws_docdb_subnet_group" "main" {
  name       = "${var.cluster_identifier}-subnet-group"
  subnet_ids = var.database_subnet_ids
  tags       = { Name = "${var.cluster_identifier}-docdb-subnet-group" }
}

# ── Security Group — Only allows access from EKS nodes, NO internet ──────────
resource "aws_security_group" "docdb" {
  name        = "${var.cluster_identifier}-docdb-sg"
  description = "DocumentDB security group — VPC internal only"
  vpc_id      = var.vpc_id

  ingress {
    from_port       = 27017
    to_port         = 27017
    protocol        = "tcp"
    security_groups = [var.eks_node_security_group_id]
    description     = "MongoDB from EKS nodes only"
  }

  # Zero-Trust: NO egress from database tier
  tags = { Name = "${var.cluster_identifier}-docdb-sg" }
}

# ── Cluster Parameter Group — Enforce TLS ────────────────────────────────────
resource "aws_docdb_cluster_parameter_group" "main" {
  family      = "docdb5.0"
  name        = "${var.cluster_identifier}-params"
  description = "DocumentDB cluster parameters"

  parameter {
    name  = "tls"
    value = "enabled"  # Enforce TLS — no plaintext connections
  }

  parameter {
    name  = "audit_logs"
    value = "enabled"  # Audit all operations — required for SOC2
  }

  tags = { Name = "${var.cluster_identifier}-params" }
}

# ── Master Password from AWS Secrets Manager ──────────────────────────────────
resource "random_password" "docdb_master" {
  length           = 32
  special          = true
  override_special = "!#$%&*()-_=+[]{}<>:?"
}

resource "aws_secretsmanager_secret" "docdb_master" {
  name                    = "${var.cluster_identifier}/docdb/master-password"
  description             = "DocumentDB master password for ${var.cluster_identifier}"
  kms_key_id              = aws_kms_key.docdb.arn
  recovery_window_in_days = 30
  tags                    = { Name = "${var.cluster_identifier}-docdb-secret" }
}

resource "aws_secretsmanager_secret_version" "docdb_master" {
  secret_id = aws_secretsmanager_secret.docdb_master.id
  secret_string = jsonencode({
    username = var.master_username
    password = random_password.docdb_master.result
    host     = aws_docdb_cluster.main.endpoint
    port     = 27017
    dbname   = var.database_name
    uri      = "mongodb://${var.master_username}:${random_password.docdb_master.result}@${aws_docdb_cluster.main.endpoint}:27017/${var.database_name}?tls=true&tlsCAFile=global-bundle.pem&replicaSet=rs0&readPreference=secondaryPreferred&retryWrites=false"
  })
}

# ── DocumentDB Cluster ────────────────────────────────────────────────────────
resource "aws_docdb_cluster" "main" {
  cluster_identifier              = var.cluster_identifier
  engine                          = "docdb"
  engine_version                  = "5.0.0"
  master_username                 = var.master_username
  master_password                 = random_password.docdb_master.result
  db_subnet_group_name            = aws_docdb_subnet_group.main.name
  vpc_security_group_ids          = [aws_security_group.docdb.id]
  db_cluster_parameter_group_name = aws_docdb_cluster_parameter_group.main.name

  # Zero-Trust: NO public access
  storage_encrypted               = true
  kms_key_id                      = aws_kms_key.docdb.arn

  # Automated backups
  backup_retention_period         = var.backup_retention_days
  preferred_backup_window         = "03:00-05:00"
  preferred_maintenance_window    = "sun:05:00-sun:07:00"
  skip_final_snapshot             = false
  final_snapshot_identifier       = "${var.cluster_identifier}-final-snapshot"
  deletion_protection             = var.deletion_protection

  # Audit logging to CloudWatch
  enabled_cloudwatch_logs_exports = ["audit", "profiler"]

  tags = { Name = var.cluster_identifier }
}

# ── DocumentDB Instances (Multi-AZ) ──────────────────────────────────────────
resource "aws_docdb_cluster_instance" "main" {
  count              = var.instance_count
  identifier         = "${var.cluster_identifier}-${count.index + 1}"
  cluster_identifier = aws_docdb_cluster.main.id
  instance_class     = var.instance_class

  auto_minor_version_upgrade = true
  tags                       = { Name = "${var.cluster_identifier}-instance-${count.index + 1}" }
}
