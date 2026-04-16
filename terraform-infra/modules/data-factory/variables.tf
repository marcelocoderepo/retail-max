###############################################################################
# Module: data-factory - Variables
###############################################################################

variable "resource_group_name" {
  description = "Name of the resource group"
  type        = string
}

variable "location" {
  description = "Azure region for the Data Factory"
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

variable "tags" {
  description = "Tags to apply to Data Factory resources"
  type        = map(string)
  default     = {}
}
