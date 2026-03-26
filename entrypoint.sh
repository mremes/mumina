#!/bin/bash
set -euo pipefail

echo ""
echo "=== Mumina Setup ==="
echo ""

# --- Step 1: Google Cloud auth ---
echo "[1/4] Google Cloud authentication..."
echo ""

if gcloud auth application-default print-access-token &>/dev/null; then
    echo "  Already authenticated (credentials mounted)."
else
    echo "  Opening browser for Google Cloud login..."
    echo "  If the browser doesn't open, copy the URL shown below and paste it in your browser."
    echo ""
    gcloud auth login --no-launch-browser
    gcloud auth application-default login --no-launch-browser
fi

# --- Step 2: GCP project ---
echo ""
echo "[2/4] Google Cloud project..."
echo ""
read -rp "  Enter a GCP project ID (e.g. my-mumble-server): " PROJECT_ID

if gcloud projects describe "$PROJECT_ID" &>/dev/null; then
    echo "  Project '$PROJECT_ID' already exists."
else
    echo "  Creating project '$PROJECT_ID'..."
    gcloud projects create "$PROJECT_ID" --name="Mumble Server"
fi

echo "  Linking billing account..."
BILLING_ID=$(gcloud billing accounts list --format="value(ACCOUNT_ID)" | head -1)
if [ -z "$BILLING_ID" ]; then
    echo "  ERROR: No billing account found."
    echo "  Go to https://console.cloud.google.com/billing to set one up."
    exit 1
fi
echo "  Using billing account: $BILLING_ID"
gcloud billing projects link "$PROJECT_ID" --billing-account="$BILLING_ID"

echo "  Enabling Compute Engine API..."
gcloud services enable compute.googleapis.com --project="$PROJECT_ID"

# --- Step 3: Configure ---
echo ""
echo "[3/4] Server configuration..."
echo ""

pulumi login --local 2>/dev/null
pulumi stack init dev 2>/dev/null || pulumi stack select dev

pulumi config set gcp:project "$PROJECT_ID"

read -rp "  Server name (displayed in Mumble): " SERVER_NAME
pulumi config set mumina:serverName "$SERVER_NAME"

read -rp "  GCP zone [europe-north1-a]: " ZONE
ZONE=${ZONE:-europe-north1-a}
pulumi config set mumina:zone "$ZONE"

read -rp "  Machine type [e2-micro]: " MACHINE_TYPE
MACHINE_TYPE=${MACHINE_TYPE:-e2-micro}
pulumi config set mumina:machineType "$MACHINE_TYPE"

read -rp "  Max users [10]: " MAX_USERS
MAX_USERS=${MAX_USERS:-10}
pulumi config set mumina:maxUsers "$MAX_USERS"

read -rp "  Server password (users need this to connect): " SERVER_PASSWORD
pulumi config set --secret mumina:serverPassword "$SERVER_PASSWORD"

read -rp "  Admin password (for SuperUser account): " ADMIN_PASSWORD
pulumi config set --secret mumina:superUserPassword "$ADMIN_PASSWORD"

# --- Step 4: Deploy ---
echo ""
echo "[4/4] Deploying..."
echo ""

pulumi up

echo ""
echo "=== Done! ==="
echo ""
IP=$(pulumi stack output serverIp)
echo "  Server IP:   $IP"
echo "  Port:        64738"
echo "  Server name: $SERVER_NAME"
echo ""
echo "  Connect with Mumble client:"
echo "    1. Download from https://www.mumble.info/downloads/"
echo "    2. Server > Connect > Add New"
echo "    3. Address: $IP  Port: 64738"
echo "    4. Enter server password when prompted"
echo ""
echo "  Admin: connect with username 'SuperUser'"
echo ""
