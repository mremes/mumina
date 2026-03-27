import pulumi

# --- Configuration ---
config = pulumi.Config("mumina")
provider = config.get("provider") or "gcp"
server_password = config.require_secret("serverPassword")
super_user_password = config.require_secret("superUserPassword")
server_name = config.require("serverName")
welcome_text = config.get("welcomeText") or f"<br/>Welcome to <b>{server_name}</b> voice server.<br/>Enjoy your stay!<br/><br/><b>For best latency:</b> Configure &gt; Settings &gt; Audio Input &gt; set Audio per packet to 10ms. Audio Output &gt; reduce Output delay to minimum.<br/>"
max_users = config.get_int("maxUsers") or 10
mumble_port = config.get_int("port") or 64738
channels = config.get("channels") or ""

# --- Startup Script (shared) ---
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

# Create channels before starting the service
apt-get install -y -qq sqlite3
# Start briefly to initialize the DB, then stop
systemctl start mumble-server
sleep 2
systemctl stop mumble-server
killall murmurd 2>/dev/null || true
sleep 1

IFS=',' read -ra CHANNELS <<< "{channels}"
NEXT_ID=$(sqlite3 /var/lib/mumble-server/mumble-server.sqlite "SELECT COALESCE(MAX(channel_id),0)+1 FROM channels WHERE server_id=1;")
for ch in "${{CHANNELS[@]}}"; do
    ch=$(echo "$ch" | xargs)
    if [ -n "$ch" ]; then
        sqlite3 /var/lib/mumble-server/mumble-server.sqlite \
            "INSERT INTO channels (server_id, channel_id, parent_id, name) VALUES (1, $NEXT_ID, 0, '$ch');"
        echo "Created channel: $ch"
        NEXT_ID=$((NEXT_ID + 1))
    fi
done

# Start the service for real
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

# --- Provider-specific infrastructure ---
server_ip = None

if provider == "upcloud":
    import pulumi_upcloud as upcloud

    zone = config.get("zone") or "fi-hel1"
    plan = config.get("machineType") or "1xCPU-1GB"

    server = upcloud.Server(
        "mumble-server",
        hostname="mumble",
        zone=zone,
        plan=plan,
        firewall=True,
        template=upcloud.ServerTemplateArgs(
            storage="Debian GNU/Linux 12 (Bookworm)",
            size=10,
        ),
        network_interfaces=[
            upcloud.ServerNetworkInterfaceArgs(type="public"),
        ],
        login=upcloud.ServerLoginArgs(
            create_password=False,
            password_delivery="none",
        ),
        user_data=startup_script,
    )

    firewall_rules = upcloud.ServerFirewallRules(
        "mumble-firewall",
        server_id=server.id,
        firewall_rules=[
            upcloud.ServerFirewallRulesFirewallRuleArgs(
                action="accept",
                direction="in",
                family="IPv4",
                protocol="tcp",
                destination_port_start=str(mumble_port),
                destination_port_end=str(mumble_port),
            ),
            upcloud.ServerFirewallRulesFirewallRuleArgs(
                action="accept",
                direction="in",
                family="IPv4",
                protocol="udp",
                destination_port_start=str(mumble_port),
                destination_port_end=str(mumble_port),
            ),
            upcloud.ServerFirewallRulesFirewallRuleArgs(
                action="accept",
                direction="in",
                family="IPv4",
                protocol="tcp",
                destination_port_start="22",
                destination_port_end="22",
            ),
            upcloud.ServerFirewallRulesFirewallRuleArgs(
                action="drop",
                direction="in",
            ),
        ],
    )

    server_ip = server.network_interfaces.apply(
        lambda ifaces: next(
            (i.ip_addresses[0].address for i in ifaces if i.type == "public"), None
        )
    )

elif provider == "gcp":
    import pulumi_gcp as gcp

    zone = config.get("zone") or "europe-north1-a"
    region = zone.rsplit("-", 1)[0]
    machine_type = config.get("machineType") or "e2-micro"

    static_ip = gcp.compute.Address(
        "mumble-ip",
        region=region,
        address_type="EXTERNAL",
        network_tier="PREMIUM",
    )

    gcp.compute.Firewall(
        "mumble-firewall",
        network="default",
        allows=[
            gcp.compute.FirewallAllowArgs(protocol="tcp", ports=[str(mumble_port)]),
            gcp.compute.FirewallAllowArgs(protocol="udp", ports=[str(mumble_port)]),
        ],
        source_ranges=["0.0.0.0/0"],
        target_tags=["mumble-server"],
    )

    gcp.compute.Firewall(
        "ssh-firewall",
        network="default",
        allows=[
            gcp.compute.FirewallAllowArgs(protocol="tcp", ports=["22"]),
        ],
        source_ranges=["0.0.0.0/0"],
        target_tags=["mumble-server"],
    )

    gcp.compute.Instance(
        "mumble-server",
        machine_type=machine_type,
        zone=zone,
        boot_disk=gcp.compute.InstanceBootDiskArgs(
            initialize_params=gcp.compute.InstanceBootDiskInitializeParamsArgs(
                image="debian-cloud/debian-12",
                size=10,
                type="pd-standard",
            ),
        ),
        network_interfaces=[
            gcp.compute.InstanceNetworkInterfaceArgs(
                network="default",
                access_configs=[
                    gcp.compute.InstanceNetworkInterfaceAccessConfigArgs(
                        nat_ip=static_ip.address,
                    ),
                ],
            ),
        ],
        metadata_startup_script=startup_script,
        tags=["mumble-server"],
    )

    server_ip = static_ip.address

else:
    raise ValueError(f"Unknown provider: {provider}. Use 'gcp' or 'upcloud'.")

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
