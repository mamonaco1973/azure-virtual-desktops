# ================================================================================
# Azure provider configuration
# --------------------------------------------------------------------------------
# Configures the AzureRM provider which Terraform uses to interact with
# Microsoft Azure resources.
#
# Notes
# - The features block is required even if empty.
# - Do not remove the block or Terraform will fail to initialize.
# ================================================================================
provider "azurerm" {
  features {}
}

# ================================================================================
# Azure subscription data source
# --------------------------------------------------------------------------------
# Retrieves metadata for the current Azure subscription.
#
# Useful for:
# - Accessing subscription_id or tenant_id
# - Tagging resources with subscription context
# - Auditing or cross-resource references
# ================================================================================
data "azurerm_subscription" "primary" {}

# ================================================================================
# Azure client configuration
# --------------------------------------------------------------------------------
# Retrieves information about the currently authenticated identity.
#
# Values exposed include:
# - tenant_id
# - client_id
# - object_id
#
# This is commonly used when creating role assignments or referencing the
# current service principal or user identity.
# ================================================================================
data "azurerm_client_config" "current" {}

# ================================================================================
# Project resource group
# --------------------------------------------------------------------------------
# Creates the primary Azure resource group that will contain all
# infrastructure for the project deployment.
#
# Notes
# - The resource group acts as a logical container for Azure resources.
# - All project resources should be deployed within this group.
# ================================================================================
resource "azurerm_resource_group" "project_rg" {
  name     = var.project_resource_group
  location = var.project_location
}