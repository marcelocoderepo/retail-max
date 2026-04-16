###############################################################################
# Module: networking - Outputs
###############################################################################

output "vnet_id" {
  description = "The ID of the Virtual Network"
  value       = azurerm_virtual_network.this.id
}

output "vnet_name" {
  description = "The name of the Virtual Network"
  value       = azurerm_virtual_network.this.name
}

output "dbx_public_subnet_name" {
  description = "Name of the Databricks public subnet"
  value       = azurerm_subnet.dbx_public.name
}

output "dbx_private_subnet_name" {
  description = "Name of the Databricks private subnet"
  value       = azurerm_subnet.dbx_private.name
}

output "dbx_public_subnet_id" {
  description = "ID of the Databricks public subnet"
  value       = azurerm_subnet.dbx_public.id
}

output "dbx_private_subnet_id" {
  description = "ID of the Databricks private subnet"
  value       = azurerm_subnet.dbx_private.id
}

output "dbx_public_nsg_id" {
  description = "ID of the Databricks public subnet NSG"
  value       = azurerm_network_security_group.dbx_public.id
}

output "dbx_private_nsg_id" {
  description = "ID of the Databricks private subnet NSG"
  value       = azurerm_network_security_group.dbx_private.id
}

output "dbx_public_nsg_association_id" {
  description = "ID of the NSG-subnet association for Databricks public subnet (required for VNet injection)"
  value       = azurerm_subnet_network_security_group_association.dbx_public.id
}

output "dbx_private_nsg_association_id" {
  description = "ID of the NSG-subnet association for Databricks private subnet (required for VNet injection)"
  value       = azurerm_subnet_network_security_group_association.dbx_private.id
}

output "private_endpoints_subnet_id" {
  description = "ID of the Private Endpoints subnet"
  value       = azurerm_subnet.private_endpoints.id
}
