# Local variables
locals {
  vnet_name = "vnet"
}

# Data sources for existing resources
data "azurerm_log_analytics_workspace" "main" {
  name                = var.log_analytics_workspace_name
  resource_group_name = var.resource_group_name
}

# Application Security Groups

resource "azurerm_application_security_group" "frontend" {
  name                = "asg-frontend"
  location            = var.location
  resource_group_name = var.resource_group_name
}

resource "azurerm_application_security_group" "backend" {
  name                = "asg-backend"
  location            = var.location
  resource_group_name = var.resource_group_name
}

resource "azurerm_application_security_group" "keyvault" {
  name                = "asg-keyvault"
  location            = var.location
  resource_group_name = var.resource_group_name
}

# Network Security Groups

# NSG around the Azure Bastion Subnet
resource "azurerm_network_security_group" "bastion" {
  name                = "nsg-${var.location}-bastion"
  location            = var.location
  resource_group_name = var.resource_group_name

  security_rule {
    name                       = "AllowWebExperienceInbound"
    description                = "Allow our users in. Update this to be as restrictive as possible."
    priority                   = 100
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "443"
    source_address_prefix      = "Internet"
    destination_address_prefix = "*"
  }

  security_rule {
    name                       = "AllowControlPlaneInbound"
    description                = "Service Requirement. Allow control plane access. Regional Tag not yet supported."
    priority                   = 110
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "443"
    source_address_prefix      = "GatewayManager"
    destination_address_prefix = "*"
  }

  security_rule {
    name                       = "AllowHealthProbesInbound"
    description                = "Service Requirement. Allow Health Probes."
    priority                   = 120
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "443"
    source_address_prefix      = "AzureLoadBalancer"
    destination_address_prefix = "*"
  }

  security_rule {
    name                       = "AllowBastionHostToHostInbound"
    description                = "Service Requirement. Allow Required Host to Host Communication."
    priority                   = 130
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "*"
    source_port_range          = "*"
    destination_port_ranges    = ["8080", "5701"]
    source_address_prefix      = "VirtualNetwork"
    destination_address_prefix = "VirtualNetwork"
  }

  security_rule {
    name                       = "DenyAllInbound"
    description                = "No further inbound traffic allowed."
    priority                   = 1000
    direction                  = "Inbound"
    access                     = "Deny"
    protocol                   = "*"
    source_port_range          = "*"
    destination_port_range     = "*"
    source_address_prefix      = "*"
    destination_address_prefix = "*"
  }

  security_rule {
    name                       = "AllowSshToVnetOutbound"
    description                = "Allow SSH out to the virtual network"
    priority                   = 100
    direction                  = "Outbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "22"
    source_address_prefix      = "*"
    destination_address_prefix = "VirtualNetwork"
  }

  security_rule {
    name                       = "AllowRdpToVnetOutbound"
    description                = "Allow RDP out to the virtual network"
    priority                   = 110
    direction                  = "Outbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "3389"
    source_address_prefix      = "*"
    destination_address_prefix = "VirtualNetwork"
  }

  security_rule {
    name                       = "AllowControlPlaneOutbound"
    description                = "Required for control plane outbound. Regional prefix not yet supported"
    priority                   = 120
    direction                  = "Outbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "443"
    source_address_prefix      = "*"
    destination_address_prefix = "AzureCloud"
  }

  security_rule {
    name                       = "AllowBastionHostToHostOutbound"
    description                = "Service Requirement. Allow Required Host to Host Communication."
    priority                   = 130
    direction                  = "Outbound"
    access                     = "Allow"
    protocol                   = "*"
    source_port_range          = "*"
    destination_port_ranges    = ["8080", "5701"]
    source_address_prefix      = "VirtualNetwork"
    destination_address_prefix = "VirtualNetwork"
  }

  security_rule {
    name                       = "AllowBastionCertificateValidationOutbound"
    description                = "Service Requirement. Allow Required Session and Certificate Validation."
    priority                   = 140
    direction                  = "Outbound"
    access                     = "Allow"
    protocol                   = "*"
    source_port_range          = "*"
    destination_port_range     = "80"
    source_address_prefix      = "*"
    destination_address_prefix = "Internet"
  }

  security_rule {
    name                       = "DenyAllOutbound"
    description                = "No further outbound traffic allowed."
    priority                   = 1000
    direction                  = "Outbound"
    access                     = "Deny"
    protocol                   = "*"
    source_port_range          = "*"
    destination_port_range     = "*"
    source_address_prefix      = "*"
    destination_address_prefix = "*"
  }
}

