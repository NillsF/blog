resource "random_string" "sp-password" {
  length = 16
  special = true
  override_special = "/@£$"
}

resource "azuread_application" "aksapim" {
  name                       = "nf-aksapim-sp"
  homepage                   = "https://homepage"
  reply_urls                 = ["https://replyurl"]
  available_to_other_tenants = false
  oauth2_allow_implicit_flow = true
}

resource "azuread_service_principal" "aksapim" {
  application_id = "${azuread_application.aksapim.application_id}"
}

resource "azuread_service_principal_password" "aksapim" {
  service_principal_id = "${azuread_service_principal.aksapim.id}"
  value                = "${random_string.sp-password.result}"
  end_date             = "2020-01-01T01:02:03Z"
}