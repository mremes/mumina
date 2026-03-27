import pulumi

# --- Configuration ---
config = pulumi.Config("mumina")
provider = config.get("provider") or "gcp"
server_password = config.require_secret("serverPassword")
super_user_password = config.require_secret("superUserPassword")
server_name = config.require("serverName")
welcome_text = config.get("welcomeText") or f"Welcome to <b>{server_name}</b>. For low latency: Settings, Audio Input, set Audio per packet to 10ms."
max_users = config.get_int("maxUsers") or 10
mumble_port = config.get_int("port") or 64738
channels = config.get("channels") or ""

# --- Startup Script ---
startup_script = pulumi.Output.all(
    server_password, super_user_password
).apply(
    lambda args: f"""#!/bin/bash
set -euo pipefail

MARKER="/var/lib/mumble-server/.setup-complete"
if [ -f "$MARKER" ]; then
    echo "Mumble server already configured, ensuring service is running."
    systemctl start mumble-server || true
    exit 0
fi

export DEBIAN_FRONTEND=noninteractive
apt-get update -qq
apt-get install -y -qq mumble-server

systemctl stop mumble-server

cat > /etc/mumble-server.ini << 'INIEOF'
# Network
port={mumble_port}
host=

# Authentication — placeholder replaced below
serverpassword=PLACEHOLDER_SERVER_PASSWORD

# Limits
bandwidth=130000
users={max_users}

# Codec
opusthreshold=0

# Server identity
welcometext={welcome_text}
registerName={server_name}

# Ping
allowping=true

# Anti-abuse
autobanAttempts=10
autobanTimeframe=120
autobanTime=300

# Logging
logfile=/var/log/mumble-server/mumble-server.log
logdays=31

# Database
database=/var/lib/mumble-server/mumble-server.sqlite

# Run as
uname=mumble-server
INIEOF

# Inject the actual server password
sed -i "s|PLACEHOLDER_SERVER_PASSWORD|{args[0]}|g" /etc/mumble-server.ini

# Set SuperUser password (hashed into the SQLite DB)
su -s /bin/bash mumble-server -c "murmurd -ini /etc/mumble-server.ini -supw '{args[1]}'"

# Create channels if any were specified
CHANNEL_LIST="{channels}"
if [ -n "$CHANNEL_LIST" ]; then
    apt-get install -y -qq sqlite3
    NEXT_ID=$(sqlite3 /var/lib/mumble-server/mumble-server.sqlite "SELECT COALESCE(MAX(channel_id),0)+1 FROM channels WHERE server_id=1;")
    IFS=',' read -ra CHANNELS <<< "$CHANNEL_LIST"
    for ch in "${{CHANNELS[@]}}"; do
        ch=$(echo "$ch" | xargs)
        if [ -n "$ch" ]; then
            sqlite3 /var/lib/mumble-server/mumble-server.sqlite \
                "INSERT INTO channels (server_id, channel_id, parent_id, name) VALUES (1, $NEXT_ID, 0, '$ch');"
            echo "Created channel: $ch"
            NEXT_ID=$((NEXT_ID + 1))
        fi
    done
fi

# Start the service
systemctl enable mumble-server
killall murmurd 2>/dev/null || true
sleep 1
/usr/sbin/murmurd -ini /etc/mumble-server.ini

# Verify it's running
sleep 2
if pgrep -x murmurd > /dev/null; then
    echo "Mumble server is running."
else
    echo "WARNING: Mumble server failed to start!"
fi

touch "$MARKER"
echo "Mumble server setup complete."
"""
)

# --- Deploy to selected provider ---
if provider == "upcloud":
    from providers.upcloud import deploy
elif provider == "gcp":
    from providers.gcp import deploy
else:
    raise ValueError(f"Unknown provider: {provider}. Use 'gcp' or 'upcloud'.")

server_ip = deploy(config, startup_script, mumble_port)

# --- Outputs ---
pulumi.export("serverIp", server_ip)
pulumi.export("serverPort", mumble_port)
pulumi.export(
    "connectionInfo",
    server_ip.apply(
        lambda ip: f"""
=== Mumble Server Connection Info ===
Address: {ip}
Port:    {mumble_port}
Server:  {server_name}

Connect with Mumble client:
  1. Download from https://www.mumble.info/downloads/
  2. Add New server -> Address: {ip}, Port: {mumble_port}
  3. Enter the server password when prompted

SuperUser login:
  Username: SuperUser
  Password: (retrieve with: pulumi config get superUserPassword)
=====================================
"""
    ),
)
