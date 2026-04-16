###############################################################################
# Module: data-factory - Outputs
###############################################################################

output "id" {
  description = "The ID of the Data Factory"
  value       = azurerm_data_factory.this.id
}

output "name" {
  description = "The name of the Data Factory"
  value       = azurerm_data_factory.this.name
}

output "identity_principal_id" {
  description = "The principal ID of the Data Factory system-assigned managed identity"
  value       = azurerm_data_factory.this.identity[0].principal_id
}

output "identity_tenant_id" {
  description = "The tenant ID of the Data Factory system-assigned managed identity"
  value       = azurerm_data_factory.this.identity[0].tenant_id
}
