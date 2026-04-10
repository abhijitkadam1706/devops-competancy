# =============================================================================
# Monitoring Module — Outputs
# =============================================================================

output "sns_alerts_topic_arn" {
  description = "ARN of the SNS topic used for CloudWatch alarm notifications"
  value       = aws_sns_topic.alerts.arn
}

output "grafana_admin_password_ssm_path" {
  description = "SSM Parameter path for Grafana admin password — retrieve with --with-decryption"
  value       = aws_ssm_parameter.grafana_admin_password.name
}

output "cloudwatch_dashboard_url" {
  description = "URL of the CloudWatch operations dashboard"
  value       = "https://console.aws.amazon.com/cloudwatch/home#dashboards:name=${aws_cloudwatch_dashboard.main.dashboard_name}"
}
