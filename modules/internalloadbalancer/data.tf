# Data sources for existing resources
data "azurerm_resource_group" "current" {
  name = terraform.workspace
}

data "azurerm_log_analytics_workspace" "main" {
  name                = var.log_analytics_workspace_name
  resource_group_name = data.azurerm_resource_group.current.name
}

data "azurerm_virtual_network" "main" {
  name                = var.vnet_name
  resource_group_name = data.azurerm_resource_group.current.name
}

data "azurerm_subnet" "internal_lb" {
  name                 = var.internal_load_balancer_subnet_name
  virtual_network_name = data.azurerm_virtual_network.main.name
  resource_group_name  = data.azurerm_resource_group.current.name
}
