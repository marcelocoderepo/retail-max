###############################################################################
# Module: data-factory
# Purpose: Azure Data Factory with system-assigned managed identity and
#          managed virtual network integration.
#
# Naming: adf-retailmax-{env}
###############################################################################

# --------------------------------------------------------------------------
# Azure Data Factory
# --------------------------------------------------------------------------
resource "azurerm_data_factory" "this" {
  name                            = "adf-retailmax-${var.env}"
  location                        = var.location
  resource_group_name             = var.resource_group_name
  managed_virtual_network_enabled = true
  public_network_enabled          = false

  identity {
    type = "SystemAssigned"
  }

  tags = var.tags
}
