# ================================================================================
# Azure Virtual Desktop host pool
# --------------------------------------------------------------------------------
# Creates the AVD host pool and enables Entra ID authentication for
# session hosts.
#
# Notes
# - Host pool type is pooled.
# - Load balancing uses BreadthFirst.
# - Start VM on Connect is enabled.
# - Custom RDP properties enable Entra ID sign-in.
# ================================================================================
resource "azurerm_virtual_desktop_host_pool" "avd_host_pool" {
  name                     = "avd-host-pool"
  location                 = var.project_location
  resource_group_name      = azurerm_resource_group.project_rg.name
  type                     = "Pooled"
  load_balancer_type       = "BreadthFirst"
  preferred_app_group_type = "Desktop"
  start_vm_on_connect      = true
  validate_environment     = true
  custom_rdp_properties    = "enablerdsaadauth:i:1;targetisaadjoined:i:1"
  friendly_name            = "@MikesCloudSolutions Desktop"
}

# ================================================================================
# Host pool registration token
# --------------------------------------------------------------------------------
# Generates the registration token used by session hosts to join the
# AVD host pool during deployment.
# ================================================================================
resource "azurerm_virtual_desktop_host_pool_registration_info" "token" {
  hostpool_id     = azurerm_virtual_desktop_host_pool.avd_host_pool.id
  expiration_date = timeadd(timestamp(), "700h")
}

# ================================================================================
# Azure Virtual Desktop application group
# --------------------------------------------------------------------------------
# Creates the desktop application group associated with the host pool.
# This is the application group presented to assigned users.
# ================================================================================
resource "azurerm_virtual_desktop_application_group" "avd_app_group" {
  name                = "avd-desktop-appgroup"
  location            = var.project_location
  resource_group_name = azurerm_resource_group.project_rg.name
  host_pool_id        = azurerm_virtual_desktop_host_pool.avd_host_pool.id
  type                = "Desktop"
  friendly_name       = "@MikesCloudSolutions AppGroup"
}

# ================================================================================
# Azure Virtual Desktop workspace
# --------------------------------------------------------------------------------
# Creates the AVD workspace that publishes the application group to users.
# ================================================================================
resource "azurerm_virtual_desktop_workspace" "avd_workspace" {
  name                = "avd-workspace"
  location            = var.project_location
  resource_group_name = azurerm_resource_group.project_rg.name
  friendly_name       = "@MikesCloudSolutions Workspace"
  description         = "Workspace for AVD desktops"
}

# ================================================================================
# Workspace to application group association
# --------------------------------------------------------------------------------
# Associates the desktop application group with the AVD workspace.
# ================================================================================
resource "azurerm_virtual_desktop_workspace_application_group_association" "avd_workspace_assoc" {
  workspace_id         = azurerm_virtual_desktop_workspace.avd_workspace.id
  application_group_id = azurerm_virtual_desktop_application_group.avd_app_group.id
}

# ================================================================================
# Session host network interfaces
# --------------------------------------------------------------------------------
# Creates one NIC per AVD session host VM.
# Each NIC is attached to the VM subnet with a dynamic private IP.
# ================================================================================
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

# ================================================================================
# AVD session host virtual machines
# --------------------------------------------------------------------------------
# Creates the Windows session host VMs used by Azure Virtual Desktop.
#
# Notes
# - Uses Windows Server 2022 by default.
# - Enables a system-assigned managed identity for Entra ID join.
# - Attaches one NIC per VM.
# ================================================================================
resource "azurerm_windows_virtual_machine" "avd_session_host" {
  count                 = var.session_host_count
  name                  = "avd-${random_string.key_vault_suffix.result}-${count.index}"
  location              = var.project_location
  resource_group_name   = azurerm_resource_group.project_rg.name
  size                  = "Standard_D2s_v3"
  admin_username        = "sysadmin"
  admin_password        = random_password.vm_password.result
  network_interface_ids = [azurerm_network_interface.avd_nic[count.index].id]

  os_disk {
    caching              = "ReadWrite"
    storage_account_type = "Premium_LRS"
  }

  source_image_reference {
    publisher = "MicrosoftWindowsServer"
    offer     = "WindowsServer"
    sku       = "2022-Datacenter"
    version   = "latest"
  }

  # --------------------------------------------------------------------------
  # Optional Windows 11 AVD image
  # --------------------------------------------------------------------------
  # source_image_reference {
  #   publisher = "MicrosoftWindowsDesktop"
  #   offer     = "windows-11"
  #   sku       = "win11-22h2-avd"
  #   version   = "latest"
  # }

  identity {
    type = "SystemAssigned"
  }

  tags = {
    Role = "AVD-SessionHost"
  }
}

# ================================================================================
# Entra ID login extension
# --------------------------------------------------------------------------------
# Installs the AADLoginForWindows extension on each session host so users
# can sign in with Entra ID credentials.
# ================================================================================
resource "azurerm_virtual_machine_extension" "aad_login" {
  count                      = var.session_host_count
  name                       = "aad-login-${count.index}"
  virtual_machine_id         = azurerm_windows_virtual_machine.avd_session_host[count.index].id
  publisher                  = "Microsoft.Azure.ActiveDirectory"
  type                       = "AADLoginForWindows"
  type_handler_version       = "1.0"
  auto_upgrade_minor_version = true
}

# ================================================================================
# AVD agent installation
# --------------------------------------------------------------------------------
# Installs the AVD agent by using the DSC extension and registers each
# session host with the AVD host pool.
#
# Notes
# - Uses the Microsoft gallery DSC package.
# - Passes the host pool name and registration token.
# - Runs only after the Entra ID login extension is installed.
# ================================================================================
resource "azurerm_virtual_machine_extension" "avd_agent" {
  count                = var.session_host_count
  name                 = "avd-agent-${count.index}"
  virtual_machine_id   = azurerm_windows_virtual_machine.avd_session_host[count.index].id
  publisher            = "Microsoft.Powershell"
  type                 = "DSC"
  type_handler_version = "2.73"

  settings = jsonencode({
    modulesUrl            = "https://wvdportalstorageblob.blob.core.windows.net/galleryartifacts/Configuration_01-19-2023.zip"
    configurationFunction = "Configuration.ps1\\AddSessionHost"
    properties = {
      hostPoolName = azurerm_virtual_desktop_host_pool.avd_host_pool.name
      aadJoin      = true
    }
  })

  protected_settings = jsonencode({
    properties = {
      registrationInfoToken = azurerm_virtual_desktop_host_pool_registration_info.token.token
    }
  })

  depends_on = [azurerm_virtual_machine_extension.aad_login]
}

# ================================================================================
# Session host reboot
# --------------------------------------------------------------------------------
# Reboots each session host after AVD agent installation to finalize
# configuration.
# ================================================================================
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