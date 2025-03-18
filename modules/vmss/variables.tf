# Core VM configuration variables
variable "base_name" {
  description = "This is the base name for each Azure resource name."
  type        = string
}

variable "vm_size" {
  description = "The default size of the virtual machines (can be overridden by frontend/backend specific variables)"
  type        = string
  default     = "Standard_D4s_v3"
}

variable "frontend_vm_size" {
  description = "The size of the frontend virtual machines"
  type        = string
  default     = "Standard_D4s_v3"
}

variable "backend_vm_size" {
  description = "The size of the backend virtual machines"
  type        = string
  default     = "Standard_E2s_v3"
}

variable "frontend_instance_count" {
  description = "Number of frontend VM instances in the scale set"
  type        = number
  default     = 3
}

variable "backend_instance_count" {
  description = "Number of backend VM instances in the scale set"
  type        = number
  default     = 3
}

variable "data_disk_size_gb" {
  description = "Size of the data disk in GB"
  type        = number
  default     = 4
}

variable "frontend_cloud_init_as_base64" {
  description = "Cloud-init configuration for frontend VMs encoded as base64"
  type        = string
}

variable "backend_cloud_init_as_base64" {
  description = "Cloud-init configuration for backend VMs encoded as base64"
  type        = string
}

variable "ssh_public_key" {
  description = "SSH public key for Linux VM authentication"
  type        = string
  default     = "ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAABgQCcFvQl2lYPcK1tMB3Tx2R9n8a7w5MJCSef14x0ePRFr9XISWfCVCNKRLM3Al/JSlIoOVKoMsdw5farEgXkPDK5F+SKLss7whg2tohnQNQwQdXit1ZjgOXkis/uft98Cv8jDWPbhwYj+VH/Aif9rx8abfjbvwVWBGeA/OnvfVvXnr1EQfdLJgMTTh+hX/FCXCqsRkQcD91MbMCxpqk8nP6jmsxJBeLrgfOxjH8RHEdSp4fF76YsRFHCi7QOwTE/6U+DpssgQ8MTWRFRat97uTfcgzKe5MOfuZHZ++5WFBgaTr1vhmSbXteGiK7dQXOk2cLxSvKkzeaiju9Jy6hoSl5oMygUVd5fNPQ94QcqTkMxZ9tQ9vPWOHwbdLRD31Ses3IBtDV+S6ehraiXf/L/e0jRUYk8IL/J543gvhOZ0hj2sQqTj9XS2hZkstZtrB2ywrJzV5ByETUU/oF9OsysyFgnaQdyduVqEPHaqXqnJvBngqqas91plyT3tSLMez3iT0s= unused-generated-by-azure"
}

# Resource group and location variables
variable "resource_group_name" {
  description = "The name of the resource group where resources will be created"
  type        = string
  default     = null
}

variable "location" {
  description = "The Azure region where resources will be created"
  type        = string
  default     = null
}

variable "number_of_availability_zones" {
  description = "The number of availability zones to distribute VMs across"
  type        = number
  default     = 3
}

# Networking variables
variable "vnet_name" {
  description = "The name of the virtual network"
  type        = string
}

variable "vmss_frontend_subnet_name" {
  description = "The name of the subnet where frontend VMs will be deployed"
  type        = string
}

variable "vmss_backend_subnet_name" {
  description = "The name of the subnet where backend VMs will be deployed"
  type        = string
}

variable "vmss_frontend_application_security_group_name" {
  description = "The name of the application security group for frontend VMs"
  type        = string
}

variable "vmss_backend_application_security_group_name" {
  description = "The name of the application security group for backend VMs"
  type        = string
}

# Load balancer and application gateway variables
variable "olb_name" {
  description = "The name of the outbound load balancer"
  type        = string
}

variable "ilb_name" {
  description = "The name of the internal load balancer"
  type        = string
}

variable "agw_name" {
  description = "The name of the application gateway"
  type        = string
}

# Key Vault variables
variable "key_vault_name" {
  description = "The name of the Key Vault"
  type        = string
}

variable "key_vault_dns_zone_name" {
  description = "The name of the Azure KeyVault Private DNS Zone"
  type        = string
}

variable "vmss_workload_public_and_private_public_certs_secret_uri" {
  description = "The Azure KeyVault secret URI for the TLS certificate"
  type        = string
}

# Administration variables
variable "admin_security_principal_object_id" {
  description = "The Microsoft Entra group/user object ID for VM administration"
  type        = string
}

variable "admin_security_principal_type" {
  description = "The principal type (User or Group)"
  type        = string
  default     = "User"
  validation {
    condition     = contains(["User", "Group"], var.admin_security_principal_type)
    error_message = "The admin_security_principal_type must be either 'User' or 'Group'."
  }
}

# Monitoring variables
variable "log_analytics_workspace_name" {
  description = "The name of the Log Analytics workspace"
  type        = string
}

variable "enable_vm_insights" {
  description = "Whether to enable VM insights"
  type        = bool
  default     = true
}

# Custom script variables
variable "frontend_custom_script_command" {
  description = "Command to execute for the frontend custom script extension"
  type        = string
  default     = "sh configure-nginx-frontend.sh"
}

variable "frontend_custom_script_uris" {
  description = "URIs for scripts to download for the frontend custom script extension"
  type        = list(string)
  default     = ["https://raw.githubusercontent.com/mspnp/iaas-baseline/main/configure-nginx-frontend.sh"]
}

variable "backend_custom_script_command" {
  description = "Command to execute for the backend custom script extension"
  type        = string
  default     = "sh configure-nginx-backend.sh"
}

variable "backend_custom_script_uris" {
  description = "URIs for scripts to download for the backend custom script extension"
  type        = list(string)
  default     = ["https://raw.githubusercontent.com/mspnp/iaas-baseline/main/configure-nginx-backend.sh"]
}

# DNS variables
variable "create_dns_zone" {
  description = "Whether to create a DNS zone for this VM"
  type        = bool
  default     = false
}

variable "create_dns_record" {
  description = "Whether to create a DNS record for this VM"
  type        = bool
  default     = false
}

variable "dns_zone_name" {
  description = "Name of the DNS zone for the DNS record"
  type        = string
  default     = ""
}

variable "dns_record_ips" {
  description = "IPs to add to the DNS record"
  type        = list(string)
  default     = []
}

variable "ingress_domain_name" {
  description = "The domain name used for the application"
  type        = string
  default     = "iaas-ingress.contoso.com"
}
