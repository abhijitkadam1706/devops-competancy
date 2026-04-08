# =============================================================================
# Production Environment — Outputs
# Run `terraform output` after apply to get all connection strings and IDs.
# Run `terraform output -json` for machine-readable format (CI/CD automation).
# =============================================================================

# ── ❶ Jenkins CI/CD ──────────────────────────────────────────────────────────

output "jenkins_ui_url" {
  description = "Jenkins Web UI — open this in your browser to access the dashboard"
  value       = "http://${module.jenkins.master_public_ip}:8080"
}

output "jenkins_master_public_ip" {
  description = "Elastic IP of Jenkins Master — stable across reboots"
  value       = module.jenkins.master_public_ip
}

output "jenkins_master_private_ip" {
  description = "Private IP of Jenkins Master (use SSM Session Manager to connect)"
  value       = module.jenkins.master_private_ip
}

output "jenkins_master_instance_id" {
  description = "EC2 Instance ID — use with SSM: aws ssm start-session --target <ID>"
  value       = module.jenkins.master_instance_id
}

output "jenkins_build_agent_ip" {
  description = "Private IP — build-agent (Node.js 20, Git, kustomize)"
  value       = module.jenkins.build_agent_private_ip
}

output "jenkins_security_agent_ip" {
  description = "Private IP — security-agent (Kaniko, Trivy, Cosign, ECR push)"
  value       = module.jenkins.security_agent_private_ip
}

output "jenkins_test_agent_ip" {
  description = "Private IP — test-agent (Docker, Newman/Postman, OWASP ZAP)"
  value       = module.jenkins.test_agent_private_ip
}

output "jenkins_agent_ssh_key_ssm_path" {
  description = "SSM path for agent SSH private key — paste this into Jenkins > Credentials"
  value       = module.jenkins.agent_ssh_private_key_ssm_path
}

output "jenkins_security_group_id" {
  description = "Security Group ID of Jenkins Master — add your IP here to restrict port 8080"
  value       = module.jenkins.jenkins_security_group_id
}

# ── ❷ EKS Cluster ────────────────────────────────────────────────────────────

output "eks_cluster_name" {
  description = "EKS cluster name — use in: aws eks update-kubeconfig --name <NAME>"
  value       = module.eks.cluster_name
}

output "eks_cluster_endpoint" {
  description = "Kubernetes API server endpoint"
  value       = module.eks.cluster_endpoint
}

output "eks_oidc_provider_arn" {
  description = "OIDC provider ARN — used for IRSA role trust policies"
  value       = module.eks.oidc_provider_arn
}

output "eks_oidc_issuer_url" {
  description = "OIDC issuer URL — reference for IAM assume-role conditions"
  value       = module.eks.cluster_oidc_issuer_url
}

output "kubeconfig_command" {
  description = "Run this command to configure kubectl for this cluster"
  value       = "aws eks update-kubeconfig --name ${module.eks.cluster_name} --region ap-southeast-1"
}

# ── ❸ ECR Container Registries ───────────────────────────────────────────────

output "ecr_stage_registry_url" {
  description = "ECR staging registry URL — used in Jenkinsfile STAGE_REGISTRY variable"
  value       = aws_ecr_repository.stage.repository_url
}

output "ecr_prod_registry_url" {
  description = "ECR production registry URL — used in Jenkinsfile PROD_REGISTRY variable"
  value       = aws_ecr_repository.prod.repository_url
}

output "ecr_login_command" {
  description = "Run this to authenticate Docker/Kaniko to ECR"
  value       = "aws ecr get-login-password --region ap-southeast-1 | docker login --username AWS --password-stdin ${split("/", aws_ecr_repository.prod.repository_url)[0]}"
}

# ── ❹ DocumentDB (MongoDB-compatible) ────────────────────────────────────────

output "docdb_cluster_endpoint" {
  description = "Primary write endpoint — use in MONGODB_URI for API server"
  value       = module.documentdb.cluster_endpoint
}

output "docdb_reader_endpoint" {
  description = "Read replica endpoint — use for analytics / reporting queries"
  value       = module.documentdb.reader_endpoint
}

output "docdb_secret_arn" {
  description = "Secrets Manager ARN containing the master password — used by IRSA app role"
  value       = module.documentdb.secret_arn
}

output "docdb_mongodb_uri_template" {
  description = "MongoDB URI template — replace <PASSWORD> with the value from Secrets Manager"
  value       = "mongodb://mern-auth-admin:<PASSWORD>@${module.documentdb.cluster_endpoint}:27017/mern-auth?tls=true&tlsCAFile=rds-combined-ca-bundle.pem&replicaSet=rs0&readPreference=secondaryPreferred&retryWrites=false"
}

# ── ❺ IAM Roles (IRSA + Agent Profiles) ─────────────────────────────────────

output "irsa_role_arns" {
  description = "Map of K8s ServiceAccount → IAM Role ARN — paste into K8s serviceaccount annotation"
  value       = module.iam.irsa_role_arns
}

output "argocd_ecr_readonly_role_arn" {
  description = "ArgoCD ECR read-only role ARN — annotate the argocd-image-updater ServiceAccount with this"
  value       = module.iam.argocd_ecr_readonly_role_arn
}

# ── ❻ Networking & Security ──────────────────────────────────────────────────

output "vpc_id" {
  description = "VPC ID — reference for security group and subnet lookups"
  value       = module.vpc.vpc_id
}

output "waf_acl_arn" {
  description = "WAF Web ACL ARN — associate this with the ALB Ingress annotation"
  value       = module.alb.waf_acl_arn
}

output "alb_controller_role_arn" {
  description = "ALB Controller IRSA role ARN — annotate the aws-load-balancer-controller ServiceAccount"
  value       = module.alb.alb_controller_role_arn
}

# ── ❼ Post-Deploy Quick-Start ─────────────────────────────────────────────────

output "next_steps" {
  description = "Operational quick-start — run these commands after a fresh apply"
  value       = <<-EOT

  ╔══════════════════════════════════════════════════════════════════╗
  ║           POST-DEPLOY QUICK-START (mern-auth-prod)              ║
  ╚══════════════════════════════════════════════════════════════════╝

  1. Configure kubectl:
     aws eks update-kubeconfig --name ${module.eks.cluster_name} --region ap-southeast-1

  2. Open Jenkins UI:
     http://${module.jenkins.master_public_ip}:8080
     (Initial password: cat /var/lib/jenkins/secrets/initialAdminPassword via SSM)

  3. Connect to Jenkins Master via SSM (no SSH key needed):
     aws ssm start-session --target ${module.jenkins.master_instance_id} --region ap-southeast-1

  4. Retrieve DocDB master password:
     aws secretsmanager get-secret-value --secret-id "${module.documentdb.secret_arn}" --query SecretString --output text --region ap-southeast-1

  5. Authenticate Docker to ECR:
     aws ecr get-login-password --region ap-southeast-1 | docker login --username AWS --password-stdin ${split("/", aws_ecr_repository.prod.repository_url)[0]}

  EOT
}
