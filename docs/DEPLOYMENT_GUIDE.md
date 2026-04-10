# MERN-Auth CI/CD Deployment Guide

> **Who is this for?** Anyone who needs to set up this project from scratch — even if you are not
> deeply technical. Every step is explained in plain English with exact commands to copy-paste.

---

## Table of Contents

1. [Before You Start (Prerequisites)](#1-before-you-start-prerequisites)
2. [Store Secrets in AWS (SSM Parameter Store)](#2-store-secrets-in-aws-ssm-parameter-store)
3. [Deploy the Infrastructure with Terraform](#3-deploy-the-infrastructure-with-terraform)
4. [Set Up Jenkins (Manual — Step by Step)](#4-set-up-jenkins-manual--step-by-step)
5. [Set Up ArgoCD (GitOps Deployment)](#5-set-up-argocd-gitops-deployment)
6. [Create and Run the CI/CD Pipeline](#6-create-and-run-the-cicd-pipeline)
7. [Verify Everything is Working](#7-verify-everything-is-working)
8. [Monthly Cost Estimate](#8-monthly-cost-estimate)

---

## 1. Before You Start (Prerequisites)

### Tools You Need on Your Laptop

Install these tools before doing anything else:

| Tool | Why You Need It | Installation |
|------|----------------|-------------|
| **AWS CLI v2** | To talk to AWS from your terminal | [Download here](https://docs.aws.amazon.com/cli/latest/userguide/getting-started-install.html) |
| **Terraform ≥ 1.5** | To create all AWS infrastructure | [Download here](https://developer.hashicorp.com/terraform/install) |
| **kubectl ≥ 1.30** | To manage the Kubernetes cluster | [Download here](https://kubernetes.io/docs/tasks/tools/) |
| **Git** | To push code changes | [Download here](https://git-scm.com/) |

### Check AWS CLI is Working

Open PowerShell and run:

```powershell
aws sts get-caller-identity
```

You should see your AWS account ID, user name, and ARN. If you see an error, run `aws configure` first.

```powershell
# Make sure you are in the right region
aws configure get region
# Should show: ap-southeast-1
```

### GitHub Details

- **Repository URL:** `https://github.com/abhijitkadam1706/devops-competancy.git`
- **Branch:** `master`

---

## 2. Store Secrets in AWS (SSM Parameter Store)

> **Why?** Secrets like passwords and tokens must never be written in code files. We store them
> securely in AWS SSM Parameter Store, encrypted with KMS. Jenkins reads them at runtime.

Open PowerShell and run each command below. Replace `YOUR_...` with your actual values.

```powershell
# ── 1. SonarCloud Token ──────────────────────────────────────────────────────
# How to get this:
#   1. Go to https://sonarcloud.io
#   2. Click your profile picture → My Account → Security
#   3. Click "Generate Token", give it a name, copy the token
aws ssm put-parameter `
  --name "/mern-auth-prod/jenkins/sonarcloud-token" `
  --type "SecureString" `
  --value "YOUR_SONARCLOUD_TOKEN" `
  --overwrite `
  --region ap-southeast-1

# ── 2. GitHub Personal Access Token (PAT) ────────────────────────────────────
# How to get this:
#   1. Go to GitHub → Settings → Developer settings → Personal access tokens → Tokens (classic)
#   2. Click "Generate new token (classic)"
#   3. Select scopes: repo, write:packages
#   4. Copy the token
aws ssm put-parameter `
  --name "/mern-auth-prod/jenkins/github-pat" `
  --type "SecureString" `
  --value "YOUR_GITHUB_PAT" `
  --overwrite `
  --region ap-southeast-1

# ── 3. GitHub Username ────────────────────────────────────────────────────────
aws ssm put-parameter `
  --name "/mern-auth-prod/jenkins/github-username" `
  --type "SecureString" `
  --value "abhijitkadam1706" `
  --overwrite `
  --region ap-southeast-1

# ── 4. JWT Secret (random, for integration tests) ────────────────────────────
# This is auto-generated — just copy and run this command as-is
aws ssm put-parameter `
  --name "/mern-auth-prod/jenkins/test-jwt-secret" `
  --type "SecureString" `
  --value "$(openssl rand -hex 32)" `
  --overwrite `
  --region ap-southeast-1

# ── 5. MongoDB Password (random, for integration tests) ──────────────────────
aws ssm put-parameter `
  --name "/mern-auth-prod/jenkins/test-mongo-password" `
  --type "SecureString" `
  --value "$(openssl rand -hex 16)" `
  --overwrite `
  --region ap-southeast-1

# ── 6. Cosign Private Key (for image signing) ─────────────────────────────────
# How to generate a cosign keypair (run once on your laptop):
#   cosign generate-key-pair
# This creates cosign.key and cosign.pub — store the private key in SSM:
aws ssm put-parameter `
  --name "/mern-auth-prod/jenkins/cosign-private-key" `
  --type "SecureString" `
  --value (Get-Content cosign.key -Raw) `
  --overwrite `
  --region ap-southeast-1

# ── 7. Cosign Key Password ────────────────────────────────────────────────────
# This is the password you set when running cosign generate-key-pair
aws ssm put-parameter `
  --name "/mern-auth-prod/jenkins/cosign-key-password" `
  --type "SecureString" `
  --value "YOUR_COSIGN_PASSWORD" `
  --overwrite `
  --region ap-southeast-1
```

### ✅ Confirm All Parameters Are Stored

```powershell
aws ssm describe-parameters `
  --filters "Key=Path,Values=/mern-auth-prod/jenkins" `
  --region ap-southeast-1 `
  --query "Parameters[].Name" --output table
```

You should see these in the list:

| Parameter | Created By |
|-----------|-----------|
| `/mern-auth-prod/jenkins/admin-password` | Terraform (auto-created) |
| `/mern-auth-prod/jenkins/agent-ssh-private-key` | Terraform (auto-created) |
| `/mern-auth-prod/jenkins/sonarcloud-token` | You (step 1) |
| `/mern-auth-prod/jenkins/github-pat` | You (step 2) |
| `/mern-auth-prod/jenkins/github-username` | You (step 3) |
| `/mern-auth-prod/jenkins/test-jwt-secret` | You (step 4) |
| `/mern-auth-prod/jenkins/test-mongo-password` | You (step 5) |
| `/mern-auth-prod/jenkins/cosign-private-key` | You (step 6) |
| `/mern-auth-prod/jenkins/cosign-key-password` | You (step 7) |

---

## 3. Deploy the Infrastructure with Terraform

```powershell
# Move into the production directory
cd terraform/environments/production

# Step 1: Download all required Terraform providers and modules
terraform init

# Step 2: Preview what will be created (nothing is built yet)
terraform plan -out=tfplan

# Step 3: Build everything on AWS (this takes 15–25 minutes)
terraform apply tfplan
```

> **Important:** After `terraform apply` finishes, it will print output values. Copy these — you
> will need the Jenkins IP and agent private IPs in the next step.

### What Gets Created on AWS

| Resource | Type | Notes |
|----------|------|-------|
| VPC | Network | `10.0.0.0/16`, 2 AZs, isolated subnets |
| EKS Cluster | Kubernetes | v1.30, 2× `t3.medium` nodes |
| Jenkins Master | EC2 `t3.medium` | Public subnet — this is where you log in |
| Jenkins Build Agent | EC2 `t3.medium` | Private subnet — runs builds |
| Jenkins Security Agent | EC2 `t3.medium` | Private subnet — runs Docker/Trivy/Cosign |
| Jenkins Test Agent | EC2 `t3.medium` | Private subnet — runs tests and ZAP |
| DocumentDB | `db.t3.medium` | MongoDB-compatible, encrypted, private |
| ECR Repositories | Container Registry | `mern-auth/stage` + `mern-auth/prod` + `kaniko-cache` |
| CloudWatch | Monitoring | Log groups, alarms, SNS email alerts |
| ArgoCD | Helm on EKS | GitOps deployment controller |
| Prometheus + Grafana | Helm on EKS | Metrics dashboards |
| AWS WAF | Security | Blocks common web attacks on the ALB |

### Get Your Jenkins URL and Password

```powershell
# Get the Jenkins IP address
terraform output jenkins_master_public_ip

# Get the auto-generated admin password
aws ssm get-parameter `
  --name "/mern-auth-prod/jenkins/admin-password" `
  --with-decryption `
  --query "Parameter.Value" `
  --output text `
  --region ap-southeast-1
```

---

## 4. Set Up Jenkins (Manual — Step by Step)

> **Jenkins is set up manually through a web browser.** There is no auto-configuration.
> Follow each step exactly.

### 4.1 Log In to Jenkins

1. Open your browser and go to: `http://<JENKINS_IP>:8080`
   *(Replace `<JENKINS_IP>` with the public IP from the terraform output)*
2. Enter credentials:
   - **Username:** `admin`
   - **Password:** *(the value you retrieved from SSM above)*

### 4.2 Install Missing Plugins (if prompted)

If Jenkins shows a plugin page:

1. Click **"Install suggested plugins"** and wait for it to finish
2. After restart, go to **Manage Jenkins → Plugins → Available plugins**
3. Search for and install these (if not already installed):
   - `Pipeline` *(search for "workflow-aggregator")*
   - `Git`
   - `SSH Build Agents`
   - `SonarQube Scanner`
   - `AnsiColor`
   - `Credentials Binding`
4. Click **"Install"** and wait, then restart Jenkins

### 4.3 Connect the SSH Agent Key (Credential)

First, get the SSH private key that Terraform generated:

```powershell
aws ssm get-parameter `
  --name "/mern-auth-prod/jenkins/agent-ssh-private-key" `
  --with-decryption `
  --query "Parameter.Value" `
  --output text `
  --region ap-southeast-1
```

Copy the full output (including `-----BEGIN...` and `-----END...` lines).

Now in Jenkins:

1. Go to **Manage Jenkins → Credentials → System → Global credentials (unrestricted)**
2. Click **"Add Credentials"**
3. Fill in:
   - **Kind:** `SSH Username with private key`
   - **ID:** `jenkins-ssh-agent-key`
   - **Username:** `jenkins-agent`
   - **Private Key:** Select "Enter directly" → paste the key you copied
4. Click **Save**

### 4.4 Add the Three Agent Nodes

First, get the private IP addresses of each agent:

```powershell
terraform output jenkins_build_agent_private_ip
terraform output jenkins_security_agent_private_ip
terraform output jenkins_test_agent_private_ip
```

For **each** of the three agents, do the following in Jenkins:

1. Go to **Manage Jenkins → Nodes → New Node**
2. Enter a node name and choose "Permanent Agent"

**Build Agent settings:**

| Field | Value |
|-------|-------|
| Name | `build-agent` |
| Remote root directory | `/home/jenkins-agent/workspace` |
| Labels | `build-agent` |
| Launch method | `Launch agents via SSH` |
| Host | *(build agent private IP)* |
| Credentials | `jenkins-ssh-agent-key` |
| Host Key Verification Strategy | `Non verifying Verification Strategy` |

Repeat for **security-agent** and **test-agent** using their respective IPs and labels.

3. Click **Save** → the agent should show as **Connected** within 30 seconds.

### 4.5 Add Pipeline Credentials

Go to **Manage Jenkins → Credentials → System → Global credentials** and add each one:

| Credential ID | Kind | What to Put |
|---------------|------|-------------|
| `sonarqube-token` | Secret text | Your SonarCloud token (from SSM) |
| `gitops-repo-creds` | Username and password | GitHub username + PAT (from SSM) |
| `test-jwt-secret` | Secret text | JWT secret (from SSM) |
| `test-mongo-password` | Secret text | Mongo password (from SSM) |
| `cosign-private-key` | Secret text | Cosign private key content (from SSM) |
| `cosign-key-password` | Secret text | Cosign key password (from SSM) |

### 4.6 Configure the SonarQube Server Connection

1. Go to **Manage Jenkins → System**
2. Scroll down to **"SonarQube servers"** section
3. Click **Add SonarQube**:
   - **Name:** `SonarQube` *(must be exactly this — the Jenkinsfile uses this name)*
   - **Server URL:** `https://sonarcloud.io`
   - **Server authentication token:** select `sonarqube-token`
4. Click **Save**

### 4.7 Configure Global Environment Variables

These values tell the pipeline where ECR is, what region, etc. You can find the ECR values from Terraform output or the AWS Console.

1. Go to **Manage Jenkins → System**
2. Scroll to **"Global properties"** → tick **"Environment variables"**
3. Add the following name/value pairs:

| Name | Value |
|------|-------|
| `AWS_REGION` | `ap-southeast-1` |
| `ECR_REGISTRY` | `<ACCOUNT_ID>.dkr.ecr.ap-southeast-1.amazonaws.com` |
| `STAGE_REGISTRY` | `<ACCOUNT_ID>.dkr.ecr.ap-southeast-1.amazonaws.com/mern-auth/stage` |
| `PROD_REGISTRY` | `<ACCOUNT_ID>.dkr.ecr.ap-southeast-1.amazonaws.com/mern-auth/prod` |
| `SONAR_PROJECT` | `mern-auth` |
| `SONAR_ORG` | `abhijitkadam1706` |
| `GITOPS_REPO` | `https://github.com/abhijitkadam1706/devops-competancy.git` |

> **How to find your ACCOUNT_ID:**
> ```powershell
> aws sts get-caller-identity --query Account --output text
> ```

4. Click **Save**

---

## 5. Set Up ArgoCD (GitOps Deployment)

ArgoCD was automatically installed by Terraform. You just need to log in and verify it is working.

### Get the ArgoCD URL

```powershell
kubectl get svc -n argocd argocd-server -o jsonpath='{.status.loadBalancer.ingress[0].hostname}'
```

### Get the ArgoCD Login Password

```powershell
kubectl get secret argocd-initial-admin-secret -n argocd `
  -o jsonpath="{.data.password}" | `
  ForEach-Object { [System.Text.Encoding]::UTF8.GetString([System.Convert]::FromBase64String($_)) }
```

### Verify it is Working

1. Open the ArgoCD URL in your browser
2. Log in with username `admin` and the password above
3. You should see two applications: `mern-auth-staging` and `mern-auth-production`
4. Both should show status **"Synced"** (or "OutOfSync" until first pipeline run — that is normal)

---

## 6. Create and Run the CI/CD Pipeline

### Create the Pipeline Job in Jenkins

1. On the Jenkins home page, click **"New Item"**
2. Enter name: `mern-auth-pipeline`
3. Select **"Pipeline"** and click **OK**
4. Under **"Build Triggers"**, check **"GitHub hook trigger for GITScm polling"**
5. Under **"Pipeline"**, configure:
   - **Definition:** `Pipeline script from SCM`
   - **SCM:** `Git`
   - **Repository URL:** `https://github.com/abhijitkadam1706/devops-competancy.git`
   - **Credentials:** `gitops-repo-creds`
   - **Branch:** `*/master`
   - **Script Path:** `jenkins-pipeline/Jenkinsfile`
6. Click **Save**

### Run Your First Build

1. Click **"Build Now"** on the pipeline page
2. Watch the stages run in the **Stage View** (or Blue Ocean if installed):

| Stage | Agent | What Happens |
|-------|-------|-------------|
| **Stage 1: Checkout & Test** | build-agent | Downloads code, installs npm packages, runs unit tests |
| **Stage 2: Lint & SAST** | build-agent | ESLint check + SonarCloud security scan |
| **Stage 3: Quality Gate** | build-agent | Waits for SonarCloud result, checks coverage ≥ 80% |
| **Stage 4: Container Build & Sign** | security-agent | Builds Docker image (Kaniko), scans for CVEs (Trivy), signs image (Cosign) |
| **Stage 5: Integration Tests & DAST** | test-agent | Starts app + MongoDB in Docker, runs API tests (Newman), OWASP ZAP scan |
| **Stage 6: DAST Quality Gate** | test-agent | Fails pipeline if ZAP finds HIGH-risk issues |
| **Stage 7: Update GitOps** | build-agent | Commits new image tag to `gitops/staging` → ArgoCD deploys automatically |

> **First run takes ~25-35 minutes.** Subsequent runs are faster.

---

## 7. Verify Everything is Working

Go through this checklist after the first successful pipeline run:

- [ ] Jenkins at `http://<EIP>:8080` shows green build
- [ ] All 3 agent nodes show "Connected" in **Manage Jenkins → Nodes**
- [ ] Pipeline completed with all 7 stages green
- [ ] SonarCloud at `https://sonarcloud.io` shows new analysis for your project
- [ ] AWS ECR Console shows a new container image tagged with the build number
- [ ] ArgoCD shows the staging app as "Synced" and "Healthy"
- [ ] `kubectl get pods -n mern-auth-staging` shows pods in **Running** state
- [ ] Grafana dashboard shows live metrics from the app
- [ ] CloudWatch Alarms are all in **OK** state

---

## 8. Monthly Cost Estimate

> **All resources are right-sized for a case study.** You are NOT paying for enterprise scale.

| Resource | Size | Monthly Cost |
|----------|------|-------------|
| EKS Control Plane | Managed | ~$73 |
| EKS Worker Nodes (2× t3.medium) | On-Demand | ~$60 |
| Jenkins Master (t3.medium) | On-Demand | ~$30 |
| Jenkins Agents (3× t3.medium) | On-Demand | ~$90 |
| DocumentDB (db.t3.medium, 1 node) | On-Demand | ~$60 |
| NAT Gateways (2× AZ) | Per hour + data | ~$65 |
| ECR Storage | Per GB | ~$2 |
| CloudWatch + ALB | Usage-based | ~$15 |
| **Estimated Total** | | **~$395/month** |

### 💡 Save Money During Off-Hours

Stop Jenkins agents and scale down EKS when not working:

```powershell
# Stop all Jenkins agent EC2 instances
aws ec2 describe-instances --filters "Name=tag:Role,Values=jenkins-agent" `
  --query "Reservations[].Instances[].InstanceId" --output text | `
  ForEach-Object { aws ec2 stop-instances --instance-ids $_ --region ap-southeast-1 }

# Scale EKS node group to 0 (stops EC2 costs for nodes)
aws eks update-nodegroup-config `
  --cluster-name mern-auth-prod `
  --nodegroup-name mern-auth-prod-node-group `
  --scaling-config minSize=0,maxSize=4,desiredSize=0 `
  --region ap-southeast-1
```
