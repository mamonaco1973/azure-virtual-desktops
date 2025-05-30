#############################################
# GENERATE RANDOM SUFFIXES FOR USERNAMES
#############################################

resource "random_id" "avd_user_suffix" {
  for_each = toset(["user1", "user2", "user3"])  # Define all base user keys
  byte_length = 3                                # 3 bytes = 6 hex characters
}

#############################################
# BUILD LOCAL USER MAP WITH RANDOM SUFFIXES
#############################################

locals {
  avd_users = {
    for key in ["user1", "user2", "user3"] :
    key => "avd-${key}-${random_id.avd_user_suffix[key].hex}"
  }
}

#############################################
# GENERATE STRONG RANDOM PASSWORDS
#############################################

# Create a random password for each AVD user
# Uses 24-character length with limited special characters for compatibility
# Passwords are unique and securely generated per user
resource "random_password" "avd_user_password" {
  for_each         = local.avd_users                           # Iterate over each user in the local map
  length           = 24                                        # Set strong password length
  special          = true                                      # Include special characters
  override_special = "!@#$%"                                   # Use only approved special characters to avoid issues in downstream systems
}

#############################################
# CREATE ENTRA ID (AzureAD) USERS
#############################################

# Provision each user in Entra ID (AzureAD)
# The UPN is dynamically generated from the username and domain
# Passwords are injected from the random_password resource
resource "azuread_user" "avd_user" {
  for_each             = local.avd_users                                     # Loop through each user
  user_principal_name  = "${each.value}@${var.azure_domain}"                 # e.g., avd-user1@mikecloud.com
  display_name         = each.value                                          # Set the display name to match username
  password             = random_password.avd_user_password[each.key].result  # Pull corresponding password
}

#############################################
# STORE CREDENTIALS SECURELY IN KEY VAULT
#############################################

# For each AVD user, store their credentials (username + password) as a JSON blob
# These secrets are securely stored in Azure Key Vault to be retrieved by automation or config scripts
resource "azurerm_key_vault_secret" "avd_user_secret" {
  for_each     = local.avd_users                                   # Iterate through all AVD users
  name         = "${each.key}-avd-credentials"                     # Secret name, e.g., user1-avd-credentials
  value        = jsonencode({                                      # Store the credentials as a JSON object
    username = "${each.value}@${var.azure_domain}"                 # Insert the correct UPN
    password = random_password.avd_user_password[each.key].result  # Secure password
  })
  key_vault_id = azurerm_key_vault.credentials_key_vault.id        # Use your defined Key Vault
  content_type = "application/json"                                # Set content type for secret
}

# ------------------------------------------------------------
# ASSIGN 'Desktop Virtualization User' ROLE TO EACH USER
# ------------------------------------------------------------
resource "azurerm_role_assignment" "avd_user_access" {
  for_each             = local.avd_users                                             # Assign role for each AVD user
  scope                = azurerm_virtual_desktop_application_group.avd_app_group.id  # Application group scope
  role_definition_name = "Desktop Virtualization User"                               # Built-in role required for AVD access
  principal_id         = azuread_user.avd_user[each.key].object_id                   # Assign role to the created user
}

# ------------------------------------------------------------
# ASSIGN VM LOGIN ROLE TO EACH AVD USER (Entra ID)
# ------------------------------------------------------------
resource "azurerm_role_assignment" "vm_user_login" {
  for_each             = azuread_user.avd_user                                  # Loop over defined users
  scope                = azurerm_resource_group.project_rg.id                   # Scope is the whole resource group
  role_definition_name = "Virtual Machine User Login"                           # Role allowing login to session hosts
  principal_id         = each.value.object_id                                   # Reference user object ID
}
