# Local variables
locals {
  olb_name            = "olb-${var.base_name}"
  resource_group_name = var.resource_group_name != null ? var.resource_group_name : data.azurerm_resource_group.current.name
  location            = var.location != null ? var.location : data.azurerm_resource_group.current.location
  num_outbound_lb_ips = 3
  zones               = range(1, var.number_of_availability_zones + 1)
}

# Public IP Addresses for the Outbound Load Balancer
resource "azurerm_public_ip" "outbound_lb" {
  count                   = local.num_outbound_lb_ips
  name                    = "pip-olb-${local.location}-${format("%02d", count.index)}"
  location                = local.location
  resource_group_name     = local.resource_group_name
  allocation_method       = "Static"
  sku                     = "Standard"
  zones                   = local.zones
  idle_timeout_in_minutes = 4
  ip_version              = "IPv4"
}

# Diagnostic settings for Public IPs
resource "azurerm_monitor_diagnostic_setting" "outbound_lb_pips" {
  count                      = local.num_outbound_lb_ips
  name                       = "default"
  target_resource_id         = azurerm_public_ip.outbound_lb[count.index].id
  log_analytics_workspace_id = data.azurerm_log_analytics_workspace.main.id

  enabled_log {
    category_group = "audit"
  }

  metric {
    category = "AllMetrics"
    enabled  = true
  }
}

# Outbound Load Balancer
resource "azurerm_lb" "outbound" {
  name                = local.olb_name
  location            = local.location
  resource_group_name = local.resource_group_name
  sku                 = "Standard"

  # Create a frontend IP configuration for each public IP
  dynamic "frontend_ip_configuration" {
    for_each = azurerm_public_ip.outbound_lb
    content {
      name                 = frontend_ip_configuration.value.name
      public_ip_address_id = frontend_ip_configuration.value.id
    }
  }
}

# Backend address pool for the outbound load balancer
resource "azurerm_lb_backend_address_pool" "outbound" {
  name            = "outboundBackendPool"
  loadbalancer_id = azurerm_lb.outbound.id
}

# Outbound rule for the load balancer
resource "azurerm_lb_outbound_rule" "outbound" {
  name                     = "olbrule"
  loadbalancer_id          = azurerm_lb.outbound.id
  protocol                 = "Tcp"
  allocated_outbound_ports = 16000 # this value must be the total number of available ports divided the amount of vms
  idle_timeout_in_minutes  = 15
  enable_tcp_reset         = true
  backend_address_pool_id  = azurerm_lb_backend_address_pool.outbound.id

  # Reference all frontend IP configurations
  dynamic "frontend_ip_configuration" {
    for_each = azurerm_lb.outbound.frontend_ip_configuration
    content {
      name = frontend_ip_configuration.value.name
    }
  }
}

# Diagnostic settings for the Outbound Load Balancer
resource "azurerm_monitor_diagnostic_setting" "outbound_lb" {
  name                       = "default"
  target_resource_id         = azurerm_lb.outbound.id
  log_analytics_workspace_id = data.azurerm_log_analytics_workspace.main.id

  enabled_log {
    category_group = "allLogs"
  }

  metric {
    category = "AllMetrics"
    enabled  = true
  }
}
