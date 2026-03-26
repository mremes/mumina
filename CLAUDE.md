# Mumina

Pulumi (Python) project that deploys a Mumble (Murmur) voice chat server on a GCP Compute Engine VM.

## Project structure

- `__main__.py` — all infrastructure: static IP, firewall rules, VM with startup script
- `Pulumi.yaml` — project definition (runtime: python, name: mumina)
- `Pulumi.dev.yaml` — stack config with secrets (gitignored, created by install.ps1)
- `requirements.txt` — Python deps: pulumi, pulumi-gcp
- `install.ps1` — interactive PowerShell setup script (installs tools, creates GCP project, configures and deploys)

## How it works

All config comes from `pulumi config` (namespace `mumina:`). Nothing is hardcoded.
The VM startup script installs mumble-server, writes `/etc/mumble-server.ini`, sets passwords, and starts the service.
Passwords are Pulumi secrets (encrypted in stack config).

## Key details

- GCP project: set via `gcp:project` config
- Region derived from zone (e.g. `europe-north1-a` -> `europe-north1`)
- Murmur stores state in `/var/lib/mumble-server/mumble-server.sqlite`
- Startup script is idempotent (marker file prevents re-run on reboot)
- `systemctl restart` can leave stale murmurd processes — use `killall murmurd` then start fresh
