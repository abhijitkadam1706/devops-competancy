output "alb_security_group_id" {
  value = aws_security_group.alb.id
}

output "alb_controller_role_arn" {
  value = aws_iam_role.alb_controller.arn
}

# ACM is optional (only created when domain_name != ""), WAF is always created.
output "acm_certificate_arn" {
  description = "ACM certificate ARN — empty string when no domain_name is set"
  value       = try(aws_acm_certificate.main[0].arn, "")
}

output "waf_acl_arn" {
  description = "WAF Web ACL ARN — always provisioned (mandatory security control)"
  value       = aws_wafv2_web_acl.main.arn
}
