# Mumina

Pulumi (Python) project that deploys a Mumble (Murmur) voice chat server. Supports UpCloud and Google Cloud.

## Project structure

- `__main__.py` — config, startup script, provider dispatch, outputs
- `providers/upcloud.py` — UpCloud server deployment (Helsinki fi-hel1)
- `providers/gcp.py` — GCP deployment (static IP, firewall, VM)
- `Pulumi.yaml` — project definition (runtime: python, name: mumina)
- `Pulumi.dev.yaml` — stack config with secrets (gitignored, created by install.ps1)
- `requirements.txt` — pulumi, pulumi-gcp, pulumi-upcloud
- `install.ps1` — interactive PowerShell setup (provider choice, auth, config, deploy, connectivity check)
- `destroy.ps1` — tears down infra, removes stack and local files

## How it works

1. `install.ps1` asks user to pick UpCloud or GCP, collects config interactively
2. `__main__.py` reads config (namespace `mumina:`), builds a shared startup script, then calls `providers/<name>.deploy()`
3. Each provider's `deploy()` creates cloud resources and returns the server IP
4. The startup script (cloud-init/user_data) installs mumble-server, configures it, creates channels, starts murmurd

## Provider details

- **UpCloud**: uses API token auth (`upcloud:token`), `user_data` for cloud-init, no firewall rules (trial limitation)
- **GCP**: uses gcloud ADC auth (`gcp:project`), `metadata_startup_script`, static IP with Premium network tier, firewall rules for port 64738 + SSH

## Key details

- All config from `pulumi config` (namespace `mumina:`), nothing hardcoded
- Passwords are Pulumi secrets (encrypted in stack config)
- Passphrase handled via `.passphrase` file + `PULUMI_CONFIG_PASSPHRASE_FILE` (empty string env var doesn't work on Windows PowerShell 5.1)
- Startup script is idempotent (marker file `/var/lib/mumble-server/.setup-complete`)
- `systemctl restart` can leave stale murmurd processes — use `killall murmurd` then start fresh
- Channels created via sqlite3 inserts into mumble-server.sqlite before starting murmurd
- UpCloud zone default: `fi-hel1` (Helsinki), GCP zone default: `europe-north1-a` (Hamina)
- Mumble Opus codec forced (`opusthreshold=0`), bandwidth 130 kbit/s per user
