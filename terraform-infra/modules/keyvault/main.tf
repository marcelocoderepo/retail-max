###############################################################################
# Module: keyvault
# Purpose: Azure Key Vault with RBAC authorization, soft-delete, purge
#          protection, and Private Endpoint.
#
# Naming: kv-retailmax-{env}
###############################################################################

data "azurerm_client_config" "current" {}

# --------------------------------------------------------------------------
# Key Vault
# --------------------------------------------------------------------------
resource "azurerm_key_vault" "this" {
  name                          = "kv-retailmax-${var.env}"
  location                      = var.location
  resource_group_name           = var.resource_group_name
  tenant_id                     = data.azurerm_client_config.current.tenant_id
  sku_name                      = "standard"
  enable_rbac_authorization     = true
  soft_delete_retention_days    = 90
  purge_protection_enabled      = true
  public_network_access_enabled = false

  tags = var.tags
}

# --------------------------------------------------------------------------
# Private Endpoint - Vault
# --------------------------------------------------------------------------
resource "azurerm_private_endpoint" "vault" {
  name                = "pe-kv-retailmax-${var.env}-vault"
  location            = var.location
  resource_group_name = var.resource_group_name
  subnet_id           = var.subnet_id
  tags                = var.tags

  private_service_connection {
    name                           = "psc-kv-retailmax-${var.env}-vault"
    private_connection_resource_id = azurerm_key_vault.this.id
    is_manual_connection           = false
    subresource_names              = ["vault"]
  }

  dynamic "private_dns_zone_group" {
    for_each = var.vault_dns_zone_id != null ? [1] : []
    content {
      name                 = "default"
      private_dns_zone_ids = [var.vault_dns_zone_id]
    }
  }
}
