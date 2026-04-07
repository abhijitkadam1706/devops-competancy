output "irsa_role_arns" {
  description = "Map of ServiceAccount name → IAM role ARN (for use in K8s annotations)"
  value       = { for k, v in aws_iam_role.irsa : k => v.arn }
}

output "jenkins_ec2_role_arn" {
  description = "ARN of the Jenkins EC2 agent IAM role"
  value       = aws_iam_role.jenkins_ec2_agent.arn
}

output "jenkins_ec2_instance_profile_name" {
  description = "Name of the Jenkins EC2 instance profile — attach this to your Jenkins EC2 machine"
  value       = aws_iam_instance_profile.jenkins_ec2_agent.name
}

output "argocd_ecr_readonly_role_arn" {
  description = "ARN of the read-only ECR role for ArgoCD"
  value       = aws_iam_role.argocd_ecr_readonly.arn
}
