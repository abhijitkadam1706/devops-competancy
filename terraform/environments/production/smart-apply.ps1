# =============================================================================
# smart-apply.ps1 — Safe Terraform Apply Wrapper
#
# USE THIS instead of `terraform apply -auto-approve` for every apply cycle.
#
# What this does BEFORE applying:
#   1. Detects a CloudWatch log group that exists in AWS but NOT in Terraform
#      state (happens after partial apply failures or failed destroys).
#   2. Imports it automatically so Terraform doesn't hit ResourceAlreadyExistsException.
#   3. Runs terraform apply.
#
# USAGE:
#   cd terraform\environments\production
#   .\smart-apply.ps1
# =============================================================================

param(
    [string]$Region      = "ap-southeast-1",
    [string]$ClusterName = "mern-auth-prod"
)

$LogGroupName = "/aws/vpc/$ClusterName/flow-logs"
$TFResource   = "module.vpc.aws_cloudwatch_log_group.flow_log"

Write-Host "`n=== Smart Terraform Apply ===" -ForegroundColor Cyan
Write-Host "Cluster : $ClusterName"
Write-Host "Region  : $Region"
Write-Host ""

# ── Step 1: Check if log group exists in AWS ─────────────────────────────────
Write-Host "[1/3] Checking CloudWatch log group in AWS..." -ForegroundColor Yellow
$awsResult = aws logs describe-log-groups `
    --log-group-name-prefix $LogGroupName `
    --region $Region `
    --query "logGroups[?logGroupName=='$LogGroupName'].logGroupName" `
    --output text 2>$null

$existsInAWS = ($awsResult -eq $LogGroupName)

if ($existsInAWS) {
    Write-Host "  Log group EXISTS in AWS." -ForegroundColor Green

    # ── Step 2: Check if it is already in Terraform state ────────────────────
    Write-Host "[2/3] Checking Terraform state..." -ForegroundColor Yellow
    $stateCheck = terraform state show $TFResource 2>&1
    $inState    = ($LASTEXITCODE -eq 0)

    if (-not $inState) {
        Write-Host "  NOT in state — orphan detected. Importing..." -ForegroundColor Magenta
        terraform import $TFResource $LogGroupName
        if ($LASTEXITCODE -ne 0) {
            Write-Host "  ERROR: Import failed. Aborting." -ForegroundColor Red
            exit 1
        }
        Write-Host "  Import successful." -ForegroundColor Green
    } else {
        Write-Host "  Already in state — nothing to import." -ForegroundColor Green
    }
} else {
    Write-Host "  Log group does NOT exist in AWS — will be created by Terraform." -ForegroundColor Green
    Write-Host "[2/3] Skipping import check (not needed)." -ForegroundColor DarkGray
}

# ── Step 3: Run terraform apply ───────────────────────────────────────────────
Write-Host ""
Write-Host "[3/3] Running terraform apply..." -ForegroundColor Yellow
terraform apply -auto-approve 2>&1

if ($LASTEXITCODE -eq 0) {
    Write-Host "`n=== Apply Complete ===" -ForegroundColor Green
} else {
    Write-Host "`n=== Apply Failed ===" -ForegroundColor Red
    exit $LASTEXITCODE
}
