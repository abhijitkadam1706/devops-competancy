# =============================================================================
# destroy.ps1 — Clean Infrastructure Teardown
#
# PURPOSE: Destroys all AWS resources created by deploy.ps1 in the correct
#          order. Kubernetes resources (Helm charts, namespaces) are destroyed
#          BEFORE the EKS cluster, avoiding orphaned AWS resources.
#
# USAGE:
#   cd terraform/environments/production
#   .\destroy.ps1
#
# COST CONTROL: Run this when you are done for the day to stop all charges.
# =============================================================================

$ErrorActionPreference = "Stop"

Write-Host ""
Write-Host "============================================================" -ForegroundColor Red
Write-Host "  ⚠  DESTROY ALL INFRASTRUCTURE" -ForegroundColor Red
Write-Host "  This will delete EVERYTHING deployed by Terraform." -ForegroundColor Yellow
Write-Host "============================================================" -ForegroundColor Red
Write-Host ""

$confirm = Read-Host "Type 'destroy' to confirm"
if ($confirm -ne "destroy") {
    Write-Host "Aborted." -ForegroundColor Yellow
    exit 0
}

Write-Host ""
Write-Host "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" -ForegroundColor DarkGray
Write-Host "  Destroying all resources... (this takes 15-25 minutes)" -ForegroundColor Yellow
Write-Host "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" -ForegroundColor DarkGray
Write-Host ""

terraform destroy -auto-approve

if ($LASTEXITCODE -ne 0) {
    Write-Host ""
    Write-Host "First destroy pass had errors. Retrying..." -ForegroundColor Yellow
    Write-Host "(This is normal — Kubernetes resources sometimes need a second pass)" -ForegroundColor Gray
    Write-Host ""
    Start-Sleep 10
    terraform destroy -auto-approve
}

if ($LASTEXITCODE -eq 0) {
    Write-Host ""
    Write-Host "============================================================" -ForegroundColor Green
    Write-Host "  ✓ All infrastructure destroyed. No more charges." -ForegroundColor Green
    Write-Host "============================================================" -ForegroundColor Green
} else {
    Write-Host ""
    Write-Host "Some resources may still exist. Check AWS Console." -ForegroundColor Red
}
Write-Host ""
