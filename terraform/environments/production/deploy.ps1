# =============================================================================
# deploy.ps1 — Single-Command Infrastructure Deployment
#
# PURPOSE: Handles the Terraform "chicken and egg" problem automatically.
#
# PROBLEM:
#   The Kubernetes/Helm/kubectl providers need to connect to the EKS cluster.
#   On a FRESH deployment, the cluster doesn't exist yet, so these providers
#   fail on the first `terraform apply`. This script solves it by deploying
#   in two phases:
#
#   Phase 1: Create VPC + EKS + IAM + Jenkins (no k8s resources)
#   Phase 2: Create Monitoring + ArgoCD + k8s annotations (needs EKS)
#
# USAGE:
#   cd terraform/environments/production
#   .\deploy.ps1
#
# AWS DevOps Competency Control: PRIAC-001 (Templated Infrastructure)
# =============================================================================

$ErrorActionPreference = "Stop"

Write-Host ""
Write-Host "============================================================" -ForegroundColor Cyan
Write-Host "  MERN-Auth Production — Automated Deployment" -ForegroundColor Cyan
Write-Host "  AWS DevOps Competency Case Study" -ForegroundColor Cyan
Write-Host "============================================================" -ForegroundColor Cyan
Write-Host ""

# ── Preflight Checks ─────────────────────────────────────────────────────────

Write-Host "[Preflight] Checking required tools..." -ForegroundColor Yellow

$tools = @("aws", "terraform", "kubectl")
foreach ($tool in $tools) {
    if (-not (Get-Command $tool -ErrorAction SilentlyContinue)) {
        Write-Host "ERROR: '$tool' is not installed or not in PATH." -ForegroundColor Red
        exit 1
    }
}

# Verify AWS credentials
Write-Host "[Preflight] Verifying AWS credentials..." -ForegroundColor Yellow
$identity = aws sts get-caller-identity --output json 2>&1
if ($LASTEXITCODE -ne 0) {
    Write-Host "ERROR: AWS CLI is not configured. Run 'aws configure' first." -ForegroundColor Red
    exit 1
}
$accountId = ($identity | ConvertFrom-Json).Account
Write-Host "  AWS Account: $accountId" -ForegroundColor Green

# ── Phase 0: Terraform Init ──────────────────────────────────────────────────

Write-Host ""
Write-Host "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" -ForegroundColor DarkGray
Write-Host "  PHASE 0/3 — Terraform Init" -ForegroundColor Cyan
Write-Host "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" -ForegroundColor DarkGray
Write-Host ""

terraform init
if ($LASTEXITCODE -ne 0) {
    Write-Host "ERROR: terraform init failed." -ForegroundColor Red
    exit 1
}

# ── Phase 1: Core Infrastructure (VPC, EKS, IAM, Jenkins, DocumentDB) ────────
#
# WHY TARGETED: The Kubernetes/Helm providers read ~/.kube/config at plan time.
# On a fresh deployment, the EKS cluster doesn't exist yet, so the kubeconfig
# has no valid context. Deploying core infra first creates the cluster and
# populates the kubeconfig via null_resource.update_kubeconfig.

Write-Host ""
Write-Host "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" -ForegroundColor DarkGray
Write-Host "  PHASE 1/3 — Core Infrastructure (VPC, EKS, IAM, Jenkins)" -ForegroundColor Cyan
Write-Host "  Estimated time: 15–20 minutes" -ForegroundColor Gray
Write-Host "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" -ForegroundColor DarkGray
Write-Host ""

