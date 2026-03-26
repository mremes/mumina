# Mumina — Setup Script
# Run this in PowerShell: .\install.ps1

$ErrorActionPreference = "Stop"

Write-Host ""
Write-Host "=== Mumina Setup ===" -ForegroundColor Cyan
Write-Host ""

# --- Install Podman if needed ---
if (-not (Get-Command podman -ErrorAction SilentlyContinue)) {
    Write-Host "Installing Podman..." -ForegroundColor Yellow
    winget install RedHat.Podman --accept-source-agreements --accept-package-agreements --silent
    Write-Host ""
    Write-Host "Podman installed. Please CLOSE this window, open a NEW PowerShell, and run this script again." -ForegroundColor Red
    Write-Host ""
    exit 0
}

# --- Initialize Podman machine if needed ---
podman machine info 2>&1 | Out-Null
if ($LASTEXITCODE -ne 0) {
    Write-Host "Initializing Podman machine..." -ForegroundColor Yellow
    podman machine init
}

$running = podman machine info --format "{{.Host.MachineState}}" 2>&1
if ($running -ne "Running") {
    Write-Host "Starting Podman machine..." -ForegroundColor Yellow
    podman machine start
}

# --- Build and run ---
Write-Host "Building Mumina container..." -ForegroundColor Yellow
podman build -t mumina .

Write-Host ""
Write-Host "Starting interactive setup..." -ForegroundColor Yellow
Write-Host "(Follow the prompts inside the container)" -ForegroundColor White
Write-Host ""

podman run -it --rm mumina
