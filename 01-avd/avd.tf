# Host pool with Entra ID authentication
resource "azurerm_virtual_desktop_host_pool" "avd_host_pool" {
  name                         = "avd-host-pool"
  location                     = var.project_location
  resource_group_name          = azurerm_resource_group.project_rg.name
  type                         = "Pooled"
  load_balancer_type           = "BreadthFirst"
  preferred_app_group_type     = "Desktop"
  start_vm_on_connect          = true
  validate_environment         = true
  custom_rdp_properties        = "enablerdsaadauth:i:1;targetisaadjoined:i:1" # Enable Entra ID auth
}

resource "azurerm_virtual_desktop_host_pool_registration_info" "token" {
  hostpool_id     = azurerm_virtual_desktop_host_pool.avd_host_pool.id
  expiration_date = timeadd(timestamp(), "700h") 
}

# Application group
resource "azurerm_virtual_desktop_application_group" "avd_app_group" {
  name                = "avd-desktop-appgroup"
  location            = var.project_location
  resource_group_name = azurerm_resource_group.project_rg.name
  host_pool_id        = azurerm_virtual_desktop_host_pool.avd_host_pool.id
  type                = "Desktop"
  friendly_name       = "AVD Desktop AppGroup"
}

# Workspace
resource "azurerm_virtual_desktop_workspace" "avd_workspace" {
  name                = "avd-workspace"
  location            = var.project_location
  resource_group_name = azurerm_resource_group.project_rg.name
  friendly_name       = "AVD Workspace"
  description         = "Workspace for AVD desktops"
}

# Associate workspace and application group
resource "azurerm_virtual_desktop_workspace_application_group_association" "avd_workspace_assoc" {
  workspace_id         = azurerm_virtual_desktop_workspace.avd_workspace.id
  application_group_id = azurerm_virtual_desktop_application_group.avd_app_group.id
}

# RBAC: Virtual Machine User Login role for Entra ID login
resource "azurerm_role_assignment" "vm_user_login" {
  count                = 3
  scope                = azurerm_resource_group.project_rg.id
  role_definition_name = "Virtual Machine User Login"
  principal_id         = [azuread_user.avd_user1.object_id, azuread_user.avd_user2.object_id, azuread_user.avd_user3.object_id][count.index]
}

# Network interface for session hosts
resource "azurerm_network_interface" "avd_nic" {
  count               = var.session_host_count
  name                = "avd-nic-${count.index}"
  location            = var.project_location
  resource_group_name = azurerm_resource_group.project_rg.name

  ip_configuration {
    name                          = "internal"
    subnet_id                     = azurerm_subnet.vm-subnet.id
    private_ip_address_allocation = "Dynamic"
  }
}

# Session host VMs
resource "azurerm_windows_virtual_machine" "avd_session_host" {
  count               = var.session_host_count
  name                = "avd-session-${count.index}"
  location            = var.project_location
  resource_group_name = azurerm_resource_group.project_rg.name
  size                = "Standard_D2s_v3"
  admin_username      = "sysadmin"
  admin_password      = random_password.vm_password.result
  network_interface_ids = [azurerm_network_interface.avd_nic[count.index].id]

  os_disk {
    caching              = "ReadWrite"
    storage_account_type = "Standard_LRS"
  }

  source_image_reference {
    publisher = "MicrosoftWindowsDesktop"
    offer     = "windows-11"
    sku       = "win11-22h2-avd"
    version   = "latest"
  }

  identity {
    type = "SystemAssigned" # Required for Entra ID join
  }

  tags = {
    Role = "AVD-SessionHost"
  }
}

# AADLoginForWindows extension for Entra ID join
resource "azurerm_virtual_machine_extension" "aad_login" {
  count                = var.session_host_count
  name                 = "aad-login-${count.index}"
  virtual_machine_id   = azurerm_windows_virtual_machine.avd_session_host[count.index].id
  publisher            = "Microsoft.Azure.ActiveDirectory"
  type                 = "AADLoginForWindows"
  type_handler_version = "1.0"
  auto_upgrade_minor_version = true
}

# DSC extension for AVD Agent registration
resource "azurerm_virtual_machine_extension" "avd_agent" {
  count                = var.session_host_count
  name                 = "avd-agent-${count.index}"
  virtual_machine_id   = azurerm_windows_virtual_machine.avd_session_host[count.index].id
  publisher            = "Microsoft.Powershell"
  type                 = "DSC"
  type_handler_version = "2.73"
  settings = jsonencode({
    modulesUrl = "https://wvdportalstorageblob.blob.core.windows.net/galleryartifacts/Configuration_01-19-2023.zip"
    configurationFunction = "Configuration.ps1\\AddSessionHost"
    properties = {
      hostPoolName = azurerm_virtual_desktop_host_pool.avd_host_pool.name
      aadJoin = true
    }
  })
  protected_settings = jsonencode({
    properties = {
      registrationInfoToken = azurerm_virtual_desktop_host_pool_registration_info.token.token
    }
  })
  depends_on = [azurerm_virtual_machine_extension.aad_login]
}

resource "azurerm_virtual_machine_extension" "reboot" {
  count                = var.session_host_count
  name                 = "reboot-${count.index}"
  virtual_machine_id   = azurerm_windows_virtual_machine.avd_session_host[count.index].id
  publisher            = "Microsoft.Compute"
  type                 = "CustomScriptExtension"
  type_handler_version = "1.10"
  settings = jsonencode({
    commandToExecute = "powershell -Command \"Start-Process -FilePath shutdown.exe -ArgumentList '/r /t 5 /c \\\"Finalize AVD setup\\\" /f' -NoNewWindow; exit 0\""
  })
  depends_on = [azurerm_virtual_machine_extension.avd_agent]
}
