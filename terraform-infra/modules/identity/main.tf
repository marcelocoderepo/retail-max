###############################################################################
# Module: identity
# Purpose: Azure AD Groups and RBAC role assignments for the RetailMax
#          platform. Assigns least-privilege access to Data Factory managed
#          identity and team groups.
#
# Groups:
#   - grp-retailmax-{env}-data-engineers  (Contributor on Databricks)
#   - grp-retailmax-{env}-data-readers    (Reader on Resource Group)
#
# Role assignments:
#   - ADF MI -> Storage Blob Data Contributor on Storage Account
#   - ADF MI -> Key Vault Secrets User on Key Vault
#   - Data Engineers group -> Contributor on Databricks workspace
#   - Data Readers group -> Reader on Resource Group
###############################################################################

data "azurerm_client_config" "current" {}

# --------------------------------------------------------------------------
# Azure AD Groups
# --------------------------------------------------------------------------
resource "azuread_group" "data_engineers" {
  display_name     = "grp-retailmax-${var.env}-data-engineers"
  security_enabled = true
  description      = "Data Engineers for RetailMax ${var.env} environment"
}

resource "azuread_group" "data_readers" {
  display_name     = "grp-retailmax-${var.env}-data-readers"
  security_enabled = true
  description      = "Data Readers (read-only) for RetailMax ${var.env} environment"
}

# --------------------------------------------------------------------------
# Role Assignments - Data Factory Managed Identity
# --------------------------------------------------------------------------

# ADF -> Storage Blob Data Contributor on the Storage Account
resource "azurerm_role_assignment" "adf_storage_contributor" {
  scope                = var.storage_account_id
  role_definition_name = "Storage Blob Data Contributor"
  principal_id         = var.data_factory_principal_id
}

# ADF -> Key Vault Secrets User on the Key Vault
resource "azurerm_role_assignment" "adf_keyvault_secrets_user" {
  scope                = var.keyvault_id
  role_definition_name = "Key Vault Secrets User"
  principal_id         = var.data_factory_principal_id
}

# --------------------------------------------------------------------------
# Role Assignments - AD Groups
# --------------------------------------------------------------------------

# Data Engineers -> Contributor on Databricks workspace
resource "azurerm_role_assignment" "engineers_databricks_contributor" {
  scope                = var.databricks_id
  role_definition_name = "Contributor"
  principal_id         = azuread_group.data_engineers.object_id
}

# Data Readers -> Reader on Resource Group
resource "azurerm_role_assignment" "readers_rg_reader" {
  scope                = var.resource_group_id
  role_definition_name = "Reader"
  principal_id         = azuread_group.data_readers.object_id
}
