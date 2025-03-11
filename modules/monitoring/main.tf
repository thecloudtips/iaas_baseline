# Local variables
locals {
  policy_assignment_name_prefix = "[IaaS baseline] -"
  location                      = var.location != null ? var.location : data.azurerm_resource_group.current.location
}

# Get current resource group
data "azurerm_resource_group" "current" {
  name = terraform.workspace
}

# Reference to existing role definitions
data "azurerm_role_definition" "monitoring_contributor" {
  name  = "Monitoring Contributor"
  scope = data.azurerm_subscription.current.id
}

data "azurerm_role_definition" "log_analytics_contributor" {
  name  = "Log Analytics Contributor"
  scope = data.azurerm_subscription.current.id
}

# Current subscription
data "azurerm_subscription" "current" {}

# Built-in policy definitions
data "azurerm_policy_definition" "configure_linux_data_collection_rule" {
  display_name = "Deploy Data Collection Rule for Linux virtual machines"
}

data "azurerm_policy_definition" "configure_windows_data_collection_rule" {
  display_name = "Deploy Data Collection Rule for Windows virtual machines"
}

# Log Analytics workspace
resource "azurerm_log_analytics_workspace" "main" {
  name                = "log-${local.location}"
  location            = local.location
  resource_group_name = data.azurerm_resource_group.current.name
  sku                 = "PerGB2018"
  retention_in_days   = 30

  # These properties are in different format in Terraform compared to Bicep
  internet_ingestion_enabled = true
  internet_query_enabled     = true
  # Note: Terraform doesn't directly support all the nested properties in Bicep
  # like forceCmkForQuery, disableLocalAuth, etc.
  # Some may require using alternative methods or azapi provider
}

# Custom table in Log Analytics
resource "azurerm_log_analytics_table" "windows_logs" {
  name                = "WindowsLogsTable_CL"
  resource_group_name = data.azurerm_resource_group.current.name
  workspace_name      = azurerm_log_analytics_workspace.main.name
  retention_in_days   = 30

  # Define column schema
  column {
    name = "TimeGenerated"
    type = "datetime"
  }

  column {
    name = "RawData"
    type = "string"
  }
}

# Diagnostic settings for Log Analytics workspace
resource "azurerm_monitor_diagnostic_setting" "log_analytics" {
  name                       = "default"
  target_resource_id         = azurerm_log_analytics_workspace.main.id
  log_analytics_workspace_id = azurerm_log_analytics_workspace.main.id

  enabled_log {
    category_group = "audit"
  }

  metric {
    category = "AllMetrics"
    enabled  = true
  }
}

# Data Collection Endpoint for Windows VM logs
resource "azurerm_monitor_data_collection_endpoint" "windows_logs" {
  name                          = "dceWindowsLogs"
  resource_group_name           = data.azurerm_resource_group.current.name
  location                      = local.location
  kind                          = "Windows"
  public_network_access_enabled = true
}

# Change Tracking Solution for Log Analytics
resource "azurerm_log_analytics_solution" "change_tracking" {
  solution_name         = "ChangeTracking"
  location              = local.location
  resource_group_name   = data.azurerm_resource_group.current.name
  workspace_resource_id = azurerm_log_analytics_workspace.main.id
  workspace_name        = azurerm_log_analytics_workspace.main.name

  plan {
    publisher = "Microsoft"
    product   = "OMSGallery/ChangeTracking"
  }
}

# Windows VM Logs Custom Data Collection Rule
resource "azurerm_monitor_data_collection_rule" "windows_logs" {
  name                = "dcrWindowsLogs"
  resource_group_name = data.azurerm_resource_group.current.name
  location            = local.location
  kind                = "Windows"

  destinations {
    log_analytics {
      workspace_resource_id = azurerm_log_analytics_workspace.main.id
      name                  = azurerm_log_analytics_workspace.main.name
    }
  }

  data_flow {
    streams       = ["Custom-WindowsLogsTable_CL"]
    destinations  = [azurerm_log_analytics_workspace.main.name]
    transform_kql = "source | extend TimeGenerated = now()"
    output_stream = "Custom-WindowsLogsTable_CL"
  }

  # Custom Windows logs data source
  data_sources {
    log_file {
      streams       = ["Custom-WindowsLogsTable_CL"]
      file_patterns = ["W:\\nginx\\data\\*.log"]
      format        = "text"
      settings {
        text {
          record_start_timestamp_format = "yyyy-MM-ddTHH:mm:ssK"
        }
      }
      name = "Custom-WindowsLogsTable_CL"
    }
  }

  stream_declaration {
    stream_name = "Custom-WindowsLogsTable_CL"
    column {
      name = "TimeGenerated"
      type = "datetime"
    }
    column {
      name = "RawData"
      type = "string"
    }
  }

  depends_on = [azurerm_log_analytics_table.windows_logs, azurerm_monitor_data_collection_endpoint.windows_logs]
}

