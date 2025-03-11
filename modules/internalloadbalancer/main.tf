# Local variables
locals {
  ilb_name = "ilb-${var.base_name}"
  location = var.location != null ? var.location : data.azurerm_resource_group.current.location

  # Generate a list of zone numbers from 1 to number_of_availability_zones
  zones = range(1, var.number_of_availability_zones + 1)
}

# Internal Load Balancer Resource
resource "azurerm_lb" "internal" {
  name                = local.ilb_name
  location            = local.location
  resource_group_name = data.azurerm_resource_group.current.name
  sku                 = "Standard"

  frontend_ip_configuration {
    name                          = "ilbBackend"
    subnet_id                     = data.azurerm_subnet.internal_lb.id
    private_ip_address            = "10.240.4.4"
    private_ip_address_allocation = "Static"
    zones                         = local.zones
  }
}

# Backend address pool
resource "azurerm_lb_backend_address_pool" "api" {
  name            = "apiBackendPool"
  loadbalancer_id = azurerm_lb.internal.id
}

# Health probe
resource "azurerm_lb_probe" "main" {
  name                = "ilbprobe"
  loadbalancer_id     = azurerm_lb.internal.id
  protocol            = "Tcp"
  port                = 80
  interval_in_seconds = 15
  number_of_probes    = 2
}

# Load balancing rule
resource "azurerm_lb_rule" "main" {
  name                           = "ilbrule"
  loadbalancer_id                = azurerm_lb.internal.id
  frontend_ip_configuration_name = "ilbBackend"
  protocol                       = "Tcp"
  frontend_port                  = 443
  backend_port                   = 443
  backend_address_pool_ids       = [azurerm_lb_backend_address_pool.api.id]
  probe_id                       = azurerm_lb_probe.main.id
  idle_timeout_in_minutes        = 15
}

# Diagnostic settings for the internal load balancer
resource "azurerm_monitor_diagnostic_setting" "internal_lb" {
  name                       = "default"
  target_resource_id         = azurerm_lb.internal.id
  log_analytics_workspace_id = data.azurerm_log_analytics_workspace.main.id

  enabled_log {
    category_group = "allLogs"
  }

  metric {
    category = "AllMetrics"
    enabled  = true
  }
}
