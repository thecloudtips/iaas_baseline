# Local variables
locals {
  vmss_backend_subdomain    = "backend"
  vmss_frontend_subdomain   = "frontend"
  vmss_frontend_domain_name = "${local.vmss_frontend_subdomain}.${var.ingress_domain_name}"
  default_admin_user_name   = substr(sha256("${var.base_name}${data.azurerm_resource_group.current.id}"), 0, 16)

  resource_group_name = var.resource_group_name != null ? var.resource_group_name : data.azurerm_resource_group.current.name
  location            = var.location != null ? var.location : data.azurerm_resource_group.current.location

  # For VM zone assignment
  zones = range(1, var.number_of_availability_zones + 1)
}

# Managed Identities
resource "azurerm_user_assigned_identity" "frontend" {
  name                = "id-vm-frontend"
  location            = local.location
  resource_group_name = local.resource_group_name
}

resource "azurerm_user_assigned_identity" "backend" {
  name                = "id-vm-backend"
  location            = local.location
  resource_group_name = local.resource_group_name
}

# Key Vault Role Assignments
resource "azurerm_role_assignment" "frontend_secrets_user" {
  scope              = data.azurerm_key_vault.main.id
  role_definition_id = data.azurerm_role_definition.key_vault_secrets_user.id
  principal_id       = azurerm_user_assigned_identity.frontend.principal_id
}

resource "azurerm_role_assignment" "frontend_key_vault_reader" {
  scope              = data.azurerm_key_vault.main.id
  role_definition_id = data.azurerm_role_definition.key_vault_reader.id
  principal_id       = azurerm_user_assigned_identity.frontend.principal_id
}

resource "azurerm_role_assignment" "backend_secrets_user" {
  scope              = data.azurerm_key_vault.main.id
  role_definition_id = data.azurerm_role_definition.key_vault_secrets_user.id
  principal_id       = azurerm_user_assigned_identity.backend.principal_id
}

resource "azurerm_role_assignment" "backend_key_vault_reader" {
  scope              = data.azurerm_key_vault.main.id
  role_definition_id = data.azurerm_role_definition.key_vault_reader.id
  principal_id       = azurerm_user_assigned_identity.backend.principal_id
}

# VM Admin Login Role Assignment
resource "azurerm_role_assignment" "admin_login" {
  scope              = data.azurerm_resource_group.current.id
  role_definition_id = data.azurerm_role_definition.vm_admin_login.id
  principal_id       = var.admin_security_principal_object_id
  principal_type     = var.admin_security_principal_type
  description        = "Allows users in this group or a single user access to log into virtual machines through Microsoft Entra ID."
}

# Private DNS Zone for the application
resource "azurerm_private_dns_zone" "contoso" {
  name                = var.ingress_domain_name
  resource_group_name = local.resource_group_name
}

resource "azurerm_private_dns_a_record" "backend" {
  name                = local.vmss_backend_subdomain
  zone_name           = azurerm_private_dns_zone.contoso.name
  resource_group_name = local.resource_group_name
  ttl                 = 3600
  records             = ["10.240.4.4"] # Internal Load Balancer IP address
}

resource "azurerm_private_dns_zone_virtual_network_link" "contoso" {
  name                  = "to_${data.azurerm_virtual_network.main.name}"
  resource_group_name   = local.resource_group_name
  private_dns_zone_name = azurerm_private_dns_zone.contoso.name
  virtual_network_id    = data.azurerm_virtual_network.main.id
  registration_enabled  = false
}

# VM Insights Solution
resource "azurerm_log_analytics_solution" "vm_insights" {
  solution_name         = "VMInsights"
  location              = local.location
  resource_group_name   = local.resource_group_name
  workspace_resource_id = data.azurerm_log_analytics_workspace.main.id
  workspace_name        = data.azurerm_log_analytics_workspace.main.name

  plan {
    publisher = "Microsoft"
    product   = "OMSGallery/VMInsights"
  }
}

