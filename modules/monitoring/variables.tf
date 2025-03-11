
# Variables (equivalent to parameters in Bicep)
variable "location" {
  description = "The resource group location"
  type        = string
  default     = null # Will be populated from the current resource group in locals
}
