# Data sources for existing resources
data "azurerm_resource_group" "current" {
  name = local.resource_group_name
}

data "azurerm_subscription" "current" {}

data "azurerm_role_definition" "key_vault_reader" {
  name  = "Key Vault Reader"
  scope = data.azurerm_subscription.current.id
}

data "azurerm_role_definition" "key_vault_secrets_user" {
  name  = "Key Vault Secrets User"
  scope = data.azurerm_subscription.current.id
}

data "azurerm_virtual_network" "main" {
  name                = var.vnet_name
  resource_group_name = local.resource_group_name
}

data "azurerm_subnet" "app_gateway" {
  name                 = var.app_gateway_subnet_name
  virtual_network_name = data.azurerm_virtual_network.main.name
  resource_group_name  = local.resource_group_name
}

data "azurerm_log_analytics_workspace" "main" {
  name                = var.log_analytics_workspace_name
  resource_group_name = local.resource_group_name
}

data "azurerm_key_vault" "main" {
  name                = var.key_vault_name
  resource_group_name = local.resource_group_name
}

data "azurerm_public_ip" "gateway" {
  name                = "pip-gw"
  resource_group_name = local.resource_group_name
}
