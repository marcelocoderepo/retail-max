###############################################################################
# Module: policy - Variables
###############################################################################

variable "subscription_id" {
  description = "Azure Subscription ID where policies will be assigned"
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

variable "required_tags" {
  description = "List of tag names that must be present on all resources"
  type        = list(string)
  default     = ["project", "environment", "managed_by", "cost_center"]
}

variable "allowed_locations" {
  description = "List of Azure regions where resources can be deployed"
  type        = list(string)
  default     = ["eastus2", "eastus"]
}

variable "enforce_policies" {
  description = "Whether to enforce policies (true) or audit-only (false). Use false for dev."
  type        = bool
  default     = true
}
