import pulumi
import pulumi_upcloud as upcloud


def deploy(config, startup_script, mumble_port):
    zone = config.get("zone") or "fi-hel1"
    plan = config.get("machineType") or "1xCPU-1GB"

    server = upcloud.Server(
        "mumble-server",
        hostname="mumble",
        zone=zone,
        plan=plan,
        firewall=True,
        metadata=True,
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

    server_ip = server.network_interfaces.apply(
        lambda ifaces: next(
            (i.ip_address for i in ifaces if i.type == "public"), None
        )
    )

    return server_ip
