output "irsa_role_arns" {
  description = "Map of ServiceAccount name → IAM role ARN (for use in K8s annotations)"
  value       = { for k, v in aws_iam_role.irsa : k => v.arn }
}

# ── Enterprise Jenkins: 4-node typed roles ────────────────────────────────────
output "jenkins_master_profile" {
  description = "IAM instance profile for Jenkins Master Controller"
  value       = aws_iam_instance_profile.jenkins_master.name
}

output "jenkins_build_agent_profile" {
  description = "IAM instance profile for build-agent (Node.js, Git, kustomize)"
  value       = aws_iam_instance_profile.jenkins_build_agent.name
}

output "jenkins_security_agent_profile" {
  description = "IAM instance profile for security-agent (Kaniko, Trivy, ECR push)"
  value       = aws_iam_instance_profile.jenkins_security_agent.name
}

output "jenkins_test_agent_profile" {
  description = "IAM instance profile for test-agent (Docker, Newman, ZAP DAST)"
  value       = aws_iam_instance_profile.jenkins_test_agent.name
}

# ── Legacy single-node profile (used in staging / dev) ───────────────────────
output "jenkins_ec2_role_arn" {
  description = "ARN of the legacy single-node Jenkins EC2 agent IAM role"
  value       = aws_iam_role.jenkins_ec2_agent.arn
}

output "jenkins_ec2_instance_profile_name" {
  description = "Legacy Jenkins EC2 instance profile (staging/dev single-node setup)"
  value       = aws_iam_instance_profile.jenkins_ec2_agent.name
}

output "argocd_ecr_readonly_role_arn" {
  description = "ARN of the read-only ECR role for ArgoCD"
  value       = aws_iam_role.argocd_ecr_readonly.arn
}
