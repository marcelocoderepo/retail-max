###############################################################################
# Module: monitoring - Variables
###############################################################################

variable "resource_group_name" {
  description = "Name of the resource group"
  type        = string
}

variable "resource_group_id" {
  description = "ID of the resource group (scope for budget)"
  type        = string
}

variable "location" {
  description = "Azure region for the Log Analytics workspace"
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

variable "data_factory_id" {
  description = "ID of the Azure Data Factory for diagnostic settings"
  type        = string
}

variable "databricks_id" {
  description = "ID of the Databricks workspace for diagnostic settings"
  type        = string
}

variable "monthly_budget" {
  description = "Monthly budget amount in the billing currency (e.g., USD)"
  type        = number
  default     = 500
}

variable "budget_start_date" {
  description = "Start date for the budget period (ISO 8601 format, first day of month, e.g., 2026-04-01T00:00:00Z)"
  type        = string
  default     = "2026-04-01T00:00:00Z"
}

variable "alert_emails" {
  description = "List of email addresses to receive budget alerts"
  type        = list(string)
  default     = []
}

variable "retention_days" {
  description = "Number of days to retain logs in Log Analytics"
  type        = number
  default     = 30
}

variable "tags" {
  description = "Tags to apply to monitoring resources"
  type        = map(string)
  default     = {}
}
