# MERN-Auth CI/CD Deployment Guide

> Complete step-by-step guide to deploy and configure the Jenkins CI/CD pipeline,
> EKS cluster, and ArgoCD GitOps for the AWS DevOps Competency case study.

---

## Table of Contents

1. [Prerequisites](#1-prerequisites)
2. [Store Secrets in AWS SSM](#2-store-secrets-in-aws-ssm)
3. [Deploy Infrastructure with Terraform](#3-deploy-infrastructure-with-terraform)
4. [Configure Jenkins (Manual UI Setup)](#4-configure-jenkins-manual-ui-setup)
5. [Configure ArgoCD](#5-configure-argocd)
6. [Create & Run the CI/CD Pipeline](#6-create--run-the-cicd-pipeline)
7. [Verify End-to-End](#7-verify-end-to-end)
8. [Cost Optimization Notes](#8-cost-optimization-notes)

---

## 1. Prerequisites

### Tools Required

| Tool | Version | Purpose |
|------|---------|---------|
| AWS CLI | v2.x | AWS resource management |
| Terraform | >= 1.5 | Infrastructure as Code |
| kubectl | >= 1.30 | Kubernetes management |
| Git | Latest | Source control |

### AWS Account Setup

```bash
# Verify AWS CLI is configured
aws sts get-caller-identity

# Verify region
aws configure get region
# Expected: ap-southeast-1
```

### GitHub Repository

Repository: `https://github.com/abhijitkadam1706/devops-competancy.git`
Branch: `master`

---

## 2. Store Secrets in AWS SSM

All secrets are stored in AWS SSM Parameter Store as `SecureString` (encrypted with KMS).
Jenkins reads these at runtime — **no secrets in code, ever**.

```powershell
# ── SonarCloud Token ─────────────────────────────────────────────────────
# Get from: https://sonarcloud.io → My Account → Security → Generate Token
aws ssm put-parameter `
  --name "/mern-auth-prod/jenkins/sonarcloud-token" `
  --type "SecureString" `
  --value "YOUR_SONARCLOUD_TOKEN" `
  --overwrite `
  --region ap-southeast-1

# ── GitHub Personal Access Token ─────────────────────────────────────────
# Scopes required: repo, write:packages
aws ssm put-parameter `
  --name "/mern-auth-prod/jenkins/github-pat" `
  --type "SecureString" `
  --value "YOUR_GITHUB_PAT" `
  --overwrite `
  --region ap-southeast-1

# ── GitHub Username ──────────────────────────────────────────────────────
aws ssm put-parameter `
  --name "/mern-auth-prod/jenkins/github-username" `
  --type "SecureString" `
  --value "abhijitkadam1706" `
  --overwrite `
  --region ap-southeast-1

# ── JWT Secret (for integration tests) ───────────────────────────────────
aws ssm put-parameter `
  --name "/mern-auth-prod/jenkins/test-jwt-secret" `
  --type "SecureString" `
  --value "$(openssl rand -hex 32)" `
  --overwrite `
  --region ap-southeast-1

# ── MongoDB Password (for integration tests) ─────────────────────────────
aws ssm put-parameter `
  --name "/mern-auth-prod/jenkins/test-mongo-password" `
  --type "SecureString" `
  --value "$(openssl rand -hex 16)" `
  --overwrite `
  --region ap-southeast-1
```

### Verify All Parameters Exist

```powershell
aws ssm describe-parameters `
  --filters "Key=Name,Values=/mern-auth-prod/jenkins/" `
  --region ap-southeast-1 `
  --query "Parameters[].Name" --output table
```

Expected parameters:
- `/mern-auth-prod/jenkins/admin-password` (auto-created by Terraform)
- `/mern-auth-prod/jenkins/agent-ssh-private-key` (auto-created by Terraform)
- `/mern-auth-prod/jenkins/sonarcloud-token`
- `/mern-auth-prod/jenkins/github-pat`
- `/mern-auth-prod/jenkins/github-username`
- `/mern-auth-prod/jenkins/test-jwt-secret`
- `/mern-auth-prod/jenkins/test-mongo-password`

---

## 3. Deploy Infrastructure with Terraform

```powershell
cd terraform/environments/production

# Initialize (downloads providers and modules)
terraform init

# Preview changes
terraform plan -out=tfplan

# Apply infrastructure
terraform apply tfplan
```

### What Gets Created

| Resource | Details |
|----------|---------|
| VPC | 10.0.0.0/16, 2 AZs, public + private subnets |
| EKS Cluster | v1.30, 2 t3.medium nodes, auto-scaling 1–4 |
| Jenkins Master | t3.medium, public subnet, Elastic IP |
| Jenkins Build Agent | t3.medium, private subnet |
| Jenkins Security Agent | t3.medium, private subnet |
| Jenkins Test Agent | t3.medium, private subnet |
| DocumentDB | db.t3.medium, single node |
| ECR Repositories | staging + production |
| CloudWatch | Log groups, alarms, SNS alerts |
| ArgoCD | Helm chart on EKS |
| Prometheus + Grafana | Helm chart on EKS |

### Get Jenkins URL and Password

```powershell
# Jenkins URL (from Terraform output)
terraform output jenkins_master_public_ip

# Admin password (from SSM)
aws ssm get-parameter `
  --name "/mern-auth-prod/jenkins/admin-password" `
  --with-decryption `
  --query "Parameter.Value" `
  --output text `
  --region ap-southeast-1
```

---

## 4. Configure Jenkins (Manual UI Setup)

### 4.1 Login

1. Open browser: `http://<JENKINS_IP>:8080`
2. Login with:
   - Username: `admin`
   - Password: (from SSM, see above)

### 4.2 Complete Plugin Installation

Most plugins are pre-installed via Terraform bootstrap. If any are missing:

1. Go to **Manage Jenkins → Plugins → Available plugins**
2. Search and install any missing plugins:
   - `Pipeline` (workflow-aggregator)
   - `Git`
   - `SSH Build Agents`
   - `SonarQube Scanner`
   - `Credentials Binding`
   - `Role-based Authorization Strategy`
3. Click **Install and restart**

### 4.3 Configure SSH Agents

The SSH private key is already on the master at `/var/lib/jenkins/.ssh/agent_key`.
Agent public keys are pre-installed on all agents by Terraform.

**Get agent private IPs** (from Terraform outputs or AWS Console):

```powershell
terraform output jenkins_build_agent_private_ip
terraform output jenkins_security_agent_private_ip
terraform output jenkins_test_agent_private_ip
```

**Add SSH credential in Jenkins:**

1. Go to **Manage Jenkins → Credentials → System → Global credentials**
2. Click **Add Credentials**
   - Kind: `SSH Username with private key`
   - ID: `jenkins-ssh-agent-key`
   - Username: `jenkins-agent`
   - Private Key: **Enter directly** → paste contents of:
     ```powershell
     aws ssm get-parameter `
       --name "/mern-auth-prod/jenkins/agent-ssh-private-key" `
       --with-decryption `
       --query "Parameter.Value" `
       --output text `
       --region ap-southeast-1
     ```

**Add each agent node:**

For each agent (build-agent, security-agent, test-agent):

1. Go to **Manage Jenkins → Nodes → New Node**
2. Configure:
   - **Name**: `build-agent` (or `security-agent` / `test-agent`)
   - **Remote root directory**: `/home/jenkins-agent/workspace`
   - **Labels**: `build-agent` (or `security-agent` / `test-agent`)
   - **Launch method**: `Launch agents via SSH`
   - **Host**: `<agent-private-ip>`
   - **Credentials**: `jenkins-ssh-agent-key`
   - **Host Key Verification Strategy**: `Non verifying`
3. Save and verify agent comes online

### 4.4 Add Pipeline Credentials

Go to **Manage Jenkins → Credentials → System → Global credentials** and add:

| ID | Kind | Value Source |
|----|------|-------------|
| `sonarqube-token` | Secret text | SSM: `/mern-auth-prod/jenkins/sonarcloud-token` |
| `gitops-repo-creds` | Username/Password | SSM: `github-username` + `github-pat` |
| `test-jwt-secret` | Secret text | SSM: `/mern-auth-prod/jenkins/test-jwt-secret` |
| `test-mongo-password` | Secret text | SSM: `/mern-auth-prod/jenkins/test-mongo-password` |

### 4.5 Configure SonarQube Server

1. Go to **Manage Jenkins → System → SonarQube servers**
2. Click **Add SonarQube**:
   - Name: `SonarQube`
   - Server URL: `https://sonarcloud.io`
   - Server authentication token: `sonarqube-token`
3. Save

### 4.6 Configure Global Environment Variables

1. Go to **Manage Jenkins → System → Global properties**
2. Check **Environment variables**
3. Add the following:

| Name | Value |
|------|-------|
| `AWS_REGION` | `ap-southeast-1` |
| `ECR_REGISTRY` | `203848753188.dkr.ecr.ap-southeast-1.amazonaws.com` |
| `STAGE_REGISTRY` | `203848753188.dkr.ecr.ap-southeast-1.amazonaws.com/mern-auth-prod-staging` |
| `PROD_REGISTRY` | `203848753188.dkr.ecr.ap-southeast-1.amazonaws.com/mern-auth-prod-production` |
| `SONAR_PROJECT` | `mern-auth` |
| `SONAR_ORG` | `abhijitkadam1706` |
| `GITOPS_REPO` | `https://github.com/abhijitkadam1706/devops-competancy.git` |

---

## 5. Configure ArgoCD

### Get ArgoCD URL

```powershell
kubectl get svc -n argocd argocd-server -o jsonpath='{.status.loadBalancer.ingress[0].hostname}'
```

### Get ArgoCD Password

```powershell
kubectl get secret argocd-initial-admin-secret -n argocd -o jsonpath="{.data.password}" | ForEach-Object { [System.Text.Encoding]::UTF8.GetString([System.Convert]::FromBase64String($_)) }
```

### Verify Application Sync

1. Login to ArgoCD UI
2. Verify the `mern-auth` application is syncing from the `master` branch
3. Check that Kubernetes manifests in `gitops/` are being tracked

---

## 6. Create & Run the CI/CD Pipeline

### Create Pipeline Job

1. In Jenkins, click **New Item**
2. Name: `mern-auth-pipeline`
3. Type: **Pipeline**
4. Under **Pipeline**:
   - Definition: `Pipeline script from SCM`
   - SCM: `Git`
   - Repository URL: `https://github.com/abhijitkadam1706/devops-competancy.git`
   - Credentials: `gitops-repo-creds`
   - Branch: `*/master`
   - Script Path: `jenkins-pipeline/Jenkinsfile`
5. Save

### Trigger First Build

1. Click **Build Now**
2. Monitor the pipeline stages:
   - **Stage 1**: Checkout & Build (build-agent)
   - **Stage 2**: Lint & SAST – SonarQube (build-agent)
   - **Stage 3**: Quality Gate (build-agent)
   - **Stage 4**: Container Build – Kaniko + Trivy (security-agent)
   - **Stage 5**: Integration Tests – Newman (test-agent)
   - **Stage 6**: DAST – OWASP ZAP (test-agent)
   - **Stage 7**: GitOps Commit (build-agent)

---

## 7. Verify End-to-End

### Checklist

- [ ] Jenkins UI accessible at `http://<EIP>:8080`
- [ ] All 3 agents online (build, security, test)
- [ ] Pipeline job created and linked to Jenkinsfile
- [ ] First build completes successfully
- [ ] SonarQube analysis visible at `https://sonarcloud.io`
- [ ] Container image pushed to ECR
- [ ] ArgoCD detects GitOps commit and syncs Kubernetes manifests
- [ ] Application pods running in EKS
- [ ] Grafana dashboards showing metrics
- [ ] CloudWatch alarms configured and SNS email verified

---

## 8. Cost Optimization Notes

| Resource | Monthly Estimate |
|----------|-----------------|
| EKS Cluster | ~$73 (control plane) |
| EKS Nodes (2× t3.medium) | ~$60 |
| Jenkins Master (t3.medium) | ~$30 |
| Jenkins Agents (3× t3.medium) | ~$90 |
| DocumentDB (t3.medium) | ~$60 |
| NAT Gateway | ~$32 |
| **Total Estimate** | **~$345/month** |

> **Tip**: To minimize costs during non-working hours, stop Jenkins agent EC2 instances
> and scale EKS nodes to 0 via `aws autoscaling` commands.
