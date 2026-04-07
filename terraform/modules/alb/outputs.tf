output "alb_security_group_id"      { value = aws_security_group.alb.id }
output "alb_controller_role_arn"    { value = aws_iam_role.alb_controller.arn }
output "acm_certificate_arn"        { value = aws_acm_certificate.main.arn }
output "waf_acl_arn"                { value = aws_wafv2_web_acl.main.arn }
