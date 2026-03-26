# Mumina

Containerized Pulumi (Python) project that deploys a Mumble (Murmur) voice chat server on a GCP Compute Engine VM.

## Project structure

- `Dockerfile` — container image with gcloud, Pulumi, Python, and project code
- `entrypoint.sh` — interactive setup script (runs inside container)
- `install.ps1` — Windows PowerShell script that installs Podman and runs the container
- `__main__.py` — Pulumi infrastructure: static IP, firewall rules, VM with startup script
- `Pulumi.yaml` — project definition (runtime: python, name: mumina)
- `requirements.txt` — Python deps: pulumi, pulumi-gcp

## How it works

User only needs Podman installed. `install.ps1` builds and runs the container.
Inside the container, `entrypoint.sh` handles gcloud auth, GCP project setup,
Pulumi config, and deployment interactively.

All config comes from `pulumi config` (namespace `mumina:`). Nothing is hardcoded.
The VM startup script installs mumble-server, writes `/etc/mumble-server.ini`,
sets passwords, and starts the service. Passwords are Pulumi secrets.

## Key details

- Container has: gcloud CLI, Pulumi CLI, Python 3.12, pulumi-gcp
- User authenticates to GCP via `gcloud auth login --no-launch-browser` inside container
- Region derived from zone (e.g. `europe-north1-a` -> `europe-north1`)
- Murmur state: `/var/lib/mumble-server/mumble-server.sqlite` on the VM
- Startup script is idempotent (marker file prevents re-run on reboot)
- `systemctl restart` can leave stale murmurd processes — use `killall murmurd` then start fresh
