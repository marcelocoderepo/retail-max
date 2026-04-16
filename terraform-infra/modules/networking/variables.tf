###############################################################################
# Module: networking - Variables
###############################################################################

variable "resource_group_name" {
  description = "Name of the resource group to deploy networking resources into"
  type        = string
}

variable "location" {
  description = "Azure region for all networking resources"
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

variable "vnet_address_space" {
  description = "CIDR block for the VNet (e.g., 10.0.0.0/16 for dev)"
  type        = string
}

variable "tags" {
  description = "Tags to apply to all networking resources"
  type        = map(string)
  default     = {}
}
