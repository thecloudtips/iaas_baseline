# Variables (equivalent to parameters in Bicep)
variable "vnet_name" {
  description = "The regional network VNet name that hosts the VM's NIC."
  type        = string
}

variable "vmss_frontend_subnet_name" {
  description = "The subnet name that will host vmss Frontend's NIC."
  type        = string
}

variable "vmss_backend_subnet_name" {
  description = "The subnet name that will host vmss Backend's NIC."
  type        = string
}

variable "location" {
  description = "The resource group location"
  type        = string
  default     = null # Will be set from the current resource group
}

variable "resource_group_name" {
  description = "The resource group name where the AppGw is going to be deployed."
  type        = string
  default     = null # Will be set from the current resource group
}

variable "number_of_availability_zones" {
  description = "The zones where the App Gw is going to be deployed."
  type        = number
  default     = 3
  validation {
    condition     = var.number_of_availability_zones >= 1 && var.number_of_availability_zones <= 3
    error_message = "The number of availability zones must be between 1 and 3."
  }
}

variable "base_name" {
  description = "This is the base name for each Azure resource name."
  type        = string
}

variable "ingress_domain_name" {
  description = "The backend domain name."
  type        = string
}

variable "frontend_cloud_init_as_base64" {
  description = "A cloud init file (starting with #cloud-config) as a base 64 encoded string used to perform image customization on the jump box VMs. Used for user-management in this context."
  type        = string
  validation {
    condition     = length(var.frontend_cloud_init_as_base64) >= 100
    error_message = "The frontend_cloud_init_as_base64 must be at least 100 characters long."
  }
}

variable "vmss_workload_public_and_private_public_certs_secret_uri" {
  description = "The Azure KeyVault secret uri for the frontend and backendpool wildcard TLS public and key certificate."
  type        = string
}

variable "key_vault_name" {
  description = "The Azure KeyVault where vmss secrets are stored."
  type        = string
}

variable "agw_name" {
  description = "The name of the Application Gateway."
  type        = string
}

variable "ilb_name" {
  description = "The Azure Internal Load Balancer name."
  type        = string
}

variable "olb_name" {
  description = "The Azure Outbound Load Balancer name."
  type        = string
}

variable "log_analytics_workspace_name" {
  description = "The Azure Log Analytics Workspace name."
  type        = string
}

variable "admin_password" {
  description = "The admin password for the Windows backend machines."
  type        = string
  sensitive   = true
}

variable "vmss_frontend_application_security_group_name" {
  description = "The name of the frontend Application Security Group."
  type        = string
}

variable "vmss_backend_application_security_group_name" {
  description = "The name of the backend Application Security Group."
  type        = string
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
  validation {
    condition     = contains(["User", "Group"], var.admin_security_principal_type)
    error_message = "The admin_security_principal_type must be either 'User' or 'Group'."
  }
}

variable "key_vault_dns_zone_name" {
  description = "The name of the Azure KeyVault Private DNS Zone."
  type        = string
}