# NSG for the frontend subnet
resource "azurerm_network_security_group" "frontend" {
  name                = "nsg-${local.vnet_name}-frontend"
  location            = var.location
  resource_group_name = var.resource_group_name

  security_rule {
    name                                       = "AllowAppGwToToFrontendInbound"
    description                                = "Allow AppGw traffic inbound."
    priority                                   = 100
    direction                                  = "Inbound"
    access                                     = "Allow"
    protocol                                   = "Tcp"
    source_port_range                          = "*"
    destination_port_range                     = "*"
    source_address_prefix                      = "10.240.5.0/24"
    destination_application_security_group_ids = [azurerm_application_security_group.frontend.id]
  }

  security_rule {
    name                       = "AllowHealthProbesInbound"
    description                = "Allow Azure Health Probes in."
    priority                   = 110
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "*"
    source_port_range          = "*"
    destination_port_range     = "*"
    source_address_prefix      = "AzureLoadBalancer"
    destination_address_prefix = "*"
  }

  security_rule {
    name                                       = "AllowBastionSubnetSshInbound"
    description                                = "Allow Azure Azure Bastion in."
    priority                                   = 120
    direction                                  = "Inbound"
    access                                     = "Allow"
    protocol                                   = "Tcp"
    source_port_range                          = "*"
    destination_port_range                     = "22"
    source_address_prefix                      = "10.240.6.0/26"
    destination_application_security_group_ids = [azurerm_application_security_group.frontend.id]
  }

  security_rule {
    name                       = "DenyAllInbound"
    description                = "No further inbound traffic allowed."
    priority                   = 1000
    direction                  = "Inbound"
    access                     = "Deny"
    protocol                   = "*"
    source_port_range          = "*"
    destination_port_range     = "*"
    source_address_prefix      = "*"
    destination_address_prefix = "*"
  }

  security_rule {
    name                                       = "AllowFrontendToToBackenddApplicationSecurityGroupHTTPSOutbBund"
    description                                = "Allow frontend ASG outbound traffic to backend ASG 443."
    priority                                   = 100
    direction                                  = "Outbound"
    access                                     = "Allow"
    protocol                                   = "Tcp"
    source_port_range                          = "*"
    destination_port_range                     = "443"
    source_application_security_group_ids      = [azurerm_application_security_group.frontend.id]
    destination_application_security_group_ids = [azurerm_application_security_group.backend.id]
  }

  security_rule {
    name                       = "Allow443ToInternetOutBound"
    description                = "Allow VMs to communicate to Azure management APIs, Azure Storage, and perform install tasks."
    priority                   = 101
    direction                  = "Outbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "443"
    source_address_prefix      = "VirtualNetwork"
    destination_address_prefix = "Internet"
  }

  security_rule {
    name                       = "Allow80ToInternetOutBound"
    description                = "Allow Packer VM to use apt-get to upgrade packages"
    priority                   = 102
    direction                  = "Outbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "80"
    source_address_prefix      = "VirtualNetwork"
    destination_address_prefix = "Internet"
  }

  security_rule {
    name                       = "AllowVnetOutBound"
    description                = "Allow VM to communicate to other devices in the virtual network"
    priority                   = 110
    direction                  = "Outbound"
    access                     = "Allow"
    protocol                   = "*"
    source_port_range          = "*"
    destination_port_range     = "*"
    source_address_prefix      = "VirtualNetwork"
    destination_address_prefix = "VirtualNetwork"
  }

  security_rule {
    name                       = "DenyAllOutBound"
    description                = "Deny all remaining outbound traffic"
    priority                   = 1000
    direction                  = "Outbound"
    access                     = "Deny"
    protocol                   = "*"
    source_port_range          = "*"
    destination_port_range     = "*"
    source_address_prefix      = "*"
    destination_address_prefix = "*"
  }
}

