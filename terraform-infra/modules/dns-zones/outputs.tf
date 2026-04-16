###############################################################################
# Module: dns-zones - Outputs
###############################################################################

output "blob_dns_zone_id" {
  description = "ID of the privatelink.blob.core.windows.net DNS zone"
  value       = azurerm_private_dns_zone.blob.id
}

output "dfs_dns_zone_id" {
  description = "ID of the privatelink.dfs.core.windows.net DNS zone"
  value       = azurerm_private_dns_zone.dfs.id
}

output "vault_dns_zone_id" {
  description = "ID of the privatelink.vaultcore.azure.net DNS zone"
  value       = azurerm_private_dns_zone.vault.id
}

output "sql_dns_zone_id" {
  description = "ID of the privatelink.database.windows.net DNS zone"
  value       = azurerm_private_dns_zone.sql.id
}

output "databricks_dns_zone_id" {
  description = "ID of the privatelink.azuredatabricks.net DNS zone"
  value       = azurerm_private_dns_zone.databricks.id
}

output "blob_dns_zone_name" {
  description = "Name of the blob Private DNS zone"
  value       = azurerm_private_dns_zone.blob.name
}

output "dfs_dns_zone_name" {
  description = "Name of the DFS Private DNS zone"
  value       = azurerm_private_dns_zone.dfs.name
}
