# ------------------------------------------------------------
# Create a Virtual Desktop Host Pool with Entra ID Authentication
# ------------------------------------------------------------
resource "azurerm_virtual_desktop_host_pool" "avd_host_pool" {
  name                         = "avd-host-pool"                                # Name of the host pool
  location                     = var.project_location                           # Azure region for deployment
  resource_group_name          = azurerm_resource_group.project_rg.name         # Resource group for the host pool
  type                         = "Pooled"                                       # Pooled host pool type
  load_balancer_type           = "BreadthFirst"                                 # Load balancing method
  preferred_app_group_type     = "Desktop"                                      # Desktop application group
  start_vm_on_connect          = true                                           # Auto-start VMs on user connect
  validate_environment         = true                                           # Validate host pool environment
  custom_rdp_properties        = "enablerdsaadauth:i:1;targetisaadjoined:i:1"   # Enable Entra ID authentication
  friendly_name                = "@MikesCloudSolutions Desktop"
}

# ------------------------------------------------------------
# Generate a Registration Token for Session Hosts to Join Pool
# ------------------------------------------------------------
resource "azurerm_virtual_desktop_host_pool_registration_info" "token" {
  hostpool_id     = azurerm_virtual_desktop_host_pool.avd_host_pool.id          # Link to host pool
  expiration_date = timeadd(timestamp(), "700h")                                # Token validity duration
}

# ------------------------------------------------------------
# Define the Application Group for the Host Pool
# ------------------------------------------------------------
resource "azurerm_virtual_desktop_application_group" "avd_app_group" {
  name                = "avd-desktop-appgroup"                                  # Application group name
  location            = var.project_location                                    # Azure region
  resource_group_name = azurerm_resource_group.project_rg.name                  # Resource group
  host_pool_id        = azurerm_virtual_desktop_host_pool.avd_host_pool.id      # Link to host pool
  type                = "Desktop"                                               # Application group type
  friendly_name       = "@MikesCloudSolutions AppGroup"                         # Display name
}

# ------------------------------------------------------------
# Create the Workspace for AVD Desktops
# ------------------------------------------------------------
resource "azurerm_virtual_desktop_workspace" "avd_workspace" {
  name                = "avd-workspace"                                         # Workspace name
  location            = var.project_location                                    # Azure region
  resource_group_name = azurerm_resource_group.project_rg.name                  # Resource group
  friendly_name       = "@MikesCloudSolutions Workspace"                        # Display name
  description         = "Workspace for AVD desktops"                            # Description
}

# ------------------------------------------------------------
# Associate the Application Group with the Workspace
# ------------------------------------------------------------
resource "azurerm_virtual_desktop_workspace_application_group_association" "avd_workspace_assoc" {
  workspace_id         = azurerm_virtual_desktop_workspace.avd_workspace.id          # Link to workspace
  application_group_id = azurerm_virtual_desktop_application_group.avd_app_group.id  # Link to application group
}

# ------------------------------------------------------------
# Create NICs for Each AVD Session Host VM
# ------------------------------------------------------------
resource "azurerm_network_interface" "avd_nic" {
  count               = var.session_host_count                                  # Number of NICs = VM count
  name                = "avd-nic-${count.index}"                                # Unique NIC name per instance
  location            = var.project_location                                    # Azure region
  resource_group_name = azurerm_resource_group.project_rg.name                  # Resource group

  ip_configuration {
    name                          = "internal"                                  # IP config name
    subnet_id                     = azurerm_subnet.vm-subnet.id                 # Subnet ID for placement
    private_ip_address_allocation = "Dynamic"                                   # Dynamic private IP allocation
  }
}

