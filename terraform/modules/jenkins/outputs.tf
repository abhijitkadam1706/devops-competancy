# =============================================================================
# Jenkins Module — Outputs
# =============================================================================

output "master_private_ip" {
  description = "Private IP of Jenkins Master (use SSM Session Manager to access)"
  value       = aws_instance.jenkins_master.private_ip
}

output "master_public_ip" {
  description = "Public IP of Jenkins Master — access the UI at http://THIS_IP:8080"
  value       = aws_eip.jenkins_master_eip.public_ip
}

output "build_agent_private_ip" {
  description = "Private IP of build-agent (Node.js/Git/kustomize)"
  value       = aws_instance.build_agent.private_ip
}

output "security_agent_private_ip" {
  description = "Private IP of security-agent (Kaniko/Trivy)"
  value       = aws_instance.security_agent.private_ip
}

output "test_agent_private_ip" {
  description = "Private IP of test-agent (Docker/Newman/ZAP)"
  value       = aws_instance.test_agent.private_ip
}

output "master_instance_id" {
  description = "Instance ID for SSM Session Manager connect"
  value       = aws_instance.jenkins_master.id
}

output "agent_ssh_public_key" {
  description = "Public SSH key — stored in all agent nodes' authorized_keys"
  value       = tls_private_key.jenkins_agent_ssh.public_key_openssh
  sensitive   = false
}

output "agent_ssh_private_key_ssm_path" {
  description = "Path in AWS SSM Parameter Store where the agent SSH private key is stored. Use this in Jenkins SSH credential configuration."
  value       = aws_ssm_parameter.jenkins_ssh_private_key.name
}

output "jenkins_security_group_id" {
  description = "Security Group controlling Jenkins Master inbound traffic"
  value       = aws_security_group.jenkins_master_sg.id
}