# Windows VM Events and Metrics Data Collection Rule
resource "azurerm_monitor_data_collection_rule" "windows_events_metrics" {
  name                = "dcrWindowsEventsAndMetrics"
  resource_group_name = data.azurerm_resource_group.current.name
  location            = local.location
  kind                = "Windows"
  description         = "Default data collection rule for Windows virtual machine."

  destinations {
    log_analytics {
      workspace_resource_id = azurerm_log_analytics_workspace.main.id
      name                  = azurerm_log_analytics_workspace.main.name
    }

    azure_monitor_metrics {
      name = "azureMonitorMetrics-default"
    }
  }

  data_flow {
    streams      = ["Microsoft-ConfigurationChange", "Microsoft-ConfigurationChangeV2", "Microsoft-ConfigurationData"]
    destinations = [azurerm_log_analytics_workspace.main.name]
  }

  data_flow {
    streams      = ["Microsoft-InsightsMetrics"]
    destinations = [azurerm_log_analytics_workspace.main.name]
  }

  data_flow {
    streams       = ["Microsoft-Event"]
    destinations  = [azurerm_log_analytics_workspace.main.name]
    transform_kql = "source"
    output_stream = "Microsoft-Event"
  }

  data_flow {
    streams      = ["Microsoft-ServiceMap"]
    destinations = [azurerm_log_analytics_workspace.main.name]
  }

  # Complex data sources for Windows VM with performance counters, extensions, and event logs
  data_sources {
    performance_counter {
      name                          = "VMInsightsPerfCounters"
      sampling_frequency_in_seconds = 60
      streams                       = ["Microsoft-InsightsMetrics"]
      counter_specifiers            = ["\\VmInsights\\DetailedMetrics"]
    }

    extension {
      name           = "CTDataSource-Windows"
      extension_name = "ChangeTracking-Windows"
      streams        = ["Microsoft-ConfigurationChange", "Microsoft-ConfigurationChangeV2", "Microsoft-ConfigurationData"]
      extension_json = jsonencode({
        enableFiles     = true
        enableSoftware  = true
        enableRegistry  = true
        enableServices  = true
        enableInventory = true
        registrySettings = {
          registryCollectionFrequency = 3000
          registryInfo = [
            {
              name        = "Registry_1"
              groupTag    = "Recommended"
              enabled     = false
              recurse     = true
              description = ""
              keyName     = "HKEY_LOCAL_MACHINE\\Software\\Microsoft\\Windows\\CurrentVersion\\Group Policy\\Scripts\\Startup"
              valueName   = ""
            },
            {
              name        = "Registry_2"
              groupTag    = "Recommended"
              enabled     = false
              recurse     = true
              description = ""
              keyName     = "HKEY_LOCAL_MACHINE\\Software\\Microsoft\\Windows\\CurrentVersion\\Group Policy\\Scripts\\Shutdown"
              valueName   = ""
            }
          ]
        }
        fileSettings = {
          fileCollectionFrequency = 2700
        }
        softwareSettings = {
          softwareCollectionFrequency = 1800
        }
        inventorySettings = {
          inventoryCollectionFrequency = 36000
        }
        servicesSettings = {
          serviceCollectionFrequency = 1800
        }
      })
    }

    extension {
      name           = "DependencyAgentDataSource"
      extension_name = "DependencyAgent"
      streams        = ["Microsoft-ServiceMap"]
      extension_json = jsonencode({})
    }

    windows_event_log {
      name    = "eventLogsDataSource"
      streams = ["Microsoft-Event"]
      x_path_queries = [
        "Application!*[System[(Level=1 or Level=2 or Level=3 or Level=4 or Level=0)]]",
        "Security!*[System[(band(Keywords,13510798882111488))]]",
        "System!*[System[(Level=1 or Level=2 or Level=3 or Level=4 or Level=0)]]"
      ]
    }
  }

  depends_on = [azurerm_log_analytics_solution.change_tracking]
}