terraform apply -auto-approve `
    -target=module.vpc `
    -target=module.eks `
    -target=module.iam `
    -target=module.jenkins `
    -target=module.documentdb `
    -target=null_resource.update_kubeconfig `
    -target=aws_ecr_repository.stage `
    -target=aws_ecr_repository.prod `
    -target=aws_ecr_repository.kaniko_cache `
    -target=aws_ecr_lifecycle_policy.stage `
    -target=aws_ecr_lifecycle_policy.prod `
    -target=aws_ecr_lifecycle_policy.kaniko_cache `
    -target=aws_ssm_parameter.ecr_registry `
    -target=aws_ssm_parameter.ecr_stage_repo `
    -target=aws_ssm_parameter.ecr_prod_repo

if ($LASTEXITCODE -ne 0) {
    Write-Host "ERROR: Phase 1 failed. Check the error above and retry." -ForegroundColor Red
    exit 1
}

Write-Host ""
Write-Host "  ✓ Phase 1 complete — EKS cluster is live" -ForegroundColor Green
Write-Host ""

# ── Phase 2: Refresh kubeconfig ──────────────────────────────────────────────
#
# The null_resource.update_kubeconfig should have already done this, but we
# do it explicitly here to guarantee the config is fresh before Phase 3.

Write-Host ""
Write-Host "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" -ForegroundColor DarkGray
Write-Host "  PHASE 2/3 — Refresh kubeconfig" -ForegroundColor Cyan
Write-Host "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" -ForegroundColor DarkGray
Write-Host ""

$clusterName = terraform output -raw eks_cluster_name
$region = "ap-southeast-1"

Write-Host "  Updating kubeconfig for cluster: $clusterName" -ForegroundColor Yellow
aws eks update-kubeconfig --region $region --name $clusterName
if ($LASTEXITCODE -ne 0) {
    Write-Host "ERROR: Failed to update kubeconfig." -ForegroundColor Red
    exit 1
}

# Flush DNS cache (Windows caches old EKS endpoint IPs)
Write-Host "  Flushing DNS cache..." -ForegroundColor Yellow
Clear-DnsClientCache

# Wait for cluster API to be ready
Write-Host "  Waiting for Kubernetes API..." -ForegroundColor Yellow
$ready = $false
for ($i = 1; $i -le 20; $i++) {
    $out = kubectl get nodes --request-timeout=10s 2>&1
    if ($LASTEXITCODE -eq 0) {
        Write-Host "  ✓ Kubernetes API is ready" -ForegroundColor Green
        $ready = $true
        break
    }
    Write-Host "  Attempt $i/20 — not ready yet, waiting 15s..."
    Start-Sleep 15
}

if (-not $ready) {
    Write-Host "WARNING: Cluster API not confirmed ready. Proceeding..." -ForegroundColor Yellow
}

# ── Phase 3: Full Apply (Monitoring, ArgoCD, StorageClass, remaining) ────────
#
# Now the kubeconfig is valid and points to a live EKS cluster.
# The Kubernetes/Helm providers can connect successfully.

Write-Host ""
Write-Host "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" -ForegroundColor DarkGray
Write-Host "  PHASE 3/3 — Full Apply (Monitoring, ArgoCD, StorageClass)" -ForegroundColor Cyan
Write-Host "  Estimated time: 10–15 minutes" -ForegroundColor Gray
Write-Host "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" -ForegroundColor DarkGray
Write-Host ""

terraform apply -auto-approve
if ($LASTEXITCODE -ne 0) {
    Write-Host "ERROR: Phase 3 failed. Check the error above and retry." -ForegroundColor Red
    exit 1
}

# ── Summary ──────────────────────────────────────────────────────────────────

Write-Host ""
Write-Host "============================================================" -ForegroundColor Green
Write-Host "  ✓ DEPLOYMENT COMPLETE — All infrastructure is live!" -ForegroundColor Green
Write-Host "============================================================" -ForegroundColor Green
Write-Host ""

# Print key outputs
Write-Host "Key Information:" -ForegroundColor Cyan
Write-Host "────────────────" -ForegroundColor DarkGray

$jenkinsIp = terraform output -raw jenkins_master_public_ip
Write-Host "  Jenkins URL:    http://${jenkinsIp}:8080" -ForegroundColor White
Write-Host "  Jenkins Login:  admin" -ForegroundColor White
Write-Host "  Jenkins Pass:   aws ssm get-parameter --name '/mern-auth-prod/jenkins/admin-password' --with-decryption --query Parameter.Value --output text --region $region" -ForegroundColor Gray

Write-Host ""
Write-Host "  EKS Cluster:    $clusterName" -ForegroundColor White
Write-Host "  ECR Registry:   $(terraform output -raw ecr_registry)" -ForegroundColor White

Write-Host ""
Write-Host "Next Steps:" -ForegroundColor Cyan
Write-Host "────────────" -ForegroundColor DarkGray
Write-Host "  1. Open Jenkins at http://${jenkinsIp}:8080" -ForegroundColor White
Write-Host "  2. Follow docs/DEPLOYMENT_GUIDE.md Section 4 to configure agents" -ForegroundColor White
Write-Host "  3. Create the pipeline job and run first build" -ForegroundColor White
Write-Host ""
