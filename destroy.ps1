# Mumina - Destroy Script
# Run this in PowerShell: .\destroy.ps1

$passfile = Join-Path $PSScriptRoot ".passphrase"
if (-not (Test-Path $passfile)) { "" | Set-Content -NoNewline $passfile }
$env:PULUMI_CONFIG_PASSPHRASE_FILE = $passfile

Write-Host ""
Write-Host "=== Mumina Destroy ===" -ForegroundColor Red
Write-Host ""
Write-Host "This will delete the Mumble server and all associated GCP resources." -ForegroundColor Yellow
Write-Host ""

pulumi destroy

Write-Host ""
Write-Host "Infrastructure destroyed." -ForegroundColor Green
Write-Host ""
Read-Host "Press Enter to exit"
