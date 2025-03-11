# Local variables
locals {
  policy_assignment_name_prefix = "[IaaS baseline] -"
  location                      = var.location != null ? var.location : data.azurerm_resource_group.current.location
}

# Policy assignment for Linux VMs
resource "azurerm_policy_assignment" "linux_security_agent" {
  name                 = uuid() # Generates a unique ID, similar to guid() in Bicep
  scope                = data.azurerm_resource_group.current.id
  policy_definition_id = data.azurerm_policy_definition.linux_security_agent.id
  location             = local.location

  display_name = substr("${local.policy_assignment_name_prefix} ${data.azurerm_policy_definition.linux_security_agent.display_name}", 0, 120)
  description  = substr(data.azurerm_policy_definition.linux_security_agent.description, 0, 500)

  enforce = true # equivalent to enforcementMode: 'Default'

  parameters = jsonencode({
    effect = {
      value = "AuditIfNotExists"
    }
  })
}

# Policy assignment for Windows VMs
resource "azurerm_policy_assignment" "windows_security_agent" {
  name                 = uuid() # Generates a unique ID, similar to guid() in Bicep
  scope                = data.azurerm_resource_group.current.id
  policy_definition_id = data.azurerm_policy_definition.windows_security_agent.id
  location             = local.location

  display_name = substr("${local.policy_assignment_name_prefix} ${data.azurerm_policy_definition.windows_security_agent.display_name}", 0, 120)
  description  = substr(data.azurerm_policy_definition.windows_security_agent.description, 0, 500)

  enforce = true # equivalent to enforcementMode: 'Default'

  parameters = jsonencode({
    effect = {
      value = "AuditIfNotExists"
    }
  })
}