# Linux VM Data Collection Rule
resource "azurerm_monitor_data_collection_rule" "linux_syslog_metrics" {
  name                = "dcrLinuxSyslogAndMetrics"
  resource_group_name = data.azurerm_resource_group.current.name
  location            = local.location
  kind                = "Linux"
  description         = "Default data collection rule for Linux virtual machines."

  destinations {
    log_analytics {
      workspace_resource_id = azurerm_log_analytics_workspace.main.id
      name                  = azurerm_log_analytics_workspace.main.name
    }
  }

  data_flow {
    streams      = ["Microsoft-ConfigurationChange", "Microsoft-ConfigurationChangeV2", "Microsoft-ConfigurationData"]
    destinations = [azurerm_log_analytics_workspace.main.name]
  }

  data_flow {
    streams      = ["Microsoft-InsightsMetrics"]
    destinations = [azurerm_log_analytics_workspace.main.name]
  }

  data_flow {
    streams      = ["Microsoft-ServiceMap"]
    destinations = [azurerm_log_analytics_workspace.main.name]
  }

  data_flow {
    streams       = ["Microsoft-Syslog"]
    destinations  = [azurerm_log_analytics_workspace.main.name]
    transform_kql = "source"
    output_stream = "Microsoft-Syslog"
  }

  # Complex data sources for Linux VM with performance counters, extensions, and syslog
  data_sources {
    performance_counter {
      name                          = "VMInsightsPerfCounters"
      sampling_frequency_in_seconds = 60
      streams                       = ["Microsoft-InsightsMetrics"]
      counter_specifiers            = ["\\VmInsights\\DetailedMetrics"]
    }

    extension {
      name           = "CTDataSource-Linux"
      extension_name = "ChangeTracking-Linux"
      streams        = ["Microsoft-ConfigurationChange", "Microsoft-ConfigurationChangeV2", "Microsoft-ConfigurationData"]
      extension_json = jsonencode({
        enableFiles     = true
        enableSoftware  = true
        enableRegistry  = false
        enableServices  = true
        enableInventory = true
        fileSettings = {
          fileCollectionFrequency = 900
          fileInfo = [
            {
              name                  = "ChangeTrackingLinuxPath_default"
              enabled               = true
              destinationPath       = "/etc/.*.conf"
              useSudo               = true
              recurse               = true
              maxContentsReturnable = 5000000
              pathType              = "File"
              type                  = "File"
              links                 = "Follow"
              maxOutputSize         = 500000
              groupTag              = "Recommended"
            }
          ]
        }
        softwareSettings = {
          softwareCollectionFrequency = 300
        }
        inventorySettings = {
          inventoryCollectionFrequency = 36000
        }
        servicesSettings = {
          serviceCollectionFrequency = 300
        }
      })
    }

    extension {
      name           = "DependencyAgentDataSource"
      extension_name = "DependencyAgent"
      streams        = ["Microsoft-ServiceMap"]
      extension_json = jsonencode({})
    }

    syslog {
      name           = "eventLogsDataSource-info"
      streams        = ["Microsoft-Syslog"]
      facility_names = ["auth", "authpriv"]
      log_levels     = ["Info", "Notice", "Warning", "Error", "Critical", "Alert", "Emergency"]
    }

    syslog {
      name    = "eventLogsDataSource-notice"
      streams = ["Microsoft-Syslog"]
      facility_names = [
        "cron", "daemon", "mark", "kern", "local0", "local1", "local2", "local3",
        "local4", "local5", "local6", "local7", "lpr", "mail", "news", "syslog",
        "user", "uucp"
      ]
      log_levels = ["Notice", "Warning", "Error", "Critical", "Alert", "Emergency"]
    }
  }

  depends_on = [azurerm_log_analytics_solution.change_tracking]
}

# Policy Assignment for Windows VM logs
resource "azurerm_policy_assignment" "windows_logs_data_collection" {
  name                 = uuid()
  scope                = data.azurerm_resource_group.current.id
  policy_definition_id = data.azurerm_policy_definition.configure_windows_data_collection_rule.id
  description          = substr(data.azurerm_policy_definition.configure_windows_data_collection_rule.description, 0, 500)
  display_name         = substr("${local.policy_assignment_name_prefix} Configure Windows virtual machines with logs data collection rules", 0, 120)
  location             = local.location

  identity {
    type = "SystemAssigned"
  }

  parameters = jsonencode({
    effect = {
      value = "DeployIfNotExists"
    },
    dcrResourceId = {
      value = azurerm_monitor_data_collection_rule.windows_logs.id
    },
    resourceType = {
      value = "Microsoft.Insights/dataCollectionRules"
    }
  })
}