# NSG for the backend subnet
resource "azurerm_network_security_group" "backend" {
  name                = "nsg-${local.vnet_name}-backend"
  location            = var.location
  resource_group_name = var.resource_group_name

  security_rule {
    name                                       = "AllowFrontendToToBackenddApplicationSecurityGroupHTTPSInbound"
    description                                = "Allow frontend ASG traffic into backend ASG 443."
    priority                                   = 100
    direction                                  = "Inbound"
    access                                     = "Allow"
    protocol                                   = "Tcp"
    source_port_range                          = "*"
    destination_port_range                     = "443"
    source_application_security_group_ids      = [azurerm_application_security_group.frontend.id]
    destination_application_security_group_ids = [azurerm_application_security_group.backend.id]
  }

  security_rule {
    name                       = "AllowHealthProbesInbound"
    description                = "Allow Azure Health Probes in."
    priority                   = 110
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "*"
    source_port_range          = "*"
    destination_port_range     = "*"
    source_address_prefix      = "AzureLoadBalancer"
    destination_address_prefix = "*"
  }

  security_rule {
    name                                       = "AllowBastionSubnetSshInbound"
    description                                = "Allow Azure Azure Bastion in."
    priority                                   = 120
    direction                                  = "Inbound"
    access                                     = "Allow"
    protocol                                   = "Tcp"
    source_port_range                          = "*"
    destination_port_range                     = "22"
    source_address_prefix                      = "10.240.6.0/26"
    destination_application_security_group_ids = [azurerm_application_security_group.backend.id]
  }

  security_rule {
    name                                       = "AllowBastionSubnetRdpInbound"
    description                                = "Allow Azure Azure Bastion in."
    priority                                   = 121
    direction                                  = "Inbound"
    access                                     = "Allow"
    protocol                                   = "Tcp"
    source_port_range                          = "*"
    destination_port_range                     = "3389"
    source_address_prefix                      = "10.240.6.0/26"
    destination_application_security_group_ids = [azurerm_application_security_group.backend.id]
  }

  security_rule {
    name                       = "DenyAllInbound"
    description                = "No further inbound traffic allowed."
    priority                   = 1000
    direction                  = "Inbound"
    access                     = "Deny"
    protocol                   = "*"
    source_port_range          = "*"
    destination_port_range     = "*"
    source_address_prefix      = "*"
    destination_address_prefix = "*"
  }

  security_rule {
    name                       = "Allow443ToInternetOutBound"
    description                = "Allow VMs to communicate to Azure management APIs, Azure Storage, and perform install tasks."
    priority                   = 100
    direction                  = "Outbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "443"
    source_address_prefix      = "VirtualNetwork"
    destination_address_prefix = "Internet"
  }

  security_rule {
    name                       = "Allow80ToInternetOutBound"
    description                = "Allow Packer VM to use apt-get to upgrade packages"
    priority                   = 102
    direction                  = "Outbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "80"
    source_address_prefix      = "VirtualNetwork"
    destination_address_prefix = "Internet"
  }

  security_rule {
    name                       = "AllowVnetOutBound"
    description                = "Allow VM to communicate to other devices in the virtual network"
    priority                   = 110
    direction                  = "Outbound"
    access                     = "Allow"
    protocol                   = "*"
    source_port_range          = "*"
    destination_port_range     = "*"
    source_address_prefix      = "VirtualNetwork"
    destination_address_prefix = "VirtualNetwork"
  }

  security_rule {
    name                       = "DenyAllOutBound"
    description                = "Deny all remaining outbound traffic"
    priority                   = 1000
    direction                  = "Outbound"
    access                     = "Deny"
    protocol                   = "*"
    source_port_range          = "*"
    destination_port_range     = "*"
    source_address_prefix      = "*"
    destination_address_prefix = "*"
  }
}

# NSG for internal load balancer subnet
resource "azurerm_network_security_group" "ilbs" {
  name                = "nsg-${local.vnet_name}-ilbs"
  location            = var.location
  resource_group_name = var.resource_group_name

  security_rule {
    name                                  = "AllowFrontendApplicationSecurityGroupHTTPSInbound"
    description                           = "Allow Frontend ASG web traffic into 443."
    priority                              = 100
    direction                             = "Inbound"
    access                                = "Allow"
    protocol                              = "Tcp"
    source_port_range                     = "*"
    destination_port_range                = "443"
    source_application_security_group_ids = [azurerm_application_security_group.frontend.id]
    destination_address_prefix            = "10.240.4.4"
  }

  security_rule {
    name                       = "AllowHealthProbesInbound"
    description                = "Allow Azure Health Probes in."
    priority                   = 110
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "*"
    source_port_range          = "*"
    destination_port_range     = "*"
    source_address_prefix      = "AzureLoadBalancer"
    destination_address_prefix = "*"
  }

  security_rule {
    name                       = "DenyAllInbound"
    description                = "No further inbound traffic allowed."
    priority                   = 1000
    direction                  = "Inbound"
    access                     = "Deny"
    protocol                   = "*"
    source_port_range          = "*"
    destination_port_range     = "*"
    source_address_prefix      = "*"
    destination_address_prefix = "*"
  }

  security_rule {
    name                       = "AllowAllOutbound"
    description                = "Allow all outbound"
    priority                   = 1000
    direction                  = "Outbound"
    access                     = "Allow"
    protocol                   = "*"
    source_port_range          = "*"
    destination_port_range     = "*"
    source_address_prefix      = "*"
    destination_address_prefix = "*"
  }
}

