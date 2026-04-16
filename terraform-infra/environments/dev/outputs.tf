output "resource_group_name" {
  value = module.resource_group.name
}

output "resource_group_id" {
  value = module.resource_group.id
}

output "vnet_id" {
  value = module.networking.vnet_id
}

output "storage_account_name" {
  value = module.storage.name
}

output "storage_account_id" {
  value = module.storage.id
}

output "keyvault_id" {
  value = module.keyvault.id
}

output "keyvault_uri" {
  value = module.keyvault.uri
}

output "databricks_workspace_url" {
  value = module.databricks.workspace_url
}

output "databricks_workspace_id" {
  value = module.databricks.workspace_id
}

output "data_factory_name" {
  value = module.data_factory.name
}

output "data_factory_id" {
  value = module.data_factory.id
}

output "log_analytics_workspace_id" {
  value = module.monitoring.log_analytics_workspace_id
}
