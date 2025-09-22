##########################################################
# NETWORK INTERFACE FOR LINUX VM
##########################################################

resource "azurerm_network_interface" "linux_vm_nic" {
  name                = "linux-vm-nic"                         # Name of the NIC resource (must be unique within RG)
  location            = var.project_location                   # Azure region from variable (e.g., "eastus")
  resource_group_name = azurerm_resource_group.project_rg.name # Resource group to contain this NIC

  # ------------------------------
  # IP CONFIGURATION FOR THE NIC
  # ------------------------------
  ip_configuration {
    name                          = "internal"                  # Arbitrary name for this IP config block
    subnet_id                     = azurerm_subnet.vm-subnet.id # Attach NIC to VM subnet in VNet
    private_ip_address_allocation = "Dynamic"                   # Let Azure auto-assign a private IP from subnet range
    # Use "Static" and add private_ip_address = "10.x.x.x" to hardcode IP if needed
  }
}

##########################################################
# LINUX VIRTUAL MACHINE DEFINITION
##########################################################

resource "azurerm_linux_virtual_machine" "linux_vm" {
  name                            = "linux-vm"                             # Name of the virtual machine in Azure
  location                        = var.project_location                   # Same region as NIC and VNet
  resource_group_name             = azurerm_resource_group.project_rg.name # Place VM in the defined resource group
  size                            = "Standard_B1s"                         # Size of VM (B-series are cost-effective burstable VMs)
  admin_username                  = "sysadmin"                             # Admin login for SSH or console access
  admin_password                  = random_password.vm_password.result     # Randomized admin password (secure) from a separate resource
  disable_password_authentication = false

  # ------------------------------
  # ASSOCIATE NETWORK INTERFACE
  # ------------------------------
  network_interface_ids = [
    azurerm_network_interface.linux_vm_nic.id # Attach previously created NIC (one NIC per VM in this case)
  ]

  # ------------------------------
  # OS DISK CONFIGURATION
  # ------------------------------
  os_disk {
    caching              = "ReadWrite"    # Disk caching for better I/O performance
    storage_account_type = "Standard_LRS" # Standard locally-redundant storage (3 replicas in one region)
  }

  # ------------------------------
  # BASE OS IMAGE DETAILS
  # ------------------------------
  source_image_reference {
    publisher = "canonical"        # Canonical = official Ubuntu publisher
    offer     = "ubuntu-24_04-lts" # Ubuntu 24.04 LTS (long-term support) version
    sku       = "server"           # SKU defines the variant of the offer (here, server edition)
    version   = "latest"           # Always deploy the most recent image version
  }

  # ------------------------------
  # CUSTOM INITIALIZATION SCRIPT
  # ------------------------------
  custom_data = filebase64("scripts/custom_data.sh") # Base64-encoded shell script to initialize the VM at boot
  # Typical uses: install packages, configure services, write environment-specific configs, etc.
}
