resource "azurerm_virtual_desktop_host_pool" "avd_host_pool" {
  name                = "avd-host-pool"
  location            = var.project_location
  resource_group_name = azurerm_resource_group.project_rg.name
  type                = "Pooled"
  load_balancer_type  = "BreadthFirst"
  preferred_app_group_type = "Desktop"
  start_vm_on_connect = true
  validate_environment = true
}

resource "azurerm_virtual_desktop_application_group" "avd_app_group" {
  name                = "avd-desktop-appgroup"
  location            = var.project_location
  resource_group_name = azurerm_resource_group.project_rg.name
  host_pool_id        = azurerm_virtual_desktop_host_pool.avd_host_pool.id
  type                = "Desktop"
  friendly_name       = "AVD Desktop AppGroup"
}

resource "azurerm_virtual_desktop_workspace" "avd_workspace" {
  name                = "avd-workspace"
  location            = var.project_location
  resource_group_name = azurerm_resource_group.project_rg.name
  friendly_name       = "AVD Workspace"
  description         = "Workspace for AVD desktops"
}

resource "azurerm_virtual_desktop_workspace_application_group_association" "avd_workspace_assoc" {
  workspace_id         = azurerm_virtual_desktop_workspace.avd_workspace.id
  application_group_id = azurerm_virtual_desktop_application_group.avd_app_group.id
}

resource "azurerm_role_assignment" "avd_user1_access" {
  scope                = azurerm_virtual_desktop_application_group.avd_app_group.id
  role_definition_name = "Desktop Virtualization User"
  principal_id         = azuread_user.avd_user1.object_id
}

resource "azurerm_role_assignment" "avd_user2_access" {
  scope                = azurerm_virtual_desktop_application_group.avd_app_group.id
  role_definition_name = "Desktop Virtualization User"
  principal_id         = azuread_user.avd_user2.object_id
}

resource "azurerm_role_assignment" "avd_user3_access" {
  scope                = azurerm_virtual_desktop_application_group.avd_app_group.id
  role_definition_name = "Desktop Virtualization User"
  principal_id         = azuread_user.avd_user2.object_id
}

resource "azurerm_virtual_desktop_host_pool_registration_info" "token" {
  hostpool_id     = azurerm_virtual_desktop_host_pool.avd_host_pool.id
  expiration_date = timeadd(timestamp(), "24h")
}

resource "azurerm_network_interface" "avd_nic" {
  count               = var.session_host_count
  name                = "avd-nic-${count.index}"
  location            = var.project_location
  resource_group_name = azurerm_resource_group.project_rg.name

  ip_configuration {
    name                          = "internal"
    subnet_id                     = data.azurerm_subnet.vm_subnet.id
    private_ip_address_allocation = "Dynamic"
  }
}

resource "azurerm_windows_virtual_machine" "avd_session_host" {
  count               = var.session_host_count
  name                = "avd-session-${count.index}"
  location            = var.project_location
  resource_group_name = azurerm_resource_group.project_rg.name
  size                = "Standard_D2s_v3"
  admin_username      = "adminuser"                                
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
    type = "SystemAssigned"
  }

  tags = {
    Role = "AVD-SessionHost"
  }
}

# resource "azurerm_virtual_machine_extension" "join_domain" {
#   count               = var.session_host_count
#   name                = "domain-join-${count.index}"
#   virtual_machine_id  = azurerm_windows_virtual_machine.avd_session_host[count.index].id
#   publisher           = "Microsoft.Compute"
#   type                = "CustomScriptExtension"
#   type_handler_version = "1.10"

#   settings = jsonencode({
#     fileUris = [
#       "https://${azurerm_storage_account.scripts_storage.name}.blob.core.windows.net/${azurerm_storage_container.scripts.name}/${azurerm_storage_blob.avd_boot_script.name}?${data.azurerm_storage_account_sas.script_sas.sas}"
#     ],
#     commandToExecute = "powershell.exe -ExecutionPolicy Unrestricted -File avd-boot.ps1 *>> C:\\WindowsAzure\\Logs\\avd-boot.log"
#   })
# }