# Frontend VMSS (Linux)
resource "azurerm_linux_virtual_machine_scale_set" "frontend" {
  name                            = "vmss-frontend"
  resource_group_name             = local.resource_group_name
  location                        = local.location
  sku                             = "Standard_D4s_v3"
  instances                       = 3
  admin_username                  = local.default_admin_user_name
  custom_data                     = var.frontend_cloud_init_as_base64
  health_probe_id                 = null
  upgrade_mode                    = "Automatic"
  disable_password_authentication = true
  overprovision                   = false
  single_placement_group          = false
  platform_fault_domain_count     = 1
  zones                           = local.zones

  identity {
    type = "UserAssigned"
    identity_ids = [
      azurerm_user_assigned_identity.frontend.id
    ]
  }

  admin_ssh_key {
    username   = local.default_admin_user_name
    public_key = var.ssh_public_key
  }

  automatic_instance_repair {
    enabled      = true
    grace_period = "PT30M"
  }

  boot_diagnostics {}

  os_disk {
    storage_account_type = "Standard_LRS"
    caching              = "ReadOnly"
    disk_size_gb         = 30

    diff_disk_settings {
      option    = "Local"
      placement = "CacheDisk"
    }
  }

  source_image_reference {
    publisher = "Canonical"
    offer     = "0001-com-ubuntu-server-focal"
    sku       = "20_04-lts-gen2"
    version   = "latest"
  }

  data_disk {
    lun                  = 0
    disk_size_gb         = 4
    caching              = "None"
    storage_account_type = "Premium_ZRS"
  }

  network_interface {
    name    = "nic-frontend"
    primary = true

    ip_configuration {
      name                                         = "default"
      primary                                      = true
      subnet_id                                    = data.azurerm_subnet.frontend.id
      application_security_group_ids               = [data.azurerm_application_security_group.frontend.id]
      load_balancer_backend_address_pool_ids       = [data.azurerm_lb_backend_address_pool.outbound.id]
      application_gateway_backend_address_pool_ids = [data.azurerm_application_gateway_backend_address_pool.webapp.id]
    }
  }

  extension {
    name                       = "AADSSHLogin"
    publisher                  = "Microsoft.Azure.ActiveDirectory"
    type                       = "AADSSHLoginForLinux"
    type_handler_version       = "1.0"
    auto_upgrade_minor_version = true
  }

  extension {
    name                       = "KeyVaultForLinux"
    publisher                  = "Microsoft.Azure.KeyVault"
    type                       = "KeyVaultForLinux"
    type_handler_version       = "2.0"
    auto_upgrade_minor_version = true
    settings = jsonencode({
      secretsManagementSettings = {
        certificateStoreLocation = "/var/lib/waagent/Microsoft.Azure.KeyVault.Store"
        observedCertificates     = [var.vmss_workload_public_and_private_public_certs_secret_uri]
        pollingIntervalInS       = "3600"
      }
    })
  }

  extension {
    name                       = "CustomScript"
    publisher                  = "Microsoft.Azure.Extensions"
    type                       = "CustomScript"
    type_handler_version       = "2.1"
    auto_upgrade_minor_version = true
    protected_settings = jsonencode({
      commandToExecute = "sh configure-nginx-frontend.sh"
      fileUris         = ["https://raw.githubusercontent.com/mspnp/iaas-baseline/main/configure-nginx-frontend.sh"]
    })
  }

  extension {
    name                       = "AzureMonitorLinuxAgent"
    publisher                  = "Microsoft.Azure.Monitor"
    type                       = "AzureMonitorLinuxAgent"
    type_handler_version       = "1.25"
    auto_upgrade_minor_version = true
    automatic_upgrade_enabled  = true
    settings = jsonencode({
      authentication = {
        managedIdentity = {
          "identifier-name"  = "mi_res_id"
          "identifier-value" = azurerm_user_assigned_identity.frontend.id
        }
      }
    })
  }

  extension {
    name                       = "DependencyAgentLinux"
    publisher                  = "Microsoft.Azure.Monitoring.DependencyAgent"
    type                       = "DependencyAgentLinux"
    type_handler_version       = "9.10"
    auto_upgrade_minor_version = true
    automatic_upgrade_enabled  = true
    settings = jsonencode({
      enableAMA = true
    })
  }

  extension {
    name                       = "HealthExtension"
    publisher                  = "Microsoft.ManagedServices"
    type                       = "ApplicationHealthLinux"
    type_handler_version       = "1.0"
    auto_upgrade_minor_version = true
    automatic_upgrade_enabled  = true
    settings = jsonencode({
      protocol          = "https"
      port              = 443
      requestPath       = "/favicon.ico"
      intervalInSeconds = 5
      numberOfProbes    = 3
    })
  }

  depends_on = [
    azurerm_role_assignment.frontend_secrets_user,
    azurerm_role_assignment.frontend_key_vault_reader,
    azurerm_linux_virtual_machine_scale_set.backend,
    azurerm_private_dns_a_record.backend,
    azurerm_private_dns_zone_virtual_network_link.contoso,
    data.azurerm_private_dns_zone_virtual_network_link.key_vault,
    azurerm_role_assignment.admin_login,
    azurerm_log_analytics_solution.vm_insights
  ]
}

