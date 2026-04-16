###############################################################################
# Module: keyvault - Variables
###############################################################################

variable "resource_group_name" {
  description = "Name of the resource group"
  type        = string
}

variable "location" {
  description = "Azure region for the Key Vault"
  type        = string
  default     = "eastus2"
}

variable "env" {
  description = "Environment identifier (dev, hml, prd)"
  type        = string

  validation {
    condition     = contains(["dev", "hml", "prd"], var.env)
    error_message = "Environment must be one of: dev, hml, prd."
  }
}

variable "subnet_id" {
  description = "ID of the Private Endpoints subnet"
  type        = string
}

variable "vault_dns_zone_id" {
  description = "ID of the privatelink.vaultcore.azure.net DNS zone (optional)"
  type        = string
  default     = null
}

variable "tags" {
  description = "Tags to apply to Key Vault resources"
  type        = map(string)
  default     = {}
}
