# Outputs
output "key_vault_name" {
  description = "The name of the key vault account."
  value       = azurerm_key_vault.main.name
}

output "gateway_cert_secret_uri" {
  description = "Uri to the secret holding the gateway listener key cert."
  value       = azurerm_key_vault_secret.gateway_public_cert.id
  sensitive   = true
}

output "gateway_trusted_root_ssl_cert_secret_uri" {
  description = "Uri to the secret holding the vmss wildcard cert."
  value       = azurerm_key_vault_secret.app_gw_vmss_webserver_tls.id
  sensitive   = true
}

output "vmss_workload_public_and_private_public_certs_secret_uri" {
  description = "Uri to the secret holding the vmss wildcard cert."
  value       = azurerm_key_vault_secret.workload_public_private_cert.id
  sensitive   = true
}

output "key_vault_dns_zone_name" {
  description = "The name of the Azure KeyVault Private DNS Zone."
  value       = azurerm_private_dns_zone.key_vault.name
}
