resource "azurerm_api_management" "apim" {
  name                = "blog-apim"
  location            = "${azurerm_resource_group.apim-aks.location}"
  resource_group_name = "${azurerm_resource_group.apim-aks.name}"
  publisher_name      = "Nills"
  publisher_email     = "nilfran@microsoft.com"

  sku {
    name     = "Developer"
    capacity = 1
  }
}

resource "azurerm_api_management_api" "back-end-api" {
  name                = "example-api"
  resource_group_name = "${azurerm_resource_group.apim-aks.name}"
  api_management_name = "${azurerm_api_management.apim.name}"
  revision            = "1"
  display_name        = "Example API"
  path                = "nginx"
  service_url          = "http://${kubernetes_service.example.load_balancer_ingress.0.ip}"
  protocols           = ["http"]
}

resource "azurerm_api_management_api_operation" "get" {
  operation_id        = "get"
  api_name            = "${azurerm_api_management_api.back-end-api.name}"
  api_management_name = "${azurerm_api_management.apim.name}"
  resource_group_name = "${azurerm_resource_group.apim-aks.name}"
  display_name        = "get"
  method              = "GET"
  url_template        = "/"

  response {
    status_code = 200
  }
}

resource "azurerm_api_management_product" "product" {
  product_id            = "nginx"
  api_management_name   = "${azurerm_api_management.apim.name}"
  resource_group_name   = "${azurerm_resource_group.apim-aks.name}"
  display_name          = "Test Product"
  subscription_required = false 
  published             = true
}

resource "azurerm_api_management_product_api" "example" {
  api_name            = "${azurerm_api_management_api.back-end-api.name}"
  product_id          = "${azurerm_api_management_product.product.product_id}"
  api_management_name = "${azurerm_api_management.apim.name}"
  resource_group_name = "${azurerm_api_management.apim.resource_group_name}"
}