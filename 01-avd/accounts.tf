# ================================================================================
# Random suffixes for AVD usernames
# --------------------------------------------------------------------------------
# Generates a unique 6-character hex suffix for each base user key.
# This helps avoid naming collisions when creating Entra ID users.
# ================================================================================
resource "random_id" "avd_user_suffix" {
  for_each    = toset(["user1", "user2", "user3"])
  byte_length = 3
}

# ================================================================================
# Local AVD user map
# --------------------------------------------------------------------------------
# Builds the final AVD username for each base user key by appending the
# generated random suffix.
# ================================================================================
locals {
  avd_users = {
    for key in ["user1", "user2", "user3"] :
    key => "avd-${key}-${random_id.avd_user_suffix[key].hex}"
  }
}

# ================================================================================
# Random passwords for AVD users
# --------------------------------------------------------------------------------
# Creates a strong random password for each AVD user.
#
# Notes
# - Password length is set to 24 characters.
# - Special characters are enabled.
# - Special characters are restricted to a known-safe subset for
#   downstream compatibility.
# ================================================================================
resource "random_password" "avd_user_password" {
  for_each         = local.avd_users
  length           = 24
  special          = true
  override_special = "!@#$%"
}

# ================================================================================
# Entra ID users
# --------------------------------------------------------------------------------
# Provisions one Entra ID user for each generated AVD username.
#
# Notes
# - The UPN is built from the generated username and Azure domain.
# - The display name matches the generated username.
# - The password comes from the corresponding random_password resource.
# ================================================================================
resource "azuread_user" "avd_user" {
  for_each            = local.avd_users
  user_principal_name = "${each.value}@${var.azure_domain}"
  display_name        = each.value
  password            = random_password.avd_user_password[each.key].result
}

# ================================================================================
# Key Vault secrets for AVD credentials
# --------------------------------------------------------------------------------
# Stores each AVD user's username and password in Azure Key Vault as a JSON
# secret. These secrets can be retrieved later by automation or bootstrap
# scripts.
#
# Secret format
# {
#   "username": "<user>@<domain>",
#   "password": "<password>"
# }
# ================================================================================
resource "azurerm_key_vault_secret" "avd_user_secret" {
  for_each = local.avd_users
  name     = "${each.key}-avd-credentials"

  value = jsonencode({
    username = "${each.value}@${var.azure_domain}"
    password = random_password.avd_user_password[each.key].result
  })

  key_vault_id = azurerm_key_vault.credentials_key_vault.id
  content_type = "application/json"

  depends_on = [azurerm_role_assignment.kv_role_assignment]
}

# ================================================================================
# AVD application group access
# --------------------------------------------------------------------------------
# Assigns the built-in Desktop Virtualization User role to each AVD user at
# the application group scope. This grants access to the published AVD
# resources.
# ================================================================================
resource "azurerm_role_assignment" "avd_user_access" {
  for_each             = local.avd_users
  scope                = azurerm_virtual_desktop_application_group.avd_app_group.id
  role_definition_name = "Desktop Virtualization User"
  principal_id         = azuread_user.avd_user[each.key].object_id
}

# ================================================================================
# Session host login access
# --------------------------------------------------------------------------------
# Assigns the Virtual Machine User Login role to each AVD user at the
# resource group scope. This allows the users to sign in to AVD session
# hosts with Entra ID authentication.
# ================================================================================
resource "azurerm_role_assignment" "vm_user_login" {
  for_each             = azuread_user.avd_user
  scope                = azurerm_resource_group.project_rg.id
  role_definition_name = "Virtual Machine User Login"
  principal_id         = each.value.object_id
}