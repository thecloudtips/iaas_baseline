# Variables
variable "resource_group_name" {
  description = "The resource group name where the resources are going to be deployed."
  type        = string
  default     = null # Will be populated from the current resource group
}

variable "base_name" {
  description = "This is the base name for each Azure resource name (6-12 chars)"
  type        = string
  validation {
    condition     = length(var.base_name) >= 6 && length(var.base_name) <= 12
    error_message = "The base_name must be between 6 and 12 characters."
  }
}

variable "location" {
  description = "The resource group location"
  type        = string
  default     = null # Will be populated from the current resource group
}

variable "app_gateway_listener_certificate" {
  description = "The certificate data for app gateway TLS termination. The value is base64 encoded."
  type        = string
  sensitive   = true
}

variable "vmss_wildcard_tls_public_certificate" {
  description = "The Base64 encoded Vmss Webserver public certificate (as .crt or .cer) to be stored in Azure Key Vault as secret and referenced by Azure Application Gateway as a trusted root certificate."
  type        = string
}

variable "vmss_wildcard_tls_public_and_key_certificates" {
  description = "The Base64 encoded Vmss Webserver public and private certificates (formatterd as .pem or .pfx) to be stored in Azure Key Vault as secret and downloaded into the frontend and backend Vmss instances for the workloads ssl certificate configuration."
  type        = string
  sensitive   = true
}

variable "vnet_name" {
  description = "The regional network VNet name that hosts the VM's NIC."
  type        = string
}

variable "private_endpoints_subnet_name" {
  description = "The subnet name for the private endpoints."
  type        = string
}

variable "key_vault_application_security_group_name" {
  description = "The name of the private endpoint keyvault Application Security Group."
  type        = string
}
