# Mumina — Mumble Voice Server on GCP

One-command [Mumble](https://www.mumble.info/) voice chat server on Google Cloud.
Everything runs in a container — you only need [Podman](https://podman.io/) installed.

## Quick Start

Open **PowerShell** (press `Win`, type `powershell`, click "Windows PowerShell") and run:

```powershell
git clone https://github.com/mremes/mumina.git
cd mumina
.\install.ps1
```

The script:
1. Installs Podman (if missing)
2. Builds a container with all tools inside (Google Cloud CLI, Pulumi, Python)
3. Walks you through setup interactively:
   - Google Cloud login (opens your browser)
   - GCP project creation and billing
   - Server name, password, location, etc.
4. Deploys the server

At the end it prints the IP address. Connect with the [Mumble client](https://www.mumble.info/downloads/).

## Prerequisites

- **Windows** with PowerShell
- **Google account** with a credit card added for billing
  (Google gives **$300 free credits** for new accounts)

That's it. No need to install Python, Pulumi, or Google Cloud CLI — they're all inside the container.

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

All settings are configured interactively during `install.ps1`. To change settings later,
run the container manually:

```powershell
podman run -it --rm mumina
```

| Setting | Default | Description |
|---------|---------|-------------|
| GCP project | — | Your Google Cloud project ID |
| Server password | — | Password users need to connect |
| Admin password | — | SuperUser (admin) password |
| Server name | — | Display name in Mumble |
| GCP zone | `europe-north1-a` | Server location ([full list](https://cloud.google.com/compute/docs/regions-zones)) |
| Machine type | `e2-micro` | VM size ([options](https://cloud.google.com/compute/docs/general-purpose-machines)) |
| Max users | `10` | Max concurrent users |

## Troubleshooting

### "podman: not recognized" after install

Close **all** PowerShell windows and open a new one.

### Browser doesn't open for Google login

The container shows a URL — copy it and paste it in your browser manually.

### Mumble client shows old server name

Close Mumble completely (check system tray), reopen and reconnect.

## What This Creates

| Resource | Purpose | Cost |
|----------|---------|------|
| Static IP | Permanent address | Free (while attached) |
| Firewall rules | Open port 64738 + SSH | Free |
| VM (e2-micro) | Debian 12 + Mumble server | ~$7-8/month |
