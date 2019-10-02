resource "azurerm_resource_group" "apim-aks" {
  name     = "blog-apim-and-aks"
  location = "WestUS2"
}

resource "azurerm_virtual_network" "apim-aks" {
  name                = "apim-aks-vnet"
  address_space       = ["10.0.0.0/16"]
  location            = "${azurerm_resource_group.apim-aks.location}"
  resource_group_name = "${azurerm_resource_group.apim-aks.name}"
}

resource "azurerm_subnet" "aks" {
  name                 = "aks-subnet"
  resource_group_name  = "${azurerm_resource_group.apim-aks.name}"
  virtual_network_name = "${azurerm_virtual_network.apim-aks.name}"
  address_prefix       = "10.0.1.0/24"
}

resource "azurerm_subnet" "apim" {
  name                 = "apim-subnet"
  resource_group_name  = "${azurerm_resource_group.apim-aks.name}"
  virtual_network_name = "${azurerm_virtual_network.apim-aks.name}"
  address_prefix       = "10.0.2.0/24"
}