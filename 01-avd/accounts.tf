resource "random_password" "avd_user1_password" {
  length             = 24    # Set password length to 24 characters
  special            = true  # Include special characters in the password
  override_special   = "!@#$%" # Limit special characters to this set
}

# Create a Key Vault secret for the User 1 credentials
resource "azurerm_key_vault_secret" "avd_user1_secret" {
  name         = "user1-avd-credentials"
  value        = jsonencode({
    username = "avd-user1@${var.azure_domain}"
    password = random_password.avd_user1_password.result
  })
  key_vault_id = azurerm_key_vault.credentials_key_vault.id
  content_type = "application/json"
}

resource "random_password" "avd_user2_password" {
  length             = 24    # Set password length to 24 characters
  special            = true  # Include special characters in the password
  override_special   = "!@#$%" # Limit special characters to this set
}

# Create a Key Vault secret for the User 2 credentials
resource "azurerm_key_vault_secret" "avd_user2_secret" {
  name         = "user2-avd-credentials"
  value        = jsonencode({
    username = "avd-user2@${var.azure_domain}"
    password = random_password.avd_user2_password.result
  })
  key_vault_id = azurerm_key_vault.credentials_key_vault.id
  content_type = "application/json"
}

resource "random_password" "avd_user3_password" {
  length             = 24    # Set password length to 24 characters
  special            = true  # Include special characters in the password
  override_special   = "!@#$%" # Limit special characters to this set
}

# Create a Key Vault secret for the User 2 credentials
resource "azurerm_key_vault_secret" "avd_user3_secret" {
  name         = "user3-avd-credentials"
  value        = jsonencode({
    username = "avd-user3@${var.azure_domain}"
    password = random_password.avd_user3_password.result
  })
  key_vault_id = azurerm_key_vault.credentials_key_vault.id
  content_type = "application/json"
}

resource "azuread_user" "avd_user1" {
   user_principal_name = "avd-user1@${var.azure_domain}"
   display_name        = "avd-user1"
   password            = random_password.avd_user1_password.result
}

resource "azuread_user" "avd_user2" {
   user_principal_name = "avd-user2@${var.azure_domain}"
   display_name        = "avd-user2"
   password            = random_password.avd_user2_password.result
}

resource "azuread_user" "avd_user3" {
   user_principal_name = "avd-user3@${var.azure_domain}"
   display_name        = "avd-user3"
   password            = random_password.avd_user3_password.result
}
