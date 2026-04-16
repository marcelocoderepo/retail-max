###############################################################################
# Module: identity - Variables
###############################################################################

variable "env" {
  description = "Environment identifier (dev, hml, prd)"
  type        = string

  validation {
    condition     = contains(["dev", "hml", "prd"], var.env)
    error_message = "Environment must be one of: dev, hml, prd."
  }
}

variable "resource_group_id" {
  description = "ID of the resource group (scope for Reader role assignment)"
  type        = string
}

variable "keyvault_id" {
  description = "ID of the Key Vault (scope for Secrets User role)"
  type        = string
}

variable "storage_account_id" {
  description = "ID of the Storage Account (scope for Blob Data Contributor role)"
  type        = string
}

variable "databricks_id" {
  description = "ID of the Databricks workspace (scope for Contributor role)"
  type        = string
}

variable "data_factory_principal_id" {
  description = "Principal ID of the Data Factory system-assigned managed identity"
  type        = string
}
