terraform {
  required_providers {
    azurerm = {
      source = "hashicorp/azurerm"
      version = "3.38.0"
    }
    azuread = {
      source = "hashicorp/azuread"
      version = "2.31.0"
    }
  }
}

provider "azurerm" {
    features {
    }
}

provider "azuread" {
}

resource "azurerm_resource_group" "rg" {
  name     = "example-resources"
  location = "West Europe"
}

resource "azurerm_container_registry" "acr" {
  name                     = "ycetindil"
  resource_group_name      = azurerm_resource_group.rg.name
  location                 = azurerm_resource_group.rg.location
  sku                      = "Premium"
  admin_enabled            = true
  anonymous_pull_enabled   = true
}

resource "azuread_application" "acr-app" {
  display_name = "acr-app"
}

resource "azuread_service_principal" "acr-sp" {
  application_id = "${azuread_application.acr-app.application_id}"

}

resource "azuread_service_principal_password" "acr-sp-pass" {
  service_principal_id = "${azuread_service_principal.acr-sp.id}"
  end_date             = "2024-01-01T01:02:03Z"
}

resource "azurerm_role_assignment" "acr-assignment" {
  scope                = "${azurerm_container_registry.acr.id}"
  role_definition_name = "Contributor"
  principal_id         = "${azuread_service_principal_password.acr-sp-pass.service_principal_id}"
}

resource "null_resource" "docker_login" {
	provisioner "local-exec" {
	command = <<-EOT
	docker login ${azurerm_container_registry.acr.login_server} -u ${azuread_application.acr-app.application_id} -p ${azuread_service_principal_password.acr-sp-pass.value}
	EOT
	}
}

resource "null_resource" "docker_push" {
	provisioner "local-exec" {
	command = <<-EOT
	docker push ${azurerm_container_registry.acr.login_server}/samples/hw
	EOT
	}
}
