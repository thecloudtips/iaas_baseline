# Local variables
locals {
  agw_name                  = "agw-${var.base_name}"
  vmss_frontend_subdomain   = "frontend"
  vmss_frontend_domain_name = "${local.vmss_frontend_subdomain}.${var.ingress_domain_name}"

  # Set locals from variables with defaults
  resource_group_name = var.resource_group_name != null ? var.resource_group_name : data.azurerm_resource_group.current.name
  location            = var.location != null ? var.location : data.azurerm_resource_group.current.location

  # For zone assignment
  zones = range(1, var.number_of_availability_zones + 1)
}

# App Gateway Managed Identity
resource "azurerm_user_assigned_identity" "app_gateway" {
  name                = "id-appgateway"
  location            = local.location
  resource_group_name = local.resource_group_name
}

# Role Assignments for App Gateway Managed Identity
resource "azurerm_role_assignment" "app_gateway_secrets_user" {
  scope              = data.azurerm_key_vault.main.id
  role_definition_id = data.azurerm_role_definition.key_vault_secrets_user.id
  principal_id       = azurerm_user_assigned_identity.app_gateway.principal_id
}

resource "azurerm_role_assignment" "app_gateway_reader" {
  scope              = data.azurerm_key_vault.main.id
  role_definition_id = data.azurerm_role_definition.key_vault_reader.id
  principal_id       = azurerm_user_assigned_identity.app_gateway.principal_id
}

# WAF Policy
resource "azurerm_web_application_firewall_policy" "main" {
  name                = "waf-${var.base_name}"
  resource_group_name = local.resource_group_name
  location            = local.location

  policy_settings {
    enabled                 = true
    mode                    = "Prevention"
    file_upload_limit_in_mb = 10
    request_body_check      = true
  }

  managed_rules {
    managed_rule_set {
      type    = "OWASP"
      version = "3.2"
    }

    managed_rule_set {
      type    = "Microsoft_BotManagerRuleSet"
      version = "1.0"
    }
  }
}

# Application Gateway
resource "azurerm_application_gateway" "main" {
  name                = local.agw_name
  resource_group_name = local.resource_group_name
  location            = local.location
  zones               = local.zones
  firewall_policy_id  = azurerm_web_application_firewall_policy.main.id
  enable_http2        = false

  identity {
    type         = "UserAssigned"
    identity_ids = [azurerm_user_assigned_identity.app_gateway.id]
  }

  sku {
    name = "WAF_v2"
    tier = "WAF_v2"
  }

  ssl_policy {
    policy_type          = "Custom"
    min_protocol_version = "TLSv1_2"
    cipher_suites = [
      "TLS_ECDHE_RSA_WITH_AES_256_GCM_SHA384",
      "TLS_ECDHE_RSA_WITH_AES_128_GCM_SHA256"
    ]
  }

  trusted_root_certificate {
    name                = "root-cert-wildcard-vmss-webserver"
    key_vault_secret_id = var.gateway_trusted_root_ssl_cert_secret_uri
  }

  gateway_ip_configuration {
    name      = "agw-ip-configuration"
    subnet_id = data.azurerm_subnet.app_gateway.id
  }

  frontend_ip_configuration {
    name                 = "agw-frontend-ip-configuration"
    public_ip_address_id = data.azurerm_public_ip.gateway.id
  }

  frontend_port {
    name = "port-443"
    port = 443
  }

  autoscale_configuration {
    min_capacity = 0
    max_capacity = 10
  }

  ssl_certificate {
    name                = "${local.agw_name}-ssl-certificate"
    key_vault_secret_id = var.gateway_ssl_cert_secret_uri
  }

  probe {
    name                                      = "probe-${var.gateway_host_name}"
    protocol                                  = "Https"
    path                                      = "/favicon.ico"
    interval                                  = 30
    timeout                                   = 30
    unhealthy_threshold                       = 3
    pick_host_name_from_backend_http_settings = true
    minimum_servers                           = 0
  }

  backend_address_pool {
    name = "webappBackendPool"
  }

  backend_http_settings {
    name                                = "vmss-webserver-backendpool-httpsettings"
    cookie_based_affinity               = "Disabled"
    port                                = 443
    protocol                            = "Https"
    request_timeout                     = 20
    host_name                           = local.vmss_frontend_domain_name
    pick_host_name_from_backend_address = false
    probe_name                          = "probe-${var.gateway_host_name}"
    trusted_root_certificate_names      = ["root-cert-wildcard-vmss-webserver"]
  }

  http_listener {
    name                           = "listener-https"
    frontend_ip_configuration_name = "agw-frontend-ip-configuration"
    frontend_port_name             = "port-443"
    protocol                       = "Https"
    ssl_certificate_name           = "${local.agw_name}-ssl-certificate"
    host_name                      = var.gateway_host_name
    require_sni                    = true
  }

  request_routing_rule {
    name                       = "agw-routing-rules"
    rule_type                  = "Basic"
    http_listener_name         = "listener-https"
    backend_address_pool_name  = "webappBackendPool"
    backend_http_settings_name = "vmss-webserver-backendpool-httpsettings"
    priority                   = 100
  }

  depends_on = [
    azurerm_role_assignment.app_gateway_secrets_user,
    azurerm_role_assignment.app_gateway_reader
  ]

  # Prevent cycling issues
  lifecycle {
    ignore_changes = [
      backend_address_pool,
      backend_http_settings,
      http_listener,
      probe,
      request_routing_rule,
      url_path_map,
      trusted_root_certificate
    ]
  }
}

# Diagnostic Settings for App Gateway
resource "azurerm_monitor_diagnostic_setting" "app_gateway" {
  name                       = "default"
  target_resource_id         = azurerm_application_gateway.main.id
  log_analytics_workspace_id = data.azurerm_log_analytics_workspace.main.id

  enabled_log {
    category_group = "allLogs"
  }

  metric {
    category = "AllMetrics"
    enabled  = true
  }
}