# ------------------------------------------------------------
# Create Windows Session Host VMs with Entra ID Join
# ------------------------------------------------------------
resource "azurerm_windows_virtual_machine" "avd_session_host" {
  count               = var.session_host_count                                  # Number of session hosts
  name                = "avd-session-${count.index}"                            # VM name
  location            = var.project_location                                    # Azure region
  resource_group_name = azurerm_resource_group.project_rg.name                  # Resource group
  size                = "Standard_D2s_v3"                                       # VM size
  admin_username      = "sysadmin"                                              # Admin user for RDP access
  admin_password      = random_password.vm_password.result                      # Admin password
  network_interface_ids = [azurerm_network_interface.avd_nic[count.index].id]   # NIC for VM

  os_disk {
    caching              = "ReadWrite"                                          # Disk caching mode
    storage_account_type = "Standard_LRS"                                       # Storage type
  }

  source_image_reference {
    publisher = "MicrosoftWindowsDesktop"                                       # Image publisher
    offer     = "windows-11"                                                    # Image offer
    sku       = "win11-22h2-avd"                                                # Image SKU for AVD
    version   = "latest"                                                        # Use latest version
  }

  identity {
    type = "SystemAssigned"                                                     # Required for Entra ID join
  }

  tags = {
    Role = "AVD-SessionHost"                                                    # Tag for identification
  }
}

# ------------------------------------------------------------
# Add AADLoginForWindows Extension for Entra ID Login
# ------------------------------------------------------------
resource "azurerm_virtual_machine_extension" "aad_login" {
  count                      = var.session_host_count                               # One per session host
  name                       = "aad-login-${count.index}"                           # Extension name
  virtual_machine_id         = azurerm_windows_virtual_machine.avd_session_host[count.index].id 
                                                                                    # VM reference
  publisher                  = "Microsoft.Azure.ActiveDirectory"                    # Publisher name
  type                       = "AADLoginForWindows"                                 # Extension type
  type_handler_version       = "1.0"                                                # Extension version
  auto_upgrade_minor_version = true                                                 # Enable auto-upgrade
}

# ------------------------------------------------------------
# Install AVD Agent using DSC Extension
# ------------------------------------------------------------
resource "azurerm_virtual_machine_extension" "avd_agent" {
  count                      = var.session_host_count                                # One per VM
  name                       = "avd-agent-${count.index}"                            # Extension name
  virtual_machine_id         = azurerm_windows_virtual_machine.avd_session_host[count.index].id 
                                                                                     # VM reference
  publisher                  = "Microsoft.Powershell"                                # Publisher
  type                       = "DSC"                                                 # Desired State Config extension
  type_handler_version       = "2.73"                                                # Version

  settings = jsonencode({
    modulesUrl            = "https://wvdportalstorageblob.blob.core.windows.net/galleryartifacts/Configuration_01-19-2023.zip" 
                                                                                    # URL to DSC package
    configurationFunction = "Configuration.ps1\\AddSessionHost"                     # Function to invoke
    properties = {
      hostPoolName = azurerm_virtual_desktop_host_pool.avd_host_pool.name           # Pass host pool name
      aadJoin      = true                                                           # Enable AAD join
    }
  })

  protected_settings = jsonencode({
    properties = {
      registrationInfoToken = azurerm_virtual_desktop_host_pool_registration_info.token.token # Token from earlier
    }
  })

  depends_on = [azurerm_virtual_machine_extension.aad_login]                        # Wait until AAD extension finishes
}

# ------------------------------------------------------------
# Reboot Each Session Host to Finalize Setup
# ------------------------------------------------------------
resource "azurerm_virtual_machine_extension" "reboot" {
  count                      = var.session_host_count                                # One per VM
  name                       = "reboot-${count.index}"                               # Extension name
  virtual_machine_id         = azurerm_windows_virtual_machine.avd_session_host[count.index].id 
                                                                                     # VM reference
  publisher                  = "Microsoft.Compute"                                   # Publisher
  type                       = "CustomScriptExtension"                               # Script runner
  type_handler_version       = "1.10"                                                # Version
  settings = jsonencode({
    commandToExecute = "powershell -Command \"Start-Process -FilePath shutdown.exe -ArgumentList '/r /t 5 /c \\\"Finalize AVD setup\\\" /f' -NoNewWindow; exit 0\""
  })

  depends_on = [azurerm_virtual_machine_extension.avd_agent]                        # Reboot after agent install
}
