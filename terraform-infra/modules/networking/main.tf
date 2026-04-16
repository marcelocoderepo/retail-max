###############################################################################
# Module: networking
# Purpose: VNet with 3 subnets (Databricks public, Databricks private,
#          Private Endpoints) + NSGs for each subnet.
#
# Address space convention:
#   dev = 10.0.0.0/16, hml = 10.2.0.0/16, prd = 10.1.0.0/16
#   Subnets use x.x.1.0/24, x.x.2.0/24, x.x.3.0/24
###############################################################################

# --------------------------------------------------------------------------
# Virtual Network
# --------------------------------------------------------------------------
resource "azurerm_virtual_network" "this" {
  name                = "vnet-retailmax-${var.env}"
  location            = var.location
  resource_group_name = var.resource_group_name
  address_space       = [var.vnet_address_space]
  tags                = var.tags
}

# --------------------------------------------------------------------------
# Derive the first two octets from the VNet address space for subnet CIDRs
# --------------------------------------------------------------------------
locals {
  # Extract base prefix (e.g., "10.0" from "10.0.0.0/16")
  vnet_octets = split(".", var.vnet_address_space)
  base_prefix = "${local.vnet_octets[0]}.${local.vnet_octets[1]}"
}

# --------------------------------------------------------------------------
# NSGs
# --------------------------------------------------------------------------
resource "azurerm_network_security_group" "dbx_public" {
  name                = "nsg-dbx-public-${var.env}"
  location            = var.location
  resource_group_name = var.resource_group_name
  tags                = var.tags
}

resource "azurerm_network_security_group" "dbx_private" {
  name                = "nsg-dbx-private-${var.env}"
  location            = var.location
  resource_group_name = var.resource_group_name
  tags                = var.tags
}

resource "azurerm_network_security_group" "private_endpoints" {
  name                = "nsg-private-endpoints-${var.env}"
  location            = var.location
  resource_group_name = var.resource_group_name
  tags                = var.tags
}

# Deny all inbound internet traffic to Private Endpoints subnet
resource "azurerm_network_security_rule" "pe_deny_internet_inbound" {
  name                        = "DenyInternetInbound"
  priority                    = 100
  direction                   = "Inbound"
  access                      = "Deny"
  protocol                    = "*"
  source_port_range           = "*"
  destination_port_range      = "*"
  source_address_prefix       = "Internet"
  destination_address_prefix  = "*"
  resource_group_name         = var.resource_group_name
  network_security_group_name = azurerm_network_security_group.private_endpoints.name
}

# --------------------------------------------------------------------------
# Subnets
# --------------------------------------------------------------------------
resource "azurerm_subnet" "dbx_public" {
  name                 = "snet-dbx-public-${var.env}"
  resource_group_name  = var.resource_group_name
  virtual_network_name = azurerm_virtual_network.this.name
  address_prefixes     = ["${local.base_prefix}.1.0/24"]

  delegation {
    name = "databricks-del-public"

    service_delegation {
      name = "Microsoft.Databricks/workspaces"
      actions = [
        "Microsoft.Network/virtualNetworks/subnets/join/action",
        "Microsoft.Network/virtualNetworks/subnets/prepareNetworkPolicies/action",
        "Microsoft.Network/virtualNetworks/subnets/unprepareNetworkPolicies/action",
      ]
    }
  }
}

resource "azurerm_subnet" "dbx_private" {
  name                 = "snet-dbx-private-${var.env}"
  resource_group_name  = var.resource_group_name
  virtual_network_name = azurerm_virtual_network.this.name
  address_prefixes     = ["${local.base_prefix}.2.0/24"]

  delegation {
    name = "databricks-del-private"

    service_delegation {
      name = "Microsoft.Databricks/workspaces"
      actions = [
        "Microsoft.Network/virtualNetworks/subnets/join/action",
        "Microsoft.Network/virtualNetworks/subnets/prepareNetworkPolicies/action",
        "Microsoft.Network/virtualNetworks/subnets/unprepareNetworkPolicies/action",
      ]
    }
  }
}

resource "azurerm_subnet" "private_endpoints" {
  name                 = "snet-private-endpoints-${var.env}"
  resource_group_name  = var.resource_group_name
  virtual_network_name = azurerm_virtual_network.this.name
  address_prefixes     = ["${local.base_prefix}.3.0/24"]
}

# --------------------------------------------------------------------------
# NSG <-> Subnet Associations
# --------------------------------------------------------------------------
resource "azurerm_subnet_network_security_group_association" "dbx_public" {
  subnet_id                 = azurerm_subnet.dbx_public.id
  network_security_group_id = azurerm_network_security_group.dbx_public.id
}

resource "azurerm_subnet_network_security_group_association" "dbx_private" {
  subnet_id                 = azurerm_subnet.dbx_private.id
  network_security_group_id = azurerm_network_security_group.dbx_private.id
}

resource "azurerm_subnet_network_security_group_association" "private_endpoints" {
  subnet_id                 = azurerm_subnet.private_endpoints.id
  network_security_group_id = azurerm_network_security_group.private_endpoints.id
}
