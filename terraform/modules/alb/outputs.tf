output "alb_security_group_id" {
  value = aws_security_group.alb.id
}

output "alb_controller_role_arn" {
  value = aws_iam_role.alb_controller.arn
}

# ACM and WAF are optional (only created when domain_name != "")
# Use try() so outputs return null safely when count = 0

output "acm_certificate_arn" {
  description = "ACM certificate ARN — empty string when no domain_name is set"
  value       = try(aws_acm_certificate.main[0].arn, "")
}

output "waf_acl_arn" {
  description = "WAF Web ACL ARN — empty string when no domain_name is set"
  value       = try(aws_wafv2_web_acl.main[0].arn, "")
}
