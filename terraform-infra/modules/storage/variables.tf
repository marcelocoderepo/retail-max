###############################################################################
# Module: storage - Variables
###############################################################################

variable "resource_group_name" {
  description = "Name of the resource group"
  type        = string
}

variable "location" {
  description = "Azure region for the storage account"
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

variable "replication_type" {
  description = "Storage replication type (LRS for dev/hml, GRS for prd)"
  type        = string
  default     = "LRS"
}

variable "blob_dns_zone_id" {
  description = "ID of the privatelink.blob.core.windows.net DNS zone (optional)"
  type        = string
  default     = null
}

variable "dfs_dns_zone_id" {
  description = "ID of the privatelink.dfs.core.windows.net DNS zone (optional)"
  type        = string
  default     = null
}

variable "tags" {
  description = "Tags to apply to all storage resources"
  type        = map(string)
  default     = {}
}
