# Variables (equivalent to parameters in Bicep)
variable "location" {
  description = "The resource group location"
  type        = string
  default     = null # Will be populated from current resource group
}

variable "resource_group_name" {
  description = "The resource group name where the AppGw is going to be deployed."
  type        = string
  default     = null # Will be populated from current resource group
}

variable "number_of_availability_zones" {
  description = "The zones where the App Gw is going to be deployed."
  type        = number
  validation {
    condition     = var.number_of_availability_zones >= 1 && var.number_of_availability_zones <= 3
    error_message = "The number_of_availability_zones must be between 1 and 3."
  }
}

variable "vnet_name" {
  description = "The regional network Net name that hosts the VM's NIC."
  type        = string
}

variable "app_gateway_subnet_name" {
  description = "The subnet name that will host App Gw's NIC."
  type        = string
}

variable "base_name" {
  description = "This is the base name for each Azure resource name."
  type        = string
}

variable "gateway_ssl_cert_secret_uri" {
  description = "The Azure KeyVault secret uri for the App Gw frontend TLS certificate."
  type        = string
}

variable "gateway_trusted_root_ssl_cert_secret_uri" {
  description = "The Azure KeyVault secret uri for the backendpool wildcard TLS certificate."
  type        = string
}

variable "gateway_host_name" {
  description = "The public frontend domain name."
  type        = string
}

variable "key_vault_name" {
  description = "The Azure KeyVault where app gw secrets are stored."
  type        = string
}

variable "ingress_domain_name" {
  description = "The backend domain name."
  type        = string
}

variable "log_analytics_workspace_name" {
  description = "The Azure Log Analytics Workspace name."
  type        = string
}
