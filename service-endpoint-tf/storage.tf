resource "azurerm_storage_account" "example" {
  name                     = "tfendpint"
  location                 = azurerm_resource_group.main.location
  resource_group_name      = azurerm_resource_group.main.name
  account_tier             = "Standard"
  account_replication_type = "LRS"

  tags = {
    environment = "staging"
  }
    network_rules {
    default_action             = "Deny"
    virtual_network_subnet_ids = [azurerm_subnet.internal.id]
  }
}