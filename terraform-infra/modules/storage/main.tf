###############################################################################
# Module: storage
# Purpose: ADLS Gen2 storage account with hierarchical namespace,
#          4 containers (bronze, silver, gold, landing), and Private Endpoints
#          for blob and dfs sub-resources.
#
# Naming: stretailmax{env} (no hyphens, max 24 chars)
###############################################################################

data "azurerm_client_config" "current" {}

# --------------------------------------------------------------------------
# Storage Account (ADLS Gen2)
# --------------------------------------------------------------------------
resource "azurerm_storage_account" "this" {
  name                     = "stretailmax${var.env}"
  resource_group_name      = var.resource_group_name
  location                 = var.location
  account_tier             = "Standard"
  account_replication_type = var.replication_type
  account_kind             = "StorageV2"
  is_hns_enabled           = true
  min_tls_version          = "TLS1_2"

  # Disable anonymous public access to blobs
  allow_nested_items_to_be_public = false

  tags = var.tags
}

# --------------------------------------------------------------------------
# Data Lake Containers (Medallion layers + landing)
# --------------------------------------------------------------------------
resource "azurerm_storage_container" "bronze" {
  name                  = "bronze"
  storage_account_id    = azurerm_storage_account.this.id
  container_access_type = "private"
}

resource "azurerm_storage_container" "silver" {
  name                  = "silver"
  storage_account_id    = azurerm_storage_account.this.id
  container_access_type = "private"
}

resource "azurerm_storage_container" "gold" {
  name                  = "gold"
  storage_account_id    = azurerm_storage_account.this.id
  container_access_type = "private"
}

resource "azurerm_storage_container" "landing" {
  name                  = "landing"
  storage_account_id    = azurerm_storage_account.this.id
  container_access_type = "private"
}

# --------------------------------------------------------------------------
# Private Endpoint - Blob
# --------------------------------------------------------------------------
resource "azurerm_private_endpoint" "blob" {
  name                = "pe-stretailmax${var.env}-blob"
  location            = var.location
  resource_group_name = var.resource_group_name
  subnet_id           = var.subnet_id
  tags                = var.tags

  private_service_connection {
    name                           = "psc-stretailmax${var.env}-blob"
    private_connection_resource_id = azurerm_storage_account.this.id
    is_manual_connection           = false
    subresource_names              = ["blob"]
  }

  dynamic "private_dns_zone_group" {
    for_each = var.blob_dns_zone_id != null ? [1] : []
    content {
      name                 = "default"
      private_dns_zone_ids = [var.blob_dns_zone_id]
    }
  }
}

# --------------------------------------------------------------------------
# Private Endpoint - DFS (Data Lake Storage)
# --------------------------------------------------------------------------
resource "azurerm_private_endpoint" "dfs" {
  name                = "pe-stretailmax${var.env}-dfs"
  location            = var.location
  resource_group_name = var.resource_group_name
  subnet_id           = var.subnet_id
  tags                = var.tags

  private_service_connection {
    name                           = "psc-stretailmax${var.env}-dfs"
    private_connection_resource_id = azurerm_storage_account.this.id
    is_manual_connection           = false
    subresource_names              = ["dfs"]
  }

  dynamic "private_dns_zone_group" {
    for_each = var.dfs_dns_zone_id != null ? [1] : []
    content {
      name                 = "default"
      private_dns_zone_ids = [var.dfs_dns_zone_id]
    }
  }
}
