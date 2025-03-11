# Get current resource group
data "azurerm_resource_group" "current" {
  name = terraform.workspace
}

# Get current subscription
data "azurerm_subscription" "current" {}

# Built-in policy definitions (existing in tenant scope)
data "azurerm_policy_definition" "linux_security_agent" {
  name = "62b52eae-c795-44e3-94e8-1b3d264766fb" # Azure Security agent should be installed on your Linux virtual machine scale sets
}

data "azurerm_policy_definition" "windows_security_agent" {
  name = "e16f967a-aa57-4f5e-89cd-8d1434d0a29a" # Azure Security agent should be installed on your Windows virtual machine scale sets
}
