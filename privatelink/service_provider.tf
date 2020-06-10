provider "azurerm" {
  features {}
  version = ">2.0"
}

resource "azurerm_resource_group" "privatelink_rg" {
  name     = "privatelink"
  location = "westus2"
}

resource "azurerm_virtual_network" "privatelink" {
  name                = "privatelink-network"
  address_space       = ["10.0.0.0/16"]
  location            = azurerm_resource_group.privatelink_rg.location
  resource_group_name = azurerm_resource_group.privatelink_rg.name
}

resource "azurerm_subnet" "internal" {
  name                 = "internal"
  resource_group_name  = azurerm_resource_group.privatelink_rg.name
  virtual_network_name = azurerm_virtual_network.privatelink.name
  address_prefix       = "10.0.1.0/24"
}

resource "azurerm_subnet" "privatelinkNAT" {
  name                 = "privatelinkNAT"
  resource_group_name  = azurerm_resource_group.privatelink_rg.name
  virtual_network_name = azurerm_virtual_network.privatelink.name
  address_prefix       = "10.0.2.0/24"
}

resource "azurerm_network_interface" "web-nic" {
  name                = "web-nic"
  location            = azurerm_resource_group.privatelink_rg.location
  resource_group_name = azurerm_resource_group.privatelink_rg.name

  ip_configuration {
    name                          = "internal"
    subnet_id                     = azurerm_subnet.internal.id
    private_ip_address_allocation = "Dynamic"
  }
}

resource "azurerm_network_interface" "ssh-nic" {
  name                = "ssh-nic"
  location            = azurerm_resource_group.privatelink_rg.location
  resource_group_name = azurerm_resource_group.privatelink_rg.name

  ip_configuration {
    name                          = "internal"
    subnet_id                     = azurerm_subnet.internal.id
    private_ip_address_allocation = "Dynamic"
  }
}

resource "azurerm_public_ip" "nat-pip" {
  name                = "nat-gateway-publicIP"
  location            = azurerm_resource_group.privatelink_rg.location
  resource_group_name = azurerm_resource_group.privatelink_rg.name
  allocation_method   = "Static"
  sku                 = "Standard"
}


resource "azurerm_nat_gateway" "natgw" {
  name                    = "nat-Gateway"
  location                = azurerm_resource_group.privatelink_rg.location
  resource_group_name     = azurerm_resource_group.privatelink_rg.name
  public_ip_address_ids   = [azurerm_public_ip.nat-pip.id]
  sku_name                = "Standard"
  idle_timeout_in_minutes = 10
}

resource "azurerm_subnet_nat_gateway_association" "internal-nat" {
  subnet_id      = azurerm_subnet.internal.id
  nat_gateway_id = azurerm_nat_gateway.natgw.id
}


resource "azurerm_linux_virtual_machine" "web" {
  name                = "web-machine"
  resource_group_name = azurerm_resource_group.privatelink_rg.name
  location            = azurerm_resource_group.privatelink_rg.location
  size                = "Standard_F2"
  admin_username      = "adminuser"
  network_interface_ids = [
    azurerm_network_interface.web-nic.id,
  ]

  admin_ssh_key {
    username   = "adminuser"
    public_key = file("~/.ssh/id_rsa.pub")
  }

  os_disk {
    caching              = "ReadWrite"
    storage_account_type = "Standard_LRS"
  }

  source_image_reference {
    publisher = "Canonical"
    offer     = "UbuntuServer"
    sku       = "18.04-LTS"
    version   = "latest"
  }
  
  custom_data = filebase64("cloud-init.yaml")
}

resource "azurerm_linux_virtual_machine" "ssh" {
  name                = "ssh-machine"
  resource_group_name = azurerm_resource_group.privatelink_rg.name
  location            = azurerm_resource_group.privatelink_rg.location
  size                = "Standard_F2"
  admin_username      = "adminuser"
  network_interface_ids = [
    azurerm_network_interface.ssh-nic.id,
  ]

  admin_ssh_key {
    username   = "adminuser"
    public_key = file("~/.ssh/id_rsa.pub")
  }

  os_disk {
    caching              = "ReadWrite"
    storage_account_type = "Standard_LRS"
  }

  source_image_reference {
    publisher = "Canonical"
    offer     = "UbuntuServer"
    sku       = "18.04-LTS"
    version   = "latest"
  }

}

resource "azurerm_lb" "ilb" {
  name                = "privatelink-lb"
  location            = azurerm_resource_group.privatelink_rg.location
  resource_group_name = azurerm_resource_group.privatelink_rg.name
  sku                 = "Standard"

  frontend_ip_configuration {
    name                 = "IP1"
    subnet_id            = azurerm_subnet.internal.id
    private_ip_address_version      = "IPv4"
  }
}

resource "azurerm_lb_backend_address_pool" "web-pool" {
  resource_group_name = azurerm_resource_group.privatelink_rg.name
  loadbalancer_id     = azurerm_lb.ilb.id
  name                = "web-pool"
}

resource "azurerm_lb_backend_address_pool" "ssh-pool" {
  resource_group_name = azurerm_resource_group.privatelink_rg.name
  loadbalancer_id     = azurerm_lb.ilb.id
  name                = "ssh-pool"
}

resource "azurerm_network_interface_backend_address_pool_association" "web" {
  network_interface_id    = azurerm_network_interface.web-nic.id
  ip_configuration_name   = "internal"
  backend_address_pool_id = azurerm_lb_backend_address_pool.web-pool.id
}

resource "azurerm_network_interface_backend_address_pool_association" "ssh" {
  network_interface_id    = azurerm_network_interface.ssh-nic.id
  ip_configuration_name   = "internal"
  backend_address_pool_id = azurerm_lb_backend_address_pool.ssh-pool.id
}

resource "azurerm_lb_probe" "web" {
  resource_group_name = azurerm_resource_group.privatelink_rg.name
  loadbalancer_id     = azurerm_lb.ilb.id
  name                = "web-running-probe"
  port                = 80
}

resource "azurerm_lb_probe" "ssh" {
  resource_group_name = azurerm_resource_group.privatelink_rg.name
  loadbalancer_id     = azurerm_lb.ilb.id
  name                = "ssh-running-probe"
  port                = 22
}

resource "azurerm_lb_rule" "web" {
  resource_group_name            = azurerm_resource_group.privatelink_rg.name
  loadbalancer_id                = azurerm_lb.ilb.id
  name                           = "web-rule"
  protocol                       = "Tcp"
  frontend_port                  = 80
  backend_port                   = 80
  frontend_ip_configuration_name = "IP1"
  probe_id                       = azurerm_lb_probe.web.id
  backend_address_pool_id        = azurerm_lb_backend_address_pool.web-pool.id
}

resource "azurerm_lb_rule" "ssh" {
  resource_group_name            = azurerm_resource_group.privatelink_rg.name
  loadbalancer_id                = azurerm_lb.ilb.id
  name                           = "ssh-rule"
  protocol                       = "Tcp"
  frontend_port                  = 22
  backend_port                   = 22
  frontend_ip_configuration_name = "IP1"
  probe_id                       = azurerm_lb_probe.ssh.id
  backend_address_pool_id        = azurerm_lb_backend_address_pool.ssh-pool.id
}