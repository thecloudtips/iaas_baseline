# Data sources for existing resources
data "azurerm_resource_group" "current" {
  name = local.resource_group_name
}

data "azurerm_client_config" "current" {}

data "azurerm_virtual_network" "main" {
  name                = var.vnet_name
  resource_group_name = local.resource_group_name
}

data "azurerm_subnet" "private_endpoints" {
  name                 = var.private_endpoints_subnet_name
  virtual_network_name = data.azurerm_virtual_network.main.name
  resource_group_name  = local.resource_group_name
}

data "azurerm_application_security_group" "key_vault" {
  name                = var.key_vault_application_security_group_name
  resource_group_name = local.resource_group_name
}
