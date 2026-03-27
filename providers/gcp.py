import pulumi
import pulumi_gcp as gcp


def deploy(config, startup_script, mumble_port):
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

    return static_ip.address
