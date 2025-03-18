// =============================================
// Location Configuration
// =============================================
location = "eastus2" // Must be one of the supported Azure regions with AZ support

// =============================================
// Domain and Authentication Settings
// =============================================
domain_name = "contoso.com"

admin_security_principal_object_id = "00000000-0000-0000-0000-000000000000" // Microsoft Entra ID (AAD) object ID
admin_security_principal_type      = "User"                                 // Or "Group"

// SSH public key for Linux VM authentication
ssh_public_key = "ssh-rsa AAAA..."

// =============================================
// Certificate Data (Base64 encoded)
// =============================================
// App Gateway listener certificate (base64 encoded)
app_gateway_listener_certificate = "MIIJqAIBA..."

// Public certificate for VMSS web server (base64 encoded)
vmss_wildcard_tls_public_certificate = "MIIFYjCC..."

// Public and private certificate bundle for VMSS (base64 encoded)
vmss_wildcard_tls_public_and_key_certificates = "MIIJkAIBA..."

// =============================================
// Cloud-Init Configurations (Base64 encoded)
// =============================================
// Frontend cloud-init configuration (base64 encoded)
frontend_cloud_init_as_base64 = "I2Nsb3VkLWNvbmZpZwp..."

// Backend cloud-init configuration (base64 encoded)
backend_cloud_init_as_base64 = "I2Nsb3VkLWNvbmZpZwp..."

// =============================================
// Virtual Machine Scale Set (VMSS) Settings
// =============================================
// Optional: Override VMSS instance sizes
// frontend_vm_size = "Standard_D4s_v3"
// backend_vm_size = "Standard_E2s_v3"

// Optional: Override VMSS instance counts
// frontend_instance_count = 3
// backend_instance_count = 3

// Optional: Override data disk size
// data_disk_size_gb = 4

// =============================================
// Network and Load Balancer Settings
// =============================================
// Optional: Override number of availability zones
// number_of_availability_zones = 3
