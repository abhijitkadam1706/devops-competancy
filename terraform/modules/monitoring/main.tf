# =============================================================================
# Monitoring Module - CloudWatch Alarms + SNS + Prometheus Integration
# Maps to existing prometheus/prometheus-config.yaml in the repo
# =============================================================================

data "aws_region" "current" {}

# ── SNS Topic for Alerts ──────────────────────────────────────────────────────
resource "aws_sns_topic" "alerts" {
  name              = "${var.cluster_name}-alerts"
  kms_master_key_id = "alias/aws/sns"
  tags              = { Name = "${var.cluster_name}-alerts" }
}

resource "aws_sns_topic_subscription" "email" {
  count     = var.alert_email != "" ? 1 : 0
  topic_arn = aws_sns_topic.alerts.arn
  protocol  = "email"
  endpoint  = var.alert_email
}

# ── CloudWatch Log Groups ─────────────────────────────────────────────────────
resource "aws_cloudwatch_log_group" "app" {
  name              = "/mern-auth/${var.environment}/application"
  retention_in_days = 90
  tags              = { Name = "${var.cluster_name}-app-logs" }
}

resource "aws_cloudwatch_log_group" "api" {
  name              = "/mern-auth/${var.environment}/api"
  retention_in_days = 90
  tags              = { Name = "${var.cluster_name}-api-logs" }
}

# ── CloudWatch Alarms — EKS Node ─────────────────────────────────────────────
resource "aws_cloudwatch_metric_alarm" "node_cpu_high" {
  alarm_name          = "${var.cluster_name}-node-cpu-high"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = "2"
  metric_name         = "node_cpu_utilization"
  namespace           = "ContainerInsights"
  period              = "300"
  statistic           = "Average"
  threshold           = "80"
  alarm_description   = "EKS node CPU >80% for 10 minutes"
  alarm_actions       = [aws_sns_topic.alerts.arn]
  ok_actions          = [aws_sns_topic.alerts.arn]
  dimensions          = { ClusterName = var.cluster_name }
}

resource "aws_cloudwatch_metric_alarm" "node_memory_high" {
  alarm_name          = "${var.cluster_name}-node-memory-high"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = "2"
  metric_name         = "node_memory_utilization"
  namespace           = "ContainerInsights"
  period              = "300"
  statistic           = "Average"
  threshold           = "85"
  alarm_description   = "EKS node memory >85% for 10 minutes"
  alarm_actions       = [aws_sns_topic.alerts.arn]
  ok_actions          = [aws_sns_topic.alerts.arn]
  dimensions          = { ClusterName = var.cluster_name }
}

# ── CloudWatch Alarm — Application Error Rate ─────────────────────────────────
resource "aws_cloudwatch_metric_alarm" "app_error_rate" {
  alarm_name          = "${var.cluster_name}-app-error-rate"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = "1"
  metric_name         = "5xxErrorRate"
  namespace           = "AWS/ApplicationELB"
  period              = "60"
  statistic           = "Average"
  threshold           = "5"
  alarm_description   = "App 5xx error rate > 5% — possible issue"
  alarm_actions       = [aws_sns_topic.alerts.arn]
  treat_missing_data  = "notBreaching"
}

# ── CloudWatch Alarm — DocumentDB CPU ────────────────────────────────────────
resource "aws_cloudwatch_metric_alarm" "docdb_cpu" {
  alarm_name          = "${var.cluster_name}-docdb-cpu"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = "3"
  metric_name         = "CPUUtilization"
  namespace           = "AWS/DocDB"
  period              = "300"
  statistic           = "Average"
  threshold           = "70"
  alarm_description   = "DocumentDB CPU >70%"
  alarm_actions       = [aws_sns_topic.alerts.arn]
  dimensions          = { DBClusterIdentifier = var.docdb_cluster_id }
}

# ── CloudWatch Dashboard ──────────────────────────────────────────────────────
resource "aws_cloudwatch_dashboard" "main" {
  dashboard_name = "${var.cluster_name}-ops"

  dashboard_body = jsonencode({
    widgets = [
      {
        type   = "metric"
        x      = 0
        y      = 0
        width  = 12
        height = 6
        properties = {
          title   = "EKS Node CPU"
          region  = data.aws_region.current.name
          metrics = [["ContainerInsights", "node_cpu_utilization", "ClusterName", var.cluster_name]]
          period  = 300
          view    = "timeSeries"
        }
      },
      {
        type   = "metric"
        x      = 12
        y      = 0
        width  = 12
        height = 6
        properties = {
          title   = "App 5xx Error Rate"
          region  = data.aws_region.current.name
          metrics = [["AWS/ApplicationELB", "5xxErrorRate"]]
          period  = 60
          view    = "timeSeries"
        }
      },
      {
        type   = "metric"
        x      = 0
        y      = 6
        width  = 12
        height = 6
        properties = {
          title   = "DocumentDB CPU"
          region  = data.aws_region.current.name
          metrics = [["AWS/DocDB", "CPUUtilization", "DBClusterIdentifier", var.docdb_cluster_id]]
          period  = 300
          view    = "timeSeries"
        }
      }
    ]
  })
}
