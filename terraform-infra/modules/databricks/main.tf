###############################################################################
# Module: databricks
# Purpose: Azure Databricks workspace with VNet injection (Premium SKU
#          required for Unity Catalog).
#
# Naming: dbx-retailmax-{env}
# Managed RG: rg-retailmax-dbx-{env}-managed
###############################################################################

# --------------------------------------------------------------------------
# Databricks Workspace with VNet Injection
# --------------------------------------------------------------------------
resource "azurerm_databricks_workspace" "this" {
  name                          = "dbx-retailmax-${var.env}"
  location                      = var.location
  resource_group_name           = var.resource_group_name
  sku                           = "premium"
  managed_resource_group_name   = "rg-retailmax-dbx-${var.env}-managed"
  public_network_access_enabled = var.public_network_access_enabled

  custom_parameters {
    virtual_network_id                                   = var.vnet_id
    public_subnet_name                                   = var.public_subnet_name
    private_subnet_name                                  = var.private_subnet_name
    public_subnet_network_security_group_association_id  = var.public_subnet_nsg_association_id
    private_subnet_network_security_group_association_id = var.private_subnet_nsg_association_id
    no_public_ip                                         = var.no_public_ip
  }

  tags = var.tags
}
