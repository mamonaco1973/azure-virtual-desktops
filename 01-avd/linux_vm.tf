# ================================================================================
# Linux VM network interface
# --------------------------------------------------------------------------------
# Creates the network interface used by the Linux virtual machine.
#
# Notes
# - The NIC is attached to the VM subnet.
# - Azure dynamically assigns a private IP address from the subnet.
# ================================================================================
resource "azurerm_network_interface" "linux_vm_nic" {
  name                = "linux-vm-nic"
  location            = var.project_location
  resource_group_name = azurerm_resource_group.project_rg.name

  # ---------------------------------------------------------------------------
  # NIC IP configuration
  # ---------------------------------------------------------------------------
  # Defines the internal IP configuration for the network interface.
  # The IP is allocated dynamically from the subnet address space.
  # ---------------------------------------------------------------------------
  ip_configuration {
    name                          = "internal"
    subnet_id                     = azurerm_subnet.vm-subnet.id
    private_ip_address_allocation = "Dynamic"
  }
}

# ================================================================================
# Linux virtual machine
# --------------------------------------------------------------------------------
# Deploys a Linux VM attached to the previously created network interface.
#
# Notes
# - Uses Ubuntu 24.04 LTS from Canonical.
# - Admin credentials are generated using a random_password resource.
# - A custom initialization script is executed at first boot.
# ================================================================================
resource "azurerm_linux_virtual_machine" "linux_vm" {
  name                = "linux-vm"
  location            = var.project_location
  resource_group_name = azurerm_resource_group.project_rg.name
  size                = "Standard_B1s"

  admin_username                  = "sysadmin"
  admin_password                  = random_password.vm_password.result
  disable_password_authentication = false

  # ---------------------------------------------------------------------------
  # Network interface attachment
  # ---------------------------------------------------------------------------
  # Attaches the previously created NIC to the VM.
  # ---------------------------------------------------------------------------
  network_interface_ids = [
    azurerm_network_interface.linux_vm_nic.id
  ]

  # ---------------------------------------------------------------------------
  # OS disk configuration
  # ---------------------------------------------------------------------------
  # Defines the storage configuration for the VM operating system disk.
  # ---------------------------------------------------------------------------
  os_disk {
    caching              = "ReadWrite"
    storage_account_type = "Premium_LRS"
  }

  # ---------------------------------------------------------------------------
  # Base OS image
  # ---------------------------------------------------------------------------
  # Uses the official Ubuntu 24.04 LTS server image from Canonical.
  # ---------------------------------------------------------------------------
  source_image_reference {
    publisher = "canonical"
    offer     = "ubuntu-24_04-lts"
    sku       = "server"
    version   = "latest"
  }

  # ---------------------------------------------------------------------------
  # Custom initialization script
  # ---------------------------------------------------------------------------
  # Executes a base64-encoded shell script at first boot. This script is
  # typically used to install packages or configure the instance.
  # ---------------------------------------------------------------------------
  custom_data = filebase64("scripts/custom_data.sh")
}