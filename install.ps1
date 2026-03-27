# Mumina - Setup Script
# Run this in PowerShell: .\install.ps1

$passfile = Join-Path $PSScriptRoot ".passphrase"
if (-not (Test-Path $passfile)) { "" | Set-Content -NoNewline $passfile }
$env:PULUMI_CONFIG_PASSPHRASE_FILE = $passfile

Write-Host ""
Write-Host "=== Mumina Setup ===" -ForegroundColor Cyan
Write-Host ""

# --- Step 1: Install tools ---
Write-Host "[1/6] Installing required tools..." -ForegroundColor Yellow

$tools = @(
    @{ Name = "Google Cloud CLI"; Id = "Google.CloudSDK"; Cmd = "gcloud" },
    @{ Name = "Pulumi CLI"; Id = "Pulumi.Pulumi"; Cmd = "pulumi" },
    @{ Name = "Python"; Id = "Python.Python.3.12"; Cmd = "python" }
)

$needsRestart = $false
foreach ($tool in $tools) {
    if (Get-Command $tool.Cmd -ErrorAction SilentlyContinue) {
        Write-Host "  $($tool.Name) - already installed" -ForegroundColor Green
    } else {
        Write-Host "  Installing $($tool.Name)..." -ForegroundColor White
        winget install $tool.Id --accept-source-agreements --accept-package-agreements --silent
        $needsRestart = $true
    }
}

if ($needsRestart) {
    Write-Host ""
    Write-Host "Tools were installed. Please CLOSE this window, open a NEW PowerShell, and run this script again." -ForegroundColor Red
    Read-Host "  Press Enter to exit"
    exit 0
}

# --- Step 2: Google Cloud auth ---
Write-Host ""
Write-Host "[2/6] Google Cloud authentication..." -ForegroundColor Yellow
Write-Host "  This will open your browser. Sign in with your Google account." -ForegroundColor White
Write-Host ""

$null = gcloud auth application-default print-access-token 2>&1
if ($LASTEXITCODE -ne 0) {
    gcloud auth login
    gcloud auth application-default login
} else {
    Write-Host "  Already authenticated" -ForegroundColor Green
}

# --- Step 3: GCP project ---
Write-Host ""
Write-Host "[3/6] Google Cloud project setup..." -ForegroundColor Yellow

do {
    $projectId = Read-Host "  Enter a project ID (6-30 chars, lowercase letters/digits/hyphens)"
    if ($projectId -notmatch "^[a-z][a-z0-9\-]{5,29}$") {
        Write-Host "  Invalid ID. Must be 6-30 chars, start with a letter, only lowercase/digits/hyphens." -ForegroundColor Red
    }
} while ($projectId -notmatch "^[a-z][a-z0-9\-]{5,29}$")

$null = gcloud projects describe $projectId 2>&1
if ($LASTEXITCODE -eq 0) {
    Write-Host "  Project '$projectId' already exists" -ForegroundColor Green
} else {
    Write-Host "  Creating project '$projectId'..." -ForegroundColor White
    gcloud projects create $projectId --name="Mumble Server" --labels=environment=development
}

# Link billing
Write-Host ""
Write-Host "  Linking billing account..." -ForegroundColor White
$billingAccounts = gcloud billing accounts list --format="value(ACCOUNT_ID)" 2>&1
$billingLines = @(($billingAccounts -split "`n") | Where-Object { $_.Trim() -ne "" })

if ($billingLines.Count -eq 0) {
    Write-Host "  No billing account found. Go to https://console.cloud.google.com/billing to set one up." -ForegroundColor Red
    Read-Host "  Press Enter to exit"
    exit 1
} elseif ($billingLines.Count -eq 1) {
    $billingId = $billingLines[0].ToString().Trim()
    Write-Host "  Using billing account: $billingId" -ForegroundColor Green
} else {
    Write-Host "  Available billing accounts:" -ForegroundColor White
    for ($i = 0; $i -lt $billingLines.Count; $i++) {
        Write-Host "    [$i] $($billingLines[$i].ToString().Trim())" -ForegroundColor White
    }
    $choice = Read-Host "  Pick one (number)"
    $billingId = $billingLines[$choice].ToString().Trim()
}

gcloud billing projects link $projectId --billing-account=$billingId

Write-Host "  Enabling Compute Engine API..." -ForegroundColor White
gcloud services enable compute.googleapis.com --project=$projectId

