# Variables

variable "resource_group_name" {
  description = "The name of the resource group in which to create the VNet."
  type        = string
}

variable "location" {
  description = "Region on which to create the VNet. All resources tied to this VNet will also be homed in this region. The region passed as a parameter is assumed to have Availability Zone support."
  type        = string
  validation {
    condition     = contains(["australiaeast", "canadacentral", "centralus", "eastus", "eastus2", "westus2", "francecentral", "germanywestcentral", "northeurope", "southafricanorth", "southcentralus", "uksouth", "westeurope", "japaneast", "southeastasia"], var.location)
    error_message = "The location must be one of the supported Azure regions with Availability Zone support."
  }
}

variable "log_analytics_workspace_name" {
  description = "The Azure Log Analytics Workspace name."
  type        = string
}
