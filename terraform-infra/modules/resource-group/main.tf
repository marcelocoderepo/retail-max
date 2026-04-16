###############################################################################
# Module: resource-group
# Purpose: Creates an Azure Resource Group with standard tagging
###############################################################################

resource "azurerm_resource_group" "this" {
  name     = var.name
  location = var.location
  tags     = var.tags
}
