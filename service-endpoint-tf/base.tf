provider "azurerm" {
  version = "=2.31"
  features {}
}

resource "azurerm_resource_group" "main" {
  name     = "tf-endpoint"
  location = "West US 2"
}