# Policy Assignment for Windows VM events and metrics
resource "azurerm_policy_assignment" "windows_events_metrics_data_collection" {
  name                 = uuid()
  scope                = data.azurerm_resource_group.current.id
  policy_definition_id = data.azurerm_policy_definition.configure_windows_data_collection_rule.id
  description          = substr(data.azurerm_policy_definition.configure_windows_data_collection_rule.description, 0, 500)
  display_name         = substr("${local.policy_assignment_name_prefix} Configure Windows virtual machines with data collection rules", 0, 120)
  location             = local.location

  identity {
    type = "SystemAssigned"
  }

  parameters = jsonencode({
    effect = {
      value = "DeployIfNotExists"
    },
    dcrResourceId = {
      value = azurerm_monitor_data_collection_rule.windows_events_metrics.id
    },
    resourceType = {
      value = "Microsoft.Insights/dataCollectionRules"
    }
  })

  depends_on = [azurerm_log_analytics_solution.change_tracking]
}

# Policy Assignment for Linux VM syslog and metrics
resource "azurerm_policy_assignment" "linux_syslog_metrics_data_collection" {
  name                 = uuid()
  scope                = data.azurerm_resource_group.current.id
  policy_definition_id = data.azurerm_policy_definition.configure_linux_data_collection_rule.id
  description          = substr(data.azurerm_policy_definition.configure_linux_data_collection_rule.description, 0, 500)
  display_name         = substr("${local.policy_assignment_name_prefix} Configure Linux virtual machines with data collection rules", 0, 120)
  location             = local.location

  identity {
    type = "SystemAssigned"
  }

  parameters = jsonencode({
    effect = {
      value = "DeployIfNotExists"
    },
    dcrResourceId = {
      value = azurerm_monitor_data_collection_rule.linux_syslog_metrics.id
    },
    resourceType = {
      value = "Microsoft.Insights/dataCollectionRules"
    }
  })
}

# Role assignments for Windows Logs policy assignment
resource "azurerm_role_assignment" "windows_logs_log_analytics_contributor" {
  scope              = data.azurerm_resource_group.current.id
  role_definition_id = data.azurerm_role_definition.log_analytics_contributor.id
  principal_id       = azurerm_policy_assignment.windows_logs_data_collection.identity[0].principal_id
  principal_type     = "ServicePrincipal"
}

resource "azurerm_role_assignment" "windows_logs_monitoring_contributor" {
  scope              = data.azurerm_resource_group.current.id
  role_definition_id = data.azurerm_role_definition.monitoring_contributor.id
  principal_id       = azurerm_policy_assignment.windows_logs_data_collection.identity[0].principal_id
  principal_type     = "ServicePrincipal"
}

# Role assignments for Windows Events & Metrics policy assignment
resource "azurerm_role_assignment" "windows_events_metrics_log_analytics_contributor" {
  scope              = data.azurerm_resource_group.current.id
  role_definition_id = data.azurerm_role_definition.log_analytics_contributor.id
  principal_id       = azurerm_policy_assignment.windows_events_metrics_data_collection.identity[0].principal_id
  principal_type     = "ServicePrincipal"
}

resource "azurerm_role_assignment" "windows_events_metrics_monitoring_contributor" {
  scope              = data.azurerm_resource_group.current.id
  role_definition_id = data.azurerm_role_definition.monitoring_contributor.id
  principal_id       = azurerm_policy_assignment.windows_events_metrics_data_collection.identity[0].principal_id
  principal_type     = "ServicePrincipal"
}

# Role assignments for Linux Syslog & Metrics policy assignment
resource "azurerm_role_assignment" "linux_syslog_metrics_log_analytics_contributor" {
  scope              = data.azurerm_resource_group.current.id
  role_definition_id = data.azurerm_role_definition.log_analytics_contributor.id
  principal_id       = azurerm_policy_assignment.linux_syslog_metrics_data_collection.identity[0].principal_id
  principal_type     = "ServicePrincipal"
}

resource "azurerm_role_assignment" "linux_syslog_metrics_monitoring_contributor" {
  scope              = data.azurerm_resource_group.current.id
  role_definition_id = data.azurerm_role_definition.monitoring_contributor.id
  principal_id       = azurerm_policy_assignment.linux_syslog_metrics_data_collection.identity[0].principal_id
  principal_type     = "ServicePrincipal"
}

# Outputs
output "log_analytics_workspace_name" {
  value = azurerm_log_analytics_workspace.main.name
}

output "log_analytics_workspace_id" {
  value = azurerm_log_analytics_workspace.main.workspace_id
}
