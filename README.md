# Mumina — Mumble Voice Server

One-command [Mumble](https://www.mumble.info/) voice chat server on the cloud.
Choose between **UpCloud** (Helsinki) or **Google Cloud** (Hamina, Finland).
Automated with [Pulumi](https://www.pulumi.com/) — run the setup script and you're online.

## Quick Start

Open **PowerShell** (press `Win`, type `powershell`, click "Windows PowerShell") and run:

```powershell
git clone https://github.com/mremes/mumina.git
cd mumina
.\install.ps1
```

The script walks you through everything:
1. Asks which cloud provider (UpCloud or GCP)
2. Installs Pulumi and Python (+ Google Cloud CLI if using GCP)
3. Authenticates with your chosen provider
4. Asks you to pick a server name, password, channels, etc.
5. Deploys the server and verifies connectivity

At the end it prints the IP address. Connect with the [Mumble client](https://www.mumble.info/downloads/).

## Cloud Providers

| | UpCloud | Google Cloud |
|---|---|---|
| **Location** | Helsinki | Hamina (~150km from Helsinki) |
| **Latency** | ~17ms | ~45ms |
| **Cost** | ~5 EUR/mo | ~7-8 USD/mo |
| **Auth** | API token | Google account + billing |
| **Plan** | 1xCPU-1GB | e2-micro |

## Prerequisites

- **Windows** with PowerShell
- **UpCloud account** with an API token ([hub.upcloud.com/people](https://hub.upcloud.com/people))
  — or —
- **Google Cloud account** with a credit card for billing

The install script handles everything else.

## Connecting

1. Download Mumble from https://www.mumble.info/downloads/
2. Open Mumble > **Server** > **Connect** > **Add New...**
3. Enter the IP address and port `64738`
4. Pick any username and click **Connect**
5. Enter the server password when prompted

### Admin access

Connect with username **SuperUser** and use the admin password you set during setup.

### Best latency settings (client-side)

- **Configure > Settings > Audio Input** — set "Audio per packet" to **10ms**
- **Configure > Settings > Audio Output** — reduce "Output delay" to minimum

---

## Configuration

All settings are stored in `Pulumi.dev.yaml` (local, not committed to git).

| Key | Required | Default | Description |
|-----|----------|---------|-------------|
| `mumina:provider` | yes | `gcp` | Cloud provider (`upcloud` or `gcp`) |
| `mumina:serverPassword` | yes | — | Password users need to connect |
| `mumina:superUserPassword` | yes | — | Admin password for SuperUser |
| `mumina:serverName` | yes | — | Display name in Mumble |
| `mumina:channels` | no | — | Comma-separated channels to create |
| `mumina:zone` | no | `fi-hel1` / `europe-north1-a` | Server zone |
| `mumina:machineType` | no | `1xCPU-1GB` / `e2-micro` | VM plan |
| `mumina:maxUsers` | no | `10` | Max concurrent users |
| `mumina:port` | no | `64738` | Mumble server port |
| `mumina:welcomeText` | no | auto | Welcome message (HTML) |

Provider-specific:

| Key | Provider | Description |
|-----|----------|-------------|
| `upcloud:token` | UpCloud | API token (secret) |
| `gcp:project` | GCP | Project ID |

## Destroy

```powershell
.\destroy.ps1
```

Removes all cloud resources, Pulumi stack, and local config files.

## Troubleshooting

### "stack is currently locked"

```powershell
pulumi cancel
```

### "passphrase must be set"

The scripts handle this automatically. If running pulumi manually, create a `.passphrase` file first:

```powershell
"" | Set-Content -NoNewline .passphrase
$env:PULUMI_CONFIG_PASSPHRASE_FILE = ".passphrase"
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
