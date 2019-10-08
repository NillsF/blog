

resource "azurerm_kubernetes_cluster" "test" {
  name                = "aks-for-apim"
  location            = "${azurerm_resource_group.apim-aks.location}"
  resource_group_name = "${azurerm_resource_group.apim-aks.name}"
  dns_prefix          = "nfaksapim"

  agent_pool_profile {
    name            = "pool1"
    count           = 1
    vm_size         = "Standard_D2_v2"
    os_type         = "Linux"
    os_disk_size_gb = 30
    type = "VirtualMachineScaleSets"
    vnet_subnet_id = "${azurerm_subnet.aks.id}"
  }

  service_principal {
    client_id     = "${azuread_application.aksapim.application_id}"
    client_secret = "${random_string.sp-password.result}"
  }

}

resource "azurerm_role_assignment" "test" {
  scope                = "${azurerm_resource_group.apim-aks.id}"
  role_definition_name = "Contributor"
  principal_id         = "${azuread_service_principal.aksapim.id}"
}

output "client_certificate" {
  value = "${azurerm_kubernetes_cluster.test.kube_config.0.client_certificate}"
}

output "kube_config" {
  value = "${azurerm_kubernetes_cluster.test.kube_config_raw}"
}