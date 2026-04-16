###############################################################################
# Module: keyvault - Outputs
###############################################################################

output "id" {
  description = "The ID of the Key Vault"
  value       = azurerm_key_vault.this.id
}

output "uri" {
  description = "The URI of the Key Vault"
  value       = azurerm_key_vault.this.vault_uri
}

output "name" {
  description = "The name of the Key Vault"
  value       = azurerm_key_vault.this.name
}

output "tenant_id" {
  description = "The tenant ID used by the Key Vault"
  value       = azurerm_key_vault.this.tenant_id
}
