# Outputs

output "vnet_resource_id" {
  value = azurerm_virtual_network.main.id
}

output "vmss_subnet_resource_ids" {
  value = [
    azurerm_subnet.frontend.id,
    azurerm_subnet.backend.id
  ]
}

output "appgw_public_ip_address" {
  value = azurerm_public_ip.primary_workload.ip_address
}

output "bastion_host_name" {
  value = azurerm_bastion_host.main.name
}

output "vnet_name" {
  value = azurerm_virtual_network.main.name
}

output "privateendpoints_subnet_name" {
  value = azurerm_subnet.privatelinkendpoints.name
}

output "appgateway_subnet_name" {
  value = azurerm_subnet.applicationgateway.name
}

output "vmss_frontend_subnet_name" {
  value = azurerm_subnet.frontend.name
}

output "vmss_backend_subnet_name" {
  value = azurerm_subnet.backend.name
}

output "internal_loadbalancer_subnet_name" {
  value = azurerm_subnet.ilbs.name
}

output "log_analytics_workspace_name" {
  value = data.azurerm_log_analytics_workspace.main.name
}

output "vmss_frontend_application_security_group_name" {
  value = azurerm_application_security_group.frontend.name
}

output "vmss_backend_application_security_group_name" {
  value = azurerm_application_security_group.backend.name
}

output "keyvault_application_security_group_name" {
  value = azurerm_application_security_group.keyvault.name
}