# Backend VMSS (Linux) - Converted from Windows
resource "azurerm_linux_virtual_machine_scale_set" "backend" {
  name                            = "vmss-backend"
  resource_group_name             = local.resource_group_name
  location                        = local.location
  sku                             = "Standard_E2s_v3"
  instances                       = 3
  admin_username                  = local.default_admin_user_name
  custom_data                     = var.backend_cloud_init_as_base64
  health_probe_id                 = null
  upgrade_mode                    = "Automatic"
  disable_password_authentication = true
  overprovision                   = false
  single_placement_group          = false
  platform_fault_domain_count     = 1
  zones                           = local.zones

  identity {
    type = "UserAssigned"
    identity_ids = [
      azurerm_user_assigned_identity.backend.id
    ]
  }

  admin_ssh_key {
    username   = local.default_admin_user_name
    public_key = var.ssh_public_key
  }

  automatic_instance_repair {
    enabled      = true
    grace_period = "PT30M"
  }

  boot_diagnostics {}

  os_disk {
    storage_account_type = "Standard_LRS"
    caching              = "ReadOnly"
    disk_size_gb         = 30

    diff_disk_settings {
      option    = "Local"
      placement = "CacheDisk"
    }
  }

  source_image_reference {
    publisher = "Canonical"
    offer     = "0001-com-ubuntu-server-focal"
    sku       = "20_04-lts-gen2"
    version   = "latest"
  }

  data_disk {
    lun                  = 0
    disk_size_gb         = 4
    caching              = "None"
    storage_account_type = "Premium_ZRS"
  }

  network_interface {
    name    = "nic-backend"
    primary = true

    ip_configuration {
      name                           = "default"
      primary                        = true
      subnet_id                      = data.azurerm_subnet.backend.id
      application_security_group_ids = [data.azurerm_application_security_group.backend.id]
      load_balancer_backend_address_pool_ids = [
        data.azurerm_lb_backend_address_pool.api.id,
        data.azurerm_lb_backend_address_pool.outbound.id
      ]
    }
  }

  extension {
    name                       = "AADSSHLogin"
    publisher                  = "Microsoft.Azure.ActiveDirectory"
    type                       = "AADSSHLoginForLinux"
    type_handler_version       = "1.0"
    auto_upgrade_minor_version = true
  }

  extension {
    name                       = "KeyVaultForLinux"
    publisher                  = "Microsoft.Azure.KeyVault"
    type                       = "KeyVaultForLinux"
    type_handler_version       = "2.0"
    auto_upgrade_minor_version = true
    settings = jsonencode({
      secretsManagementSettings = {
        certificateStoreLocation = "/var/lib/waagent/Microsoft.Azure.KeyVault.Store"
        observedCertificates     = [var.vmss_workload_public_and_private_public_certs_secret_uri]
        pollingIntervalInS       = "3600"
      }
    })
  }

  extension {
    name                       = "CustomScript"
    publisher                  = "Microsoft.Azure.Extensions"
    type                       = "CustomScript"
    type_handler_version       = "2.1"
    auto_upgrade_minor_version = true
    protected_settings = jsonencode({
      commandToExecute = "sh configure-nginx-backend.sh"
      fileUris         = ["https://raw.githubusercontent.com/mspnp/iaas-baseline/main/configure-nginx-backend.sh"]
    })
  }

  extension {
    name                       = "AzureMonitorLinuxAgent"
    publisher                  = "Microsoft.Azure.Monitor"
    type                       = "AzureMonitorLinuxAgent"
    type_handler_version       = "1.25"
    auto_upgrade_minor_version = true
    automatic_upgrade_enabled  = true
    settings = jsonencode({
      authentication = {
        managedIdentity = {
          "identifier-name"  = "mi_res_id"
          "identifier-value" = azurerm_user_assigned_identity.backend.id
        }
      }
    })
  }

  extension {
    name                       = "DependencyAgentLinux"
    publisher                  = "Microsoft.Azure.Monitoring.DependencyAgent"
    type                       = "DependencyAgentLinux"
    type_handler_version       = "9.10"
    auto_upgrade_minor_version = true
    automatic_upgrade_enabled  = true
    settings = jsonencode({
      enableAMA = true
    })
  }

  extension {
    name                       = "HealthExtension"
    publisher                  = "Microsoft.ManagedServices"
    type                       = "ApplicationHealthLinux"
    type_handler_version       = "1.0"
    auto_upgrade_minor_version = true
    automatic_upgrade_enabled  = true
    settings = jsonencode({
      protocol          = "https"
      port              = 443
      requestPath       = "/favicon.ico"
      intervalInSeconds = 5
      numberOfProbes    = 3
    })
  }

  depends_on = [
    azurerm_role_assignment.backend_secrets_user,
    azurerm_role_assignment.backend_key_vault_reader,
    azurerm_private_dns_a_record.backend,
    azurerm_private_dns_zone_virtual_network_link.contoso,
    data.azurerm_private_dns_zone_virtual_network_link.key_vault,
    azurerm_role_assignment.admin_login,
    azurerm_log_analytics_solution.vm_insights
  ]
}
