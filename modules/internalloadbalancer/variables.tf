# Variables (equivalent to parameters in Bicep)
variable "location" {
  description = "The resource group location"
  type        = string
  default     = null # Will be populated from current resource group
}

variable "number_of_availability_zones" {
  description = "The zones where the Internal Load Balancer is going to be deployed."
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

variable "internal_load_balancer_subnet_name" {
  description = "The subnet name that will host App Gw's NIC."
  type        = string
}

variable "base_name" {
  description = "This is the base name for each Azure resource name."
  type        = string
}

variable "log_analytics_workspace_name" {
  description = "The Azure Log Analytics Workspace name."
  type        = string
}
