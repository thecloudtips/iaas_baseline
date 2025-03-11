# Data sources for existing resources
data "azurerm_resource_group" "current" {
  name = local.resource_group_name
}

data "azurerm_client_config" "current" {}

data "azurerm_subscription" "current" {}

# Existing Private DNS Zone
data "azurerm_private_dns_zone" "key_vault" {
  name                = var.key_vault_dns_zone_name
  resource_group_name = local.resource_group_name
}

data "azurerm_private_dns_zone_virtual_network_link" "key_vault" {
  name                  = "${var.key_vault_dns_zone_name}-link"
  private_dns_zone_name = data.azurerm_private_dns_zone.key_vault.name
  resource_group_name   = local.resource_group_name
}

# Existing role definitions
data "azurerm_role_definition" "key_vault_reader" {
  name  = "Key Vault Reader"
  scope = data.azurerm_subscription.current.id
}

data "azurerm_role_definition" "key_vault_secrets_user" {
  name  = "Key Vault Secrets User"
  scope = data.azurerm_subscription.current.id
}

data "azurerm_role_definition" "vm_admin_login" {
  name  = "Virtual Machine Administrator Login"
  scope = data.azurerm_subscription.current.id
}

# Existing Log Analytics Workspace
data "azurerm_log_analytics_workspace" "main" {
  name                = var.log_analytics_workspace_name
  resource_group_name = local.resource_group_name
}

# Existing Virtual Network and Subnets
data "azurerm_virtual_network" "main" {
  name                = var.vnet_name
  resource_group_name = local.resource_group_name
}

data "azurerm_subnet" "frontend" {
  name                 = var.vmss_frontend_subnet_name
  virtual_network_name = data.azurerm_virtual_network.main.name
  resource_group_name  = local.resource_group_name
}

data "azurerm_subnet" "backend" {
  name                 = var.vmss_backend_subnet_name
  virtual_network_name = data.azurerm_virtual_network.main.name
  resource_group_name  = local.resource_group_name
}

# Existing Application Security Groups
data "azurerm_application_security_group" "frontend" {
  name                = var.vmss_frontend_application_security_group_name
  resource_group_name = local.resource_group_name
}

data "azurerm_application_security_group" "backend" {
  name                = var.vmss_backend_application_security_group_name
  resource_group_name = local.resource_group_name
}

# Existing Load Balancers
data "azurerm_lb" "outbound" {
  name                = var.olb_name
  resource_group_name = local.resource_group_name
}

data "azurerm_lb" "internal" {
  name                = var.ilb_name
  resource_group_name = local.resource_group_name
}

# Existing Application Gateway
data "azurerm_application_gateway" "main" {
  name                = var.agw_name
  resource_group_name = local.resource_group_name
}

# Load Balancer Backend Address Pools
data "azurerm_lb_backend_address_pool" "outbound" {
  name            = "outboundBackendPool"
  loadbalancer_id = data.azurerm_lb.outbound.id
}

data "azurerm_lb_backend_address_pool" "api" {
  name            = "apiBackendPool"
  loadbalancer_id = data.azurerm_lb.internal.id
}

# Application Gateway Backend Address Pool
data "azurerm_application_gateway_backend_address_pool" "webapp" {
  name                     = "webappBackendPool"
  resource_group_name      = local.resource_group_name
  application_gateway_name = data.azurerm_application_gateway.main.name
}

# Key Vault for role assignments
data "azurerm_key_vault" "main" {
  name                = var.key_vault_name
  resource_group_name = local.resource_group_name
}
