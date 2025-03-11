# Outputs
output "key_vault_name" {
  value = module.secrets.key_vault_name
}

output "app_gw_public_ip_address" {
  value = module.networking.app_gw_public_ip_address
}

output "bastion_host_name" {
  value = module.networking.bastion_host_name
}

output "backend_admin_user_name" {
  value = module.vmss.backend_admin_user_name
}

output "log_analytics_workspace_id" {
  value = module.monitoring.log_analytics_workspace_id
}