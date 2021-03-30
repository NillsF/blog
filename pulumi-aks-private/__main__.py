"""An Azure RM Python Pulumi program"""

import pulumi
from pulumi_azure_native import storage
from pulumi_azure_native import resources
from pulumi_azure_native import network
from pulumi_azure_native import containerservice
from pulumi_azure_native import compute

# Setting up variables
prefix_name = "pulumiAKS"

vnet_ip_range = "192.168.0.0/16"
aks_ip_range = "192.168.0.0/20"
vm_ip_range = "192.168.16.0/24"

ssh_key = "ssh-rsa AAAAB3NzaC1yc2EAAAABJQAAAQEAslS5LnoCJlj8OE4VncUK2iP6YhVT/RmeNkvP3VTd/GbiZd384wrD0rzr3MwEgMm4ZkjUQno54x+bpRhIFDha4Kj89cs7LwuPHZSkXLF+aVydxy2nu464TmflnhVVW71wLE9E3bCUxmh5+IZ3sJ8is2XQMuC1IHiIoEMFc+buMTG+kVc3f+VaJ5ZT+bFPjqs816YBPTSZRmUjzfwRcLIRXvlVxlFsMckhSTa7xCCxunsGKITOnqmlk/vIWr/bKfev6RD+qV8DFquM0zxquwcSv5ERXE384m6ESJ/YJ4IN5P14CDWT3pdZtwM1jOaL/zPyMHbamk5iTPLfuPao740plQ=="
# Create an Azure Resource Group
resource_group = resources.ResourceGroup(
    prefix_name+"-rg",
    resource_group_name=(prefix_name+"-rg"))

# Create network security group
nsg = network.NetworkSecurityGroup(
    resource_name=(prefix_name+"-nsg"),
    network_security_group_name=(prefix_name+"-nsg"),
    resource_group_name=resource_group.name,
    security_rules=[network.SecurityRuleArgs(
        access="Allow",
        destination_address_prefix="*",
        destination_port_range="22",
        direction="Inbound",
        name="Allow-SSH",
        priority=130,
        protocol="*",
        source_address_prefix="*",
        source_port_range="*",
    )])
# Create a VNET
vnet = network.VirtualNetwork(
    prefix_name+"-vnet",
    address_space=network.AddressSpaceArgs(
        address_prefixes=[vnet_ip_range],
    ),
    resource_group_name=resource_group.name,
    virtual_network_name=(prefix_name+"-vnet"))

aks_subnet = network.Subnet(
    "aks-subnet",
    address_prefix=aks_ip_range,
    resource_group_name=resource_group.name,
    subnet_name="aks-subnet",
    virtual_network_name=vnet.name)

vm_subnet = network.Subnet(
    "vm-subnet",
    address_prefix=vm_ip_range,
    resource_group_name=resource_group.name,
    subnet_name="vm-subnet",
    virtual_network_name=vnet.name,
    network_security_group=network.NetworkSecurityGroupArgs(
        id=nsg.id
    ))


# Create AKS cluster
aks_cluster = containerservice.ManagedCluster(
    addon_profiles={},
    agent_pool_profiles=[containerservice.ManagedClusterAgentPoolProfileArgs(
        count=1,
        enable_node_public_ip=False,
        mode="System",
        name="nodepool1",
        os_type="Linux",
        type="VirtualMachineScaleSets",
        vm_size="Standard_D2s_v4",
        vnet_subnet_id=aks_subnet.id
    )],
    api_server_access_profile=containerservice.ManagedClusterAPIServerAccessProfileArgs(
        enable_private_cluster=True
    ),
    dns_prefix=prefix_name,
    enable_rbac=True,
    identity=containerservice.ManagedClusterIdentityArgs(
        type=containerservice.ResourceIdentityType.SYSTEM_ASSIGNED),
    linux_profile=containerservice.ContainerServiceLinuxProfileArgs(
        admin_username="nilfranadmin",
        ssh=containerservice.ContainerServiceSshConfigurationArgs(
            public_keys=[containerservice.ContainerServiceSshPublicKeyArgs(
                key_data=ssh_key,
            )],
        ),
    ),
    network_profile=containerservice.ContainerServiceNetworkProfileArgs(
        load_balancer_sku="standard",
        outbound_type="loadBalancer",
        network_plugin="azure"
    ),
    resource_group_name=resource_group.name,
    resource_name=(prefix_name+"-aks"),
    sku=containerservice.ManagedClusterSKUArgs(
        name="Basic",
        tier="Free",
    ))

# Create VM
pip = network.PublicIPAddress(
    resource_name=(prefix_name+"-pip"),
    public_ip_address_name=(prefix_name+"-pip"),
    resource_group_name=resource_group.name
)


nic = network.NetworkInterface(
    resource_name=(prefix_name+"-nic"),
    ip_configurations=[network.NetworkInterfaceIPConfigurationArgs(
        name="ipconfig1",
        public_ip_address=network.PublicIPAddressArgs(
            id=pip.id,
        ),
        subnet=network.SubnetArgs(
            id=vm_subnet.id,
        ),
    )],
    network_interface_name=(prefix_name+"-nic"),
    resource_group_name=resource_group.name
)

vm = compute.VirtualMachine(
    resource_name=(prefix_name + "-vm"),
    hardware_profile=compute.HardwareProfileArgs(
        vm_size="Standard_D2s_v4",
    ),
    network_profile=compute.NetworkProfileArgs(
        network_interfaces=[compute.NetworkInterfaceReferenceArgs(
            id=nic.id,
            primary=True,
        )],
    ),
    os_profile=compute.OSProfileArgs(
        admin_username="nilfranadmin",
        computer_name=(prefix_name + "-vm"),
        linux_configuration=compute.LinuxConfigurationArgs(
            disable_password_authentication=True,
            ssh=compute.SshConfigurationArgs(
                public_keys=[compute.SshPublicKeyArgs(
                    key_data=ssh_key,
                    path="/home/nilfranadmin/.ssh/authorized_keys",
                )],
            ),
        ),
    ),
    resource_group_name=resource_group.name,
    storage_profile=compute.StorageProfileArgs(
        image_reference=compute.ImageReferenceArgs(
            offer="UbuntuServer",
            publisher="Canonical",
            sku="18.04-LTS",
            version="latest",
        ),
        os_disk=compute.OSDiskArgs(
            caching="ReadWrite",
            create_option="FromImage",
            managed_disk=compute.ManagedDiskParametersArgs(
                storage_account_type="StandardSSD_LRS",
            ),
            name=(prefix_name + "-vm-osdisk"),
        ),
    ),
    vm_name=(prefix_name + "-vm")
)
