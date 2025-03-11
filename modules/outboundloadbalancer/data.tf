# Data sources for existing resources
data "azurerm_resource_group" "current" {
  name = local.resource_group_name
}

data "azurerm_log_analytics_workspace" "main" {
  name                = var.log_analytics_workspace_name
  resource_group_name = local.resource_group_name
}
