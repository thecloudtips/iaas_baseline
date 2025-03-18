# Azure Provider configuration with enhanced feature management
provider "azurerm" {
  features {
    # Soft delete and key vault management configurations
    key_vault {
      purge_soft_delete_on_destroy    = true
      recover_soft_deleted_key_vaults = true
    }

    # Add additional provider features for better resource management
    virtual_machine_scale_set {
      roll_instances_when_required = true
    }
  }
}

# Local variables with migration-specific considerations
locals {
  # Unique identifier generation strategy
  sub_rg_unique_string = sha1("linux-vmss${data.azurerm_subscription.current.subscription_id}${data.azurerm_resource_group.current.id}")
  vmss_name            = "vmss-${local.sub_rg_unique_string}"

  # Domain and networking configurations
  ingress_domain_name          = "iaas-ingress.${var.domain_name}"
  number_of_availability_zones = 3
}

# Retain existing data sources
data "azurerm_subscription" "current" {}

data "azurerm_resource_group" "current" {
  name = terraform.workspace
}

# Modules remain largely unchanged, with potential minor adjustments
module "governance" {
  source   = "./modules/governance"
  location = var.location
}

module "monitoring" {
  source   = "./modules/monitoring"
  location = var.location
}

module "networking" {
  source                       = "./modules/networking"
  resource_group_name          = data.azurerm_resource_group.current.name
  location                     = var.location
  log_analytics_workspace_name = module.monitoring.log_analytics_workspace_name
}

# Key Vault module with Linux-specific certificate considerations
module "keyvault" {
  source                        = "./modules/keyvault"
  location                      = var.location
  base_name                     = local.vmss_name
  vnet_name                     = module.networking.vnet_name
  private_endpoints_subnet_name = module.networking.private_endpoints_subnet_name

  # Ensure certificates are compatible with Linux (PEM/Key formats)
  app_gateway_listener_certificate              = var.app_gateway_listener_certificate
  vmss_wildcard_tls_public_certificate          = var.vmss_wildcard_tls_public_certificate
  vmss_wildcard_tls_public_and_key_certificates = var.vmss_wildcard_tls_public_and_key_certificates
  key_vault_application_security_group_name     = module.networking.key_vault_application_security_group_name
}

# Load Balancer and Gateway modules remain consistent
module "internal_load_balancer" {
  source                             = "./modules/internal_load_balancer"
  location                           = var.location
  vnet_name                          = module.networking.vnet_name
  internal_load_balancer_subnet_name = module.networking.internal_load_balancer_subnet_name
  number_of_availability_zones       = local.number_of_availability_zones
  base_name                          = local.vmss_name
  log_analytics_workspace_name       = module.monitoring.log_analytics_workspace_name
}

module "outbound_load_balancer" {
  source                       = "./modules/outbound_load_balancer"
  location                     = var.location
  number_of_availability_zones = local.number_of_availability_zones
  base_name                    = local.vmss_name
  log_analytics_workspace_name = module.monitoring.log_analytics_workspace_name
}

module "gateway" {
  source                                   = "./modules/gateway"
  location                                 = var.location
  vnet_name                                = module.networking.vnet_name
  app_gateway_subnet_name                  = module.networking.app_gateway_subnet_name
  number_of_availability_zones             = local.number_of_availability_zones
  base_name                                = local.vmss_name
  key_vault_name                           = module.secrets.key_vault_name
  gateway_ssl_cert_secret_uri              = module.secrets.gateway_cert_secret_uri
  gateway_trusted_root_ssl_cert_secret_uri = module.secrets.gateway_trusted_root_ssl_cert_secret_uri
  gateway_host_name                        = var.domain_name
  ingress_domain_name                      = local.ingress_domain_name
  log_analytics_workspace_name             = module.monitoring.log_analytics_workspace_name
}

# VMSS Module with Linux-specific configurations
module "vmss" {
  source                                                   = "./modules/vmss"
  location                                                 = var.location
  vnet_name                                                = module.networking.vnet_name
  vmss_frontend_subnet_name                                = module.networking.vmss_frontend_subnet_name
  vmss_backend_subnet_name                                 = module.networking.vmss_backend_subnet_name
  number_of_availability_zones                             = local.number_of_availability_zones
  base_name                                                = local.vmss_name
  frontend_cloud_init_as_base64                            = var.frontend_cloud_init_as_base64
  backend_cloud_init_as_base64                             = var.backend_cloud_init_as_base64
  ssh_public_key                                           = var.ssh_public_key
  vmss_frontend_application_security_group_name            = module.networking.vmss_frontend_application_security_group_name
  vmss_backend_application_security_group_name             = module.networking.vmss_backend_application_security_group_name
  key_vault_name                                           = module.secrets.key_vault_name
  vmss_workload_public_and_private_public_certs_secret_uri = module.secrets.vmss_workload_public_and_private_public_certs_secret_uri
  agw_name                                                 = module.gateway.app_gateway_name
  ilb_name                                                 = module.internal_load_balancer.ilb_name
  olb_name                                                 = module.outbound_load_balancer.olb_name
  log_analytics_workspace_name                             = module.monitoring.log_analytics_workspace_name
  admin_security_principal_object_id                       = var.admin_security_principal_object_id
  admin_security_principal_type                            = var.admin_security_principal_type
  key_vault_dns_zone_name                                  = module.secrets.key_vault_dns_zone_name

}