# NSG for application gateway subnet
resource "azurerm_network_security_group" "appgw" {
  name                = "nsg-${local.vnet_name}-appgw"
  location            = var.location
  resource_group_name = var.resource_group_name

  security_rule {
    name                       = "Allow443Inbound"
    description                = "Allow ALL web traffic into 443. (If you wanted to allow-list specific IPs, this is where you'd list them.)"
    priority                   = 100
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "443"
    source_address_prefix      = "Internet"
    destination_address_prefix = "VirtualNetwork"
  }

  security_rule {
    name                       = "AllowControlPlaneInbound"
    description                = "Allow Azure Control Plane in. (https://learn.microsoft.com/azure/application-gateway/configuration-infrastructure#network-security-groups)"
    priority                   = 110
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "*"
    source_port_range          = "*"
    destination_port_range     = "65200-65535"
    source_address_prefix      = "GatewayManager"
    destination_address_prefix = "*"
  }

  security_rule {
    name                       = "AllowHealthProbesInbound"
    description                = "Allow Azure Health Probes in. (https://learn.microsoft.com/azure/application-gateway/configuration-infrastructure#network-security-groups)"
    priority                   = 120
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "*"
    source_port_range          = "*"
    destination_port_range     = "*"
    source_address_prefix      = "AzureLoadBalancer"
    destination_address_prefix = "*"
  }

  security_rule {
    name                       = "DenyAllInbound"
    description                = "No further inbound traffic allowed."
    priority                   = 1000
    direction                  = "Inbound"
    access                     = "Deny"
    protocol                   = "*"
    source_port_range          = "*"
    destination_port_range     = "*"
    source_address_prefix      = "*"
    destination_address_prefix = "*"
  }

  security_rule {
    name                       = "AllowAllOutbound"
    description                = "App Gateway v2 requires full outbound access."
    priority                   = 1000
    direction                  = "Outbound"
    access                     = "Allow"
    protocol                   = "*"
    source_port_range          = "*"
    destination_port_range     = "*"
    source_address_prefix      = "*"
    destination_address_prefix = "*"
  }
}

# NSG for private link endpoints subnet
resource "azurerm_network_security_group" "privatelinkendpoints" {
  name                = "nsg-${local.vnet_name}-privatelinkendpoints"
  location            = var.location
  resource_group_name = var.resource_group_name

  security_rule {
    name                                       = "AllowAll443InFromVnet"
    priority                                   = 100
    direction                                  = "Inbound"
    access                                     = "Allow"
    protocol                                   = "Tcp"
    source_port_range                          = "*"
    destination_port_range                     = "443"
    source_address_prefix                      = "VirtualNetwork"
    destination_application_security_group_ids = [azurerm_application_security_group.keyvault.id]
  }

  security_rule {
    name                       = "DenyAllInbound"
    priority                   = 1000
    direction                  = "Inbound"
    access                     = "Deny"
    protocol                   = "*"
    source_port_range          = "*"
    destination_port_range     = "*"
    source_address_prefix      = "*"
    destination_address_prefix = "*"
  }

  security_rule {
    name                       = "DenyAllOutbound"
    priority                   = 1000
    direction                  = "Outbound"
    access                     = "Deny"
    protocol                   = "*"
    source_port_range          = "*"
    destination_port_range     = "*"
    source_address_prefix      = "*"
    destination_address_prefix = "*"
  }
}

# NSG for deployment agent subnet
resource "azurerm_network_security_group" "deploymentagent" {
  name                = "nsg-${local.vnet_name}-deploymentagent"
  location            = var.location
  resource_group_name = var.resource_group_name

  security_rule {
    name                       = "AllowAll443InFromVnet"
    priority                   = 100
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "443"
    source_address_prefix      = "VirtualNetwork"
    destination_address_prefix = "VirtualNetwork"
  }

  security_rule {
    name                       = "DenyAllInbound"
    priority                   = 1000
    direction                  = "Inbound"
    access                     = "Deny"
    protocol                   = "*"
    source_port_range          = "*"
    destination_port_range     = "*"
    source_address_prefix      = "*"
    destination_address_prefix = "*"
  }

  security_rule {
    name                       = "DenyAllOutbound"
    priority                   = 1000
    direction                  = "Outbound"
    access                     = "Deny"
    protocol                   = "*"
    source_port_range          = "*"
    destination_port_range     = "*"
    source_address_prefix      = "*"
    destination_address_prefix = "*"
  }
}

