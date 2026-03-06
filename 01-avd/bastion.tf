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
  name                = "bastion-public-ip"
  location            = var.project_location
  resource_group_name = azurerm_resource_group.project_rg.name
  allocation_method   = "Static"
  sku                 = "Standard"
}

# ================================================================================
# Azure Bastion host
# --------------------------------------------------------------------------------
# Deploys the Azure Bastion service which enables secure browser-based
# RDP/SSH connectivity to virtual machines without exposing VM public IPs.
#
# Requirements
# - Must be deployed in a subnet named "AzureBastionSubnet".
# - Requires a static Standard public IP.
# ================================================================================
resource "azurerm_bastion_host" "bastion-host" {
  name                = "bastion-host"
  location            = var.project_location
  resource_group_name = azurerm_resource_group.project_rg.name

  ip_configuration {
    name                 = "bastion-ip-config"
    subnet_id            = azurerm_subnet.bastion-subnet.id
    public_ip_address_id = azurerm_public_ip.bastion-ip.id
  }

    depends_on = [
    azurerm_subnet_network_security_group_association.bastion-nsg-assoc
  ]

}