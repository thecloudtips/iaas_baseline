# Local variables
locals {
  key_vault_name                  = "kv-${var.base_name}"
  key_vault_private_endpoint_name = "pep-${local.key_vault_name}"
  key_vault_dns_group_name        = "default"
  key_vault_dns_zone_name         = "privatelink.vaultcore.azure.net"

  resource_group_name = var.resource_group_name != null ? var.resource_group_name : data.azurerm_resource_group.current.name
  location            = var.location != null ? var.location : data.azurerm_resource_group.current.location
}

# Key Vault
resource "azurerm_key_vault" "main" {
  name                            = local.key_vault_name
  location                        = local.location
  resource_group_name             = local.resource_group_name
  enabled_for_deployment          = false
  enabled_for_disk_encryption     = false
  enabled_for_template_deployment = false
  tenant_id                       = data.azurerm_client_config.current.tenant_id
  soft_delete_retention_days      = 7
  purge_protection_enabled        = false
  enable_rbac_authorization       = true
  public_network_access_enabled   = false

  sku_name = "standard"

  network_acls {
    default_action             = "Deny"
    bypass                     = "AzureServices" # Required for AppGW communication
    ip_rules                   = []
    virtual_network_subnet_ids = []
  }
}

# Key Vault Secrets
resource "azurerm_key_vault_secret" "app_gw_vmss_webserver_tls" {
  name         = "appgw-vmss-webserver-tls"
  value        = var.vmss_wildcard_tls_public_certificate
  key_vault_id = azurerm_key_vault.main.id
}

resource "azurerm_key_vault_secret" "gateway_public_cert" {
  name         = "gateway-public-cert"
  value        = var.app_gateway_listener_certificate
  key_vault_id = azurerm_key_vault.main.id
}

resource "azurerm_key_vault_secret" "workload_public_private_cert" {
  name         = "workload-public-private-cert"
  value        = var.vmss_wildcard_tls_public_and_key_certificates
  key_vault_id = azurerm_key_vault.main.id
  content_type = "application/x-pkcs12"
}

# Private Endpoint for Key Vault
resource "azurerm_private_endpoint" "key_vault" {
  name                          = local.key_vault_private_endpoint_name
  location                      = local.location
  resource_group_name           = local.resource_group_name
  subnet_id                     = data.azurerm_subnet.private_endpoints.id
  custom_network_interface_name = "nic-pe-${local.key_vault_private_endpoint_name}"
  private_service_connection {
    name                           = local.key_vault_private_endpoint_name
    private_connection_resource_id = azurerm_key_vault.main.id
    is_manual_connection           = false
    subresource_names              = ["vault"]
  }
}

# Private DNS Zone
resource "azurerm_private_dns_zone" "key_vault" {
  name                = local.key_vault_dns_zone_name
  resource_group_name = local.resource_group_name
}

# Virtual Network Link
resource "azurerm_private_dns_zone_virtual_network_link" "key_vault" {
  name                  = "${local.key_vault_dns_zone_name}-link"
  resource_group_name   = local.resource_group_name
  private_dns_zone_name = azurerm_private_dns_zone.key_vault.name
  virtual_network_id    = data.azurerm_virtual_network.main.id
  registration_enabled  = false
}

# Private DNS Zone Group
resource "azurerm_private_endpoint_dns_zone_group" "key_vault" {
  name                 = local.key_vault_dns_group_name
  resource_group_name  = local.resource_group_name
  private_dns_zone_ids = [azurerm_private_dns_zone.key_vault.id]
  private_endpoint_id  = azurerm_private_endpoint.key_vault.id
}