# Diagnostic Settings for NSGs

resource "azurerm_monitor_diagnostic_setting" "bastion_nsg" {
  name                       = "default"
  target_resource_id         = azurerm_network_security_group.bastion.id
  log_analytics_workspace_id = data.azurerm_log_analytics_workspace.main.id

  enabled_log {
    category_group = "allLogs"
  }
}

resource "azurerm_monitor_diagnostic_setting" "frontend_nsg" {
  name                       = "default"
  target_resource_id         = azurerm_network_security_group.frontend.id
  log_analytics_workspace_id = data.azurerm_log_analytics_workspace.main.id

  enabled_log {
    category_group = "allLogs"
  }
}

resource "azurerm_monitor_diagnostic_setting" "backend_nsg" {
  name                       = "default"
  target_resource_id         = azurerm_network_security_group.backend.id
  log_analytics_workspace_id = data.azurerm_log_analytics_workspace.main.id

  enabled_log {
    category_group = "allLogs"
  }
}

resource "azurerm_monitor_diagnostic_setting" "ilbs_nsg" {
  name                       = "default"
  target_resource_id         = azurerm_network_security_group.ilbs.id
  log_analytics_workspace_id = data.azurerm_log_analytics_workspace.main.id

  enabled_log {
    category_group = "allLogs"
  }
}

resource "azurerm_monitor_diagnostic_setting" "appgw_nsg" {
  name                       = "default"
  target_resource_id         = azurerm_network_security_group.appgw.id
  log_analytics_workspace_id = data.azurerm_log_analytics_workspace.main.id

  enabled_log {
    category_group = "allLogs"
  }
}

resource "azurerm_monitor_diagnostic_setting" "privatelinkendpoints_nsg" {
  name                       = "default"
  target_resource_id         = azurerm_network_security_group.privatelinkendpoints.id
  log_analytics_workspace_id = data.azurerm_log_analytics_workspace.main.id

  enabled_log {
    category_group = "allLogs"
  }
}

# Virtual Network and Subnets

resource "azurerm_virtual_network" "main" {
  name                = local.vnet_name
  location            = var.location
  resource_group_name = var.resource_group_name
  address_space       = ["10.240.0.0/21"]
}

resource "azurerm_subnet" "frontend" {
  name                                          = "snet-frontend"
  resource_group_name                           = var.resource_group_name
  virtual_network_name                          = azurerm_virtual_network.main.name
  address_prefixes                              = ["10.240.0.0/24"]
  private_link_service_network_policies_enabled = false
}

resource "azurerm_subnet" "backend" {
  name                                          = "snet-backend"
  resource_group_name                           = var.resource_group_name
  virtual_network_name                          = azurerm_virtual_network.main.name
  address_prefixes                              = ["10.240.1.0/24"]
  private_link_service_network_policies_enabled = false
}

resource "azurerm_subnet" "ilbs" {
  name                                          = "snet-ilbs"
  resource_group_name                           = var.resource_group_name
  virtual_network_name                          = azurerm_virtual_network.main.name
  address_prefixes                              = ["10.240.4.0/28"]
  private_link_service_network_policies_enabled = false
}

resource "azurerm_subnet" "privatelinkendpoints" {
  name                                          = "snet-privatelinkendpoints"
  resource_group_name                           = var.resource_group_name
  virtual_network_name                          = azurerm_virtual_network.main.name
  address_prefixes                              = ["10.240.4.32/28"]
  private_link_service_network_policies_enabled = true
}

resource "azurerm_subnet" "deploymentagent" {
  name                                          = "snet-deploymentagent"
  resource_group_name                           = var.resource_group_name
  virtual_network_name                          = azurerm_virtual_network.main.name
  address_prefixes                              = ["10.240.4.64/28"]
  private_link_service_network_policies_enabled = true
}

resource "azurerm_subnet" "applicationgateway" {
  name                                          = "snet-applicationgateway"
  resource_group_name                           = var.resource_group_name
  virtual_network_name                          = azurerm_virtual_network.main.name
  address_prefixes                              = ["10.240.5.0/24"]
  private_link_service_network_policies_enabled = false
}

