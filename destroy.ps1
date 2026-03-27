# Mumina - Destroy Script
# Run this in PowerShell: .\destroy.ps1

$passfile = Join-Path $PSScriptRoot ".passphrase"
if (-not (Test-Path $passfile)) { "" | Set-Content -NoNewline $passfile }
$env:PULUMI_CONFIG_PASSPHRASE_FILE = $passfile

Write-Host ""
Write-Host "=== Mumina Destroy ===" -ForegroundColor Red
Write-Host ""
Write-Host "This will delete the Mumble server, GCP project, and all local config." -ForegroundColor Yellow
Write-Host ""

# Get GCP project ID before destroying
$projectId = pulumi config get gcp:project 2>&1
if ($LASTEXITCODE -ne 0) { $projectId = $null }

# Destroy infrastructure
pulumi destroy

if ($LASTEXITCODE -ne 0) {
    Write-Host ""
    Read-Host "Press Enter to exit"
    exit 0
}

# Remove Pulumi stack
Write-Host ""
Write-Host "Removing Pulumi stack..." -ForegroundColor Yellow
pulumi stack rm dev --yes

# Delete GCP project
if ($projectId) {
    Write-Host "Deleting GCP project '$projectId'..." -ForegroundColor Yellow
    gcloud projects delete $projectId --quiet
}

# Clean up local files
Write-Host "Cleaning up local files..." -ForegroundColor Yellow
$cleanup = @("Pulumi.dev.yaml", ".passphrase", "venv")
foreach ($item in $cleanup) {
    $path = Join-Path $PSScriptRoot $item
    if (Test-Path $path) {
        Remove-Item $path -Recurse -Force
        Write-Host "  Removed $item" -ForegroundColor White
    }
}

Write-Host ""
Write-Host "Everything destroyed and cleaned up." -ForegroundColor Green
Write-Host ""
Read-Host "Press Enter to exit"
