# Mumina - Destroy Script
# Run this in PowerShell: .\destroy.ps1

[Environment]::SetEnvironmentVariable("PULUMI_CONFIG_PASSPHRASE", "", "Process")

Write-Host ""
Write-Host "=== Mumina Destroy ===" -ForegroundColor Red
Write-Host ""
Write-Host "This will delete the Mumble server and all associated GCP resources." -ForegroundColor Yellow
Write-Host ""

$confirm = Read-Host "Are you sure? (yes/no)"
if ($confirm -ne "yes") {
    Write-Host "Cancelled." -ForegroundColor Green
    exit 0
}

pulumi destroy --yes

Write-Host ""
Write-Host "Infrastructure destroyed." -ForegroundColor Green
Write-Host ""
Read-Host "Press Enter to exit"
