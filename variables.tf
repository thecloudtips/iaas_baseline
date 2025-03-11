# Variables (equivalent to parameters in Bicep)
variable "location" {
  description = "IaaS region. This needs to be the same region as the vnet provided in these parameters."
  type        = string
  default     = "eastus2"
  validation {
    condition     = contains(["australiaeast", "canadacentral", "centralus", "eastus", "eastus2", "westus2", "francecentral", "germanywestcentral", "northeurope", "southafricanorth", "southcentralus", "uksouth", "westeurope", "japaneast", "southeastasia"], var.location)
    error_message = "The location must be one of the allowed Azure regions with availability zone support."
  }
}

variable "app_gateway_listener_certificate" {
  description = "The certificate data for app gateway TLS termination. It is base64 encoded"
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

variable "domain_name" {
  description = "Domain name to use for App Gateway and Vmss Webserver."
  type        = string
  default     = "contoso.com"
}

variable "frontend_cloud_init_as_base64" {
  description = "A cloud init file (starting with #cloud-config) as a base 64 encoded string used to perform image customization on the jump box VMs. Used for user-management in this context."
  type        = string
  validation {
    condition     = length(var.frontend_cloud_init_as_base64) >= 100
    error_message = "The frontend_cloud_init_as_base64 must be at least 100 characters long."
  }
}

variable "admin_password" {
  description = "The admin passwork for the Windows backend machines."
  type        = string
  sensitive   = true
}

variable "admin_security_principal_object_id" {
  description = "The Microsoft Entra group/user object id (guid) that will be assigned as the admin users for all deployed virtual machines."
  type        = string
  validation {
    condition     = length(var.admin_security_principal_object_id) >= 36
    error_message = "The admin_security_principal_object_id must be at least 36 characters long."
  }
}

variable "admin_security_principal_type" {
  description = "The principal type of the adminSecurityPrincipalObjectId ID."
  type        = string
  default     = "User"
  validation {
    condition     = contains(["User", "Group"], var.admin_security_principal_type)
    error_message = "The admin_security_principal_type must be either 'User' or 'Group'."
  }
}