resource "azurerm_subnet" "bastion" {
  name                 = "AzureBastionSubnet" # This name is required by Azure
  resource_group_name  = var.resource_group_name
  virtual_network_name = azurerm_virtual_network.main.name
  address_prefixes     = ["10.240.6.0/26"]
}

# Subnet NSG Associations
resource "azurerm_subnet_network_security_group_association" "frontend" {
  subnet_id                 = azurerm_subnet.frontend.id
  network_security_group_id = azurerm_network_security_group.frontend.id
}

resource "azurerm_subnet_network_security_group_association" "backend" {
  subnet_id                 = azurerm_subnet.backend.id
  network_security_group_id = azurerm_network_security_group.backend.id
}

resource "azurerm_subnet_network_security_group_association" "ilbs" {
  subnet_id                 = azurerm_subnet.ilbs.id
  network_security_group_id = azurerm_network_security_group.ilbs.id
}

resource "azurerm_subnet_network_security_group_association" "privatelinkendpoints" {
  subnet_id                 = azurerm_subnet.privatelinkendpoints.id
  network_security_group_id = azurerm_network_security_group.privatelinkendpoints.id
}

resource "azurerm_subnet_network_security_group_association" "applicationgateway" {
  subnet_id                 = azurerm_subnet.applicationgateway.id
  network_security_group_id = azurerm_network_security_group.appgw.id
}

resource "azurerm_subnet_network_security_group_association" "bastion" {
  subnet_id                 = azurerm_subnet.bastion.id
  network_security_group_id = azurerm_network_security_group.bastion.id
}

# Diagnostic setting for VNet
resource "azurerm_monitor_diagnostic_setting" "vnet" {
  name                       = "default"
  target_resource_id         = azurerm_virtual_network.main.id
  log_analytics_workspace_id = data.azurerm_log_analytics_workspace.main.id

  metric {
    category = "AllMetrics"
    enabled  = true
  }
}

# Bastion Host and Public IPs

# Public IP for Bastion Host
resource "azurerm_public_ip" "bastion" {
  name                    = "pip-ab-${var.location}"
  location                = var.location
  resource_group_name     = var.resource_group_name
  allocation_method       = "Static"
  sku                     = "Standard"
  zones                   = [1, 2, 3] # Explicit zones for the Public IP
  idle_timeout_in_minutes = 4
  ip_version              = "IPv4"
}

# Diagnostic setting for Bastion Public IP
resource "azurerm_monitor_diagnostic_setting" "bastion_pip" {
  name                       = "default"
  target_resource_id         = azurerm_public_ip.bastion.id
  log_analytics_workspace_id = data.azurerm_log_analytics_workspace.main.id

  enabled_log {
    category_group = "audit"
  }

  metric {
    category = "AllMetrics"
    enabled  = true
  }
}

# Bastion Host
resource "azurerm_bastion_host" "main" {
  name                = "ab-${var.location}"
  location            = var.location
  resource_group_name = var.resource_group_name
  sku                 = "Standard"
  tunneling_enabled   = true

  ip_configuration {
    name                 = "hub-subnet"
    subnet_id            = azurerm_subnet.bastion.id
    public_ip_address_id = azurerm_public_ip.bastion.id
  }
}

# Diagnostic setting for Bastion Host
resource "azurerm_monitor_diagnostic_setting" "bastion_host" {
  name                       = "default"
  target_resource_id         = azurerm_bastion_host.main.id
  log_analytics_workspace_id = data.azurerm_log_analytics_workspace.main.id

  enabled_log {
    category = "BastionAuditLogs"
  }
}

# Public IP for primary workload (Application Gateway)
resource "azurerm_public_ip" "primary_workload" {
  name                    = "pip-gw"
  location                = var.location
  resource_group_name     = var.resource_group_name
  allocation_method       = "Static"
  sku                     = "Standard"
  zones                   = [1, 2, 3] # Explicit zones for the Public IP
  idle_timeout_in_minutes = 4
  ip_version              = "IPv4"
}

# Diagnostic setting for Primary Workload Public IP
resource "azurerm_monitor_diagnostic_setting" "primary_workload_pip" {
  name                       = "default"
  target_resource_id         = azurerm_public_ip.primary_workload.id
  log_analytics_workspace_id = data.azurerm_log_analytics_workspace.main.id

  enabled_log {
    category_group = "audit"
  }

  metric {
    category = "AllMetrics"
    enabled  = true
  }
}
