###############################################################################
# Module: databricks - Variables
###############################################################################

variable "resource_group_name" {
  description = "Name of the resource group"
  type        = string
}

variable "location" {
  description = "Azure region for the Databricks workspace"
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

variable "vnet_id" {
  description = "ID of the VNet for VNet injection"
  type        = string
}

variable "public_subnet_name" {
  description = "Name of the Databricks public (host) subnet"
  type        = string
}

variable "private_subnet_name" {
  description = "Name of the Databricks private (container) subnet"
  type        = string
}

variable "public_subnet_nsg_association_id" {
  description = "ID of the NSG association for the public subnet"
  type        = string
}

variable "private_subnet_nsg_association_id" {
  description = "ID of the NSG association for the private subnet"
  type        = string
}

variable "no_public_ip" {
  description = "Whether to disable public IPs on Databricks cluster nodes (Secure Cluster Connectivity)"
  type        = bool
  default     = true
}

variable "public_network_access_enabled" {
  description = "Whether public network access is allowed to the workspace"
  type        = bool
  default     = true
}

variable "tags" {
  description = "Tags to apply to the Databricks workspace"
  type        = map(string)
  default     = {}
}
