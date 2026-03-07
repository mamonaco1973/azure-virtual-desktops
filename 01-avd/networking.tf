# ================================================================================
# Virtual network
# --------------------------------------------------------------------------------
# Creates the project virtual network that contains the workload subnet
# and the Azure Bastion subnet.
#
# Addressing
# - VNet CIDR: 10.0.0.0/23
# - VM subnet: 10.0.0.0/25
# - Bastion subnet: 10.0.1.0/25
# ================================================================================
resource "azurerm_virtual_network" "project-vnet" {
  name                = var.project_vnet
  address_space       = ["10.0.0.0/23"]
  location            = var.project_location
  resource_group_name = azurerm_resource_group.project_rg.name
}

# ================================================================================
# VM subnet
# --------------------------------------------------------------------------------
# Creates the subnet used by application and virtual machine workloads.
#
# Notes
# - Uses the lower half of the VNet address space.
# - Default outbound access is disabled.
# - Outbound internet access is provided later through a NAT Gateway.
# ================================================================================
resource "azurerm_subnet" "vm-subnet" {
  name                            = var.project_subnet
  resource_group_name             = azurerm_resource_group.project_rg.name
  virtual_network_name            = azurerm_virtual_network.project-vnet.name
  address_prefixes                = ["10.0.0.0/25"]
  default_outbound_access_enabled = false
}

# ================================================================================
# VM subnet network security group
# --------------------------------------------------------------------------------
# Creates the NSG applied to the VM subnet.
#
# Inbound access
# - SSH   : TCP 22
# - RDP   : TCP 3389
# - HTTP  : TCP 80
# ================================================================================
resource "azurerm_network_security_group" "vm-nsg" {
  name                = "vm-nsg"
  location            = var.project_location
  resource_group_name = azurerm_resource_group.project_rg.name

  # ---------------------------------------------------------------------------
  # Allow SSH
  # ---------------------------------------------------------------------------
  security_rule {
    name                       = "Allow-SSH"
    priority                   = 1000
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "22"
    source_address_prefix      = "*"
    destination_address_prefix = "*"
  }

  # ---------------------------------------------------------------------------
  # Allow RDP
  # ---------------------------------------------------------------------------
  security_rule {
    name                       = "Allow-RDP"
    priority                   = 1001
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "3389"
    source_address_prefix      = "*"
    destination_address_prefix = "*"
  }

  # ---------------------------------------------------------------------------
  # Allow HTTP
  # ---------------------------------------------------------------------------
  security_rule {
    name                       = "Allow-HTTP"
    priority                   = 1002
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "80"
    source_address_prefix      = "*"
    destination_address_prefix = "*"
  }
}


# ================================================================================
# VM subnet to NSG association
# --------------------------------------------------------------------------------
# Associates the VM subnet with the VM NSG.
# ================================================================================
resource "azurerm_subnet_network_security_group_association" "vm-nsg-assoc" {
  subnet_id                 = azurerm_subnet.vm-subnet.id
  network_security_group_id = azurerm_network_security_group.vm-nsg.id
}

# ================================================================================
# NAT Gateway
# --------------------------------------------------------------------------------
# Creates the NAT Gateway used to provide outbound internet access for
# private resources in the VM subnet.
# ================================================================================
resource "azurerm_nat_gateway" "vm-nat-gateway" {
  name                = "vm-nat-gateway"
  location            = var.project_location
  resource_group_name = azurerm_resource_group.project_rg.name
  sku_name            = "Standard"
}

# ================================================================================
# NAT Gateway public IP
# --------------------------------------------------------------------------------
# Creates the static public IP used by the NAT Gateway.
#
# Notes
# - Must use Standard SKU.
# - Static allocation provides a predictable outbound IP.
# ================================================================================
resource "azurerm_public_ip" "vm_nat_public_ip" {
  name                = "vm-nat-public-ip"
  location            = var.project_location
  resource_group_name = azurerm_resource_group.project_rg.name
  allocation_method   = "Static"
  sku                 = "Standard"
}

# ================================================================================
# NAT Gateway public IP association
# --------------------------------------------------------------------------------
# Associates the static public IP with the NAT Gateway.
# ================================================================================
resource "azurerm_nat_gateway_public_ip_association" "vm_nat_assoc" {
  nat_gateway_id       = azurerm_nat_gateway.vm-nat-gateway.id
  public_ip_address_id = azurerm_public_ip.vm_nat_public_ip.id
}

# ================================================================================
# VM subnet NAT Gateway association
# --------------------------------------------------------------------------------
# Attaches the NAT Gateway to the VM subnet so private VMs can reach the
# internet for outbound connections.
# ================================================================================
resource "azurerm_subnet_nat_gateway_association" "vm_subnet_nat" {
  subnet_id      = azurerm_subnet.vm-subnet.id
  nat_gateway_id = azurerm_nat_gateway.vm-nat-gateway.id
}