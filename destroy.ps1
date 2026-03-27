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

pulumi destroy 2>&1 | ForEach-Object {
    if ($_ -notmatch "history and configuration" -and $_ -notmatch "pulumi stack rm") {
        Write-Host $_
    }
}

if ($LASTEXITCODE -ne 0) {
    Write-Host ""
    Write-Host "Destroy was cancelled or failed." -ForegroundColor Yellow
    Write-Host ""
    Read-Host "Press Enter to close"
    exit 0
}

pulumi stack rm dev --yes 2>&1 | Out-Null

Write-Host ""
Write-Host "Infrastructure and stack removed." -ForegroundColor Green
Write-Host ""
Read-Host "Press Enter to exit"
