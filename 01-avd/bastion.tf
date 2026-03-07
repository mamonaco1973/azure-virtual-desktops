# ================================================================================
# Azure Bastion public IP
# --------------------------------------------------------------------------------
# Creates the public IP address used by the Azure Bastion host.
#
# Notes
# - Bastion requires a static public IP.
# - Standard SKU is required for Azure Bastion.
# ================================================================================

resource "azurerm_public_ip" "bastion-ip" {

  count = var.bastion_support ? 1 : 0

  name                = "bastion-public-ip"
  location            = var.project_location
  resource_group_name = azurerm_resource_group.project_rg.name
  allocation_method   = "Static"
  sku                 = "Standard"
}

# ================================================================================
# Azure Bastion subnet
# --------------------------------------------------------------------------------
# Creates the dedicated subnet required by Azure Bastion.
#
# Requirements
# - The subnet name must be exactly "AzureBastionSubnet".
# - Uses the upper half of the VNet address space.
# ================================================================================

resource "azurerm_subnet" "bastion-subnet" {

  count = var.bastion_support ? 1 : 0

  name                 = "AzureBastionSubnet"
  resource_group_name  = azurerm_resource_group.project_rg.name
  virtual_network_name = azurerm_virtual_network.project-vnet.name
  address_prefixes     = ["10.0.1.0/25"]
}

# ================================================================================
# Bastion subnet network security group
# --------------------------------------------------------------------------------
# Creates the NSG required for Azure Bastion operation.
#
# Notes
# - Azure Bastion requires specific inbound and outbound rules.
# - These rules allow Bastion control plane and VM connectivity.
# ================================================================================

resource "azurerm_network_security_group" "bastion-nsg" {

  count = var.bastion_support ? 1 : 0

  name                = "bastion-nsg"
  location            = var.project_location
  resource_group_name = azurerm_resource_group.project_rg.name

  # ---------------------------------------------------------------------------
  # Allow inbound HTTPS from Azure GatewayManager
  # ---------------------------------------------------------------------------
  security_rule {
    name                       = "GatewayManager"
    priority                   = 1001
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "443"
    source_address_prefix      = "GatewayManager"
    destination_address_prefix = "*"
  }

  # ---------------------------------------------------------------------------
  # Allow inbound HTTPS from the internet to the Bastion public IP
  # ---------------------------------------------------------------------------
  security_rule {
    name                       = "Internet-Bastion-PublicIP"
    priority                   = 1002
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "443"
    source_address_prefix      = "*"
    destination_address_prefix = "*"
  }

  # ---------------------------------------------------------------------------
  # Allow outbound SSH and RDP from Bastion to private VMs
  # ---------------------------------------------------------------------------
  security_rule {
    name                       = "OutboundVirtualNetwork"
    priority                   = 1001
    direction                  = "Outbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_ranges    = ["22", "3389"]
    source_address_prefix      = "*"
    destination_address_prefix = "VirtualNetwork"
  }

  # ---------------------------------------------------------------------------
  # Allow outbound HTTPS to Azure infrastructure
  # ---------------------------------------------------------------------------
  security_rule {
    name                       = "OutboundToAzureCloud"
    priority                   = 1002
    direction                  = "Outbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "443"
    source_address_prefix      = "*"
    destination_address_prefix = "AzureCloud"
  }
}

# ================================================================================
# Bastion subnet to NSG association
# --------------------------------------------------------------------------------
# Associates the Azure Bastion subnet with the Bastion NSG.
# ================================================================================

resource "azurerm_subnet_network_security_group_association" "bastion-nsg-assoc" {

  count = var.bastion_support ? 1 : 0

  subnet_id                 = azurerm_subnet.bastion-subnet[0].id
  network_security_group_id = azurerm_network_security_group.bastion-nsg[0].id
}

# ================================================================================
# Azure Bastion host
# --------------------------------------------------------------------------------
# Deploys the Azure Bastion service which enables secure browser-based
# RDP/SSH connectivity to virtual machines without exposing VM public IPs.
# ================================================================================

resource "azurerm_bastion_host" "bastion-host" {

  count = var.bastion_support ? 1 : 0

  name                = "bastion-host"
  location            = var.project_location
  resource_group_name = azurerm_resource_group.project_rg.name

  ip_configuration {
    name                 = "bastion-ip-config"
    subnet_id            = azurerm_subnet.bastion-subnet[0].id
    public_ip_address_id = azurerm_public_ip.bastion-ip[0].id
  }

  depends_on = [
    azurerm_subnet_network_security_group_association.bastion-nsg-assoc
  ]
}