# --- Step 4: Pulumi stack ---
Write-Host ""
Write-Host "[4/6] Pulumi setup..." -ForegroundColor Yellow

$null = pulumi whoami 2>&1
if ($LASTEXITCODE -ne 0) {
    pulumi login --local
}

$stackExists = pulumi stack ls 2>&1 | Select-String "dev"
if (-not $stackExists) {
    pulumi stack init dev
} else {
    pulumi stack select dev
    Write-Host "  Stack 'dev' already exists" -ForegroundColor Green
}

# --- Step 5: Configure ---
Write-Host ""
Write-Host "[5/6] Server configuration..." -ForegroundColor Yellow
Write-Host ""

pulumi config set gcp:project $projectId

$serverName = Read-Host "  Server name (displayed in Mumble)"
pulumi config set mumina:serverName $serverName

$zone = Read-Host "  GCP zone (press Enter for europe-north1-a / Finland)"
if ([string]::IsNullOrWhiteSpace($zone)) { $zone = "europe-north1-a" }
pulumi config set mumina:zone $zone

$machineType = Read-Host "  Machine type (press Enter for e2-micro)"
if ([string]::IsNullOrWhiteSpace($machineType)) { $machineType = "e2-micro" }
pulumi config set mumina:machineType $machineType

$maxUsers = Read-Host "  Max users (press Enter for 10)"
if ([string]::IsNullOrWhiteSpace($maxUsers)) { $maxUsers = "10" }
pulumi config set mumina:maxUsers $maxUsers

$channels = Read-Host "  Channels to create (comma-separated, or press Enter for none)"
if (-not [string]::IsNullOrWhiteSpace($channels)) {
    pulumi config set mumina:channels $channels
}

$serverPassword = Read-Host "  Server password (users need this to connect)"
pulumi config set --secret mumina:serverPassword $serverPassword

$adminPassword = Read-Host "  Admin password (for SuperUser account)"
pulumi config set --secret mumina:superUserPassword $adminPassword

# --- Step 6: Deploy ---
Write-Host ""
Write-Host "[6/6] Deploying..." -ForegroundColor Yellow
Write-Host ""

pulumi up

if ($LASTEXITCODE -ne 0) {
    Write-Host ""
    Write-Host "Deploy was cancelled or failed." -ForegroundColor Yellow
    Write-Host "You can re-run the deploy later with: pulumi up" -ForegroundColor White
    Write-Host ""
    Read-Host "Press Enter to close"
    exit 0
}

# --- Verify server is reachable ---
Write-Host ""
Write-Host "Waiting for server to come online..." -ForegroundColor Yellow
$ip = pulumi stack output serverIp 2>&1

$ready = $false
$wait = 3
for ($attempt = 1; $attempt -le 8; $attempt++) {
    $result = Test-NetConnection -ComputerName $ip -Port 64738 -WarningAction SilentlyContinue
    if ($result.TcpTestSucceeded) {
        $ready = $true
        break
    }
    Write-Host "  Not ready yet, retrying in ${wait}s..." -ForegroundColor White
    Start-Sleep -Seconds $wait
    $wait = [math]::Min($wait * 2, 60)
}

if (-not $ready) {
    Write-Host ""
    Write-Host "Server deployed but not responding on port 64738 yet." -ForegroundColor Yellow
    Write-Host "It may need a few more minutes. Try connecting with Mumble shortly." -ForegroundColor White
} else {
    Write-Host "  Server is online!" -ForegroundColor Green
}

Write-Host ""
Write-Host "=== Done! ===" -ForegroundColor Green
Write-Host ""
Write-Host "  Server IP:    $ip" -ForegroundColor Cyan
Write-Host "  Port:         64738" -ForegroundColor Cyan
Write-Host "  Server name:  $serverName" -ForegroundColor Cyan
Write-Host ""
Write-Host "  Connect with Mumble client:" -ForegroundColor White
Write-Host "    1. Download from https://www.mumble.info/downloads/" -ForegroundColor White
Write-Host "    2. Server -> Connect -> Add New" -ForegroundColor White
Write-Host "    3. Address: $ip  Port: 64738" -ForegroundColor White
Write-Host "    4. Enter server password when prompted" -ForegroundColor White
Write-Host ""
Write-Host "  Admin: connect with username 'SuperUser'" -ForegroundColor White
Write-Host ""
Read-Host "  Press Enter to exit"
