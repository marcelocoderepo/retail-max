###############################################################################
# Module: dns-zones - Variables
###############################################################################

variable "resource_group_name" {
  description = "Name of the resource group for the DNS zones"
  type        = string
}

variable "vnet_id" {
  description = "ID of the VNet to link the DNS zones to"
  type        = string
}

variable "env" {
  description = "Environment identifier (dev, hml, prd)"
  type        = string

  validation {
    condition     = contains(["dev", "hml", "prd"], var.env)
    error_message = "Environment must be one of: dev, hml, prd."
  }
}

variable "tags" {
  description = "Tags to apply to DNS zone resources"
  type        = map(string)
  default     = {}
}
