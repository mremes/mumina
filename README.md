# Mumina — Mumble Voice Server on GCP

One-command [Mumble](https://www.mumble.info/) voice chat server on Google Cloud.
Automated with [Pulumi](https://www.pulumi.com/) — run the setup script and you're online.

## Quick Start

Open **PowerShell** (press `Win`, type `powershell`, click "Windows PowerShell") and run:

```powershell
git clone https://github.com/mremes/mumina.git
cd mumina
.\install.ps1
```

The script walks you through everything:
1. Installs Google Cloud CLI, Pulumi, and Python (if missing)
2. Logs you into Google Cloud (opens your browser)
3. Creates a GCP project and links billing
4. Asks you to pick a server name, password, location, etc.
5. Deploys the server

At the end it prints the IP address. Connect with the [Mumble client](https://www.mumble.info/downloads/).

## Prerequisites

- **Windows** with PowerShell
- **Google account** with a credit card added for billing
  (Google gives **$300 free credits** for new accounts, after that ~$7-8/month)

That's it — the install script handles the rest.

## Connecting

1. Download Mumble from https://www.mumble.info/downloads/
2. Open Mumble > **Server** > **Connect** > **Add New...**
3. Enter the IP address and port `64738`
4. Pick any username and click **Connect**
5. Enter the server password when prompted

### Admin access

Connect with username **SuperUser** and use the admin password you set during setup.

---

## Configuration

All settings are stored in `Pulumi.dev.yaml` (local, not committed to git).
Change them anytime with `pulumi config set`:

```powershell
$env:PULUMI_CONFIG_PASSPHRASE = ""
pulumi config set mumina:serverName "New Name"
pulumi up
```

| Key | Required | Default | Description |
|-----|----------|---------|-------------|
| `gcp:project` | yes | — | Your GCP project ID |
| `mumina:serverPassword` | yes | — | Password users need to connect |
| `mumina:superUserPassword` | yes | — | Admin password for SuperUser |
| `mumina:serverName` | yes | — | Display name in Mumble |
| `mumina:zone` | no | `europe-north1-a` | GCP zone ([full list](https://cloud.google.com/compute/docs/regions-zones)) |
| `mumina:machineType` | no | `e2-micro` | VM size ([options](https://cloud.google.com/compute/docs/general-purpose-machines)) |
| `mumina:maxUsers` | no | `10` | Max concurrent users |
| `mumina:port` | no | `64738` | Mumble server port |
| `mumina:welcomeText` | no | auto | HTML welcome message |

## Day-to-Day Commands

```powershell
# Always set this first in a new PowerShell window
$env:PULUMI_CONFIG_PASSPHRASE = ""

# Deploy or update
pulumi up

# Show server IP
pulumi stack output serverIp

# Shut down and delete everything
pulumi destroy

# SSH into the server
gcloud compute ssh mumble-server --zone=europe-north1-a --project=YOUR_PROJECT
```

## Troubleshooting

### "passphrase must be set" error

Run this before any `pulumi` command:

```powershell
$env:PULUMI_CONFIG_PASSPHRASE = ""
```

### "not recognized" after installing tools

Close **all** PowerShell windows and open a new one.

### Server not picking up changes

SSH in and force-restart:

```bash
sudo killall murmurd
sleep 2
sudo /usr/sbin/murmurd -ini /etc/mumble-server.ini
```

### Mumble client shows old server name

Close Mumble completely (check system tray), reopen and reconnect.

## What This Creates

| Resource | Purpose | Cost |
|----------|---------|------|
| Static IP | Permanent address | Free (while attached) |
| Firewall rules | Open port 64738 + SSH | Free |
| VM (e2-micro) | Debian 12 + Mumble server | ~$7-8/month |
