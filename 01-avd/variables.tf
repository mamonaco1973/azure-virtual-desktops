# ================================================================================
# Project resource group name
# --------------------------------------------------------------------------------
# Defines the name of the Azure resource group used for this deployment.
#
# Notes
# - The resource group acts as the logical container for all project
#   resources created by Terraform.
# - The value can be overridden using CLI variables or tfvars files.
# ================================================================================
variable "project_resource_group" {
  description = "Name of the Azure Resource Group"
  type        = string
  default     = "avd-rg"
}

# ================================================================================
# Virtual network name
# --------------------------------------------------------------------------------
# Defines the name of the Azure virtual network used for the project.
#
# Notes
# - The VNet contains both the VM subnet and the Bastion subnet.
# - The value can be overridden during deployment if required.
# ================================================================================
variable "project_vnet" {
  description = "Name of the Azure Virtual Network"
  type        = string
  default     = "avd-vnet"
}

# ================================================================================
# VM subnet name
# --------------------------------------------------------------------------------
# Defines the name of the subnet used for virtual machines.
#
# Notes
# - This subnet hosts application workloads and AVD session hosts.
# - It should remain separate from the AzureBastionSubnet.
# ================================================================================
variable "project_subnet" {
  description = "Name of the Azure Subnet within the Virtual Network"
  type        = string
  default     = "vm-subnet"
}

# ================================================================================
# Azure deployment region
# --------------------------------------------------------------------------------
# Defines the Azure region where resources will be deployed.
#
# Examples
# - Central US
# - East US
# - West Europe
# ================================================================================
variable "project_location" {
  description = "Azure region where resources will be deployed"
  type        = string
  default     = "Central US"
}

# ================================================================================
# Azure Entra ID domain
# --------------------------------------------------------------------------------
# Defines the default Azure Entra ID domain used when creating user
# principal names for generated accounts.
#
# Example
# - exampletenant.onmicrosoft.com
# ================================================================================
variable "azure_domain" {
  description = "The default Azure AD domain"
}

# ================================================================================
# AVD session host count
# --------------------------------------------------------------------------------
# Defines the number of Azure Virtual Desktop session host VMs that
# will be deployed.
#
# Notes
# - Each session host receives its own NIC and VM instance.
# - Increase this value to scale the AVD environment.
# ================================================================================
variable "session_host_count" {
  description = "Number of AVD session host VMs to deploy"
  type        = number
  default     = 1
}