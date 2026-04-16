###############################################################################
# Module: identity - Outputs
###############################################################################

output "data_engineers_group_id" {
  description = "Object ID of the Data Engineers AD group"
  value       = azuread_group.data_engineers.object_id
}

output "data_readers_group_id" {
  description = "Object ID of the Data Readers AD group"
  value       = azuread_group.data_readers.object_id
}

output "data_engineers_group_name" {
  description = "Display name of the Data Engineers AD group"
  value       = azuread_group.data_engineers.display_name
}

output "data_readers_group_name" {
  description = "Display name of the Data Readers AD group"
  value       = azuread_group.data_readers.display_name
}
