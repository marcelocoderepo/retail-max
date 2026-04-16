###############################################################################
# Module: storage - Outputs
###############################################################################

output "id" {
  description = "The ID of the storage account"
  value       = azurerm_storage_account.this.id
}

output "name" {
  description = "The name of the storage account"
  value       = azurerm_storage_account.this.name
}

output "primary_dfs_endpoint" {
  description = "The primary DFS endpoint for ADLS Gen2"
  value       = azurerm_storage_account.this.primary_dfs_endpoint
}

output "primary_blob_endpoint" {
  description = "The primary blob endpoint"
  value       = azurerm_storage_account.this.primary_blob_endpoint
}

output "primary_access_key" {
  description = "The primary access key (sensitive - use managed identity instead)"
  value       = azurerm_storage_account.this.primary_access_key
  sensitive   = true
}
