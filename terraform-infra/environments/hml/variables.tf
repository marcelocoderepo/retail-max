variable "location" {
  description = "Azure region for all resources"
  type        = string
  default     = "eastus2"
}

variable "subscription_id" {
  description = "Azure Subscription ID for the hml environment"
  type        = string
}

variable "monthly_budget" {
  description = "Monthly budget alert threshold in USD"
  type        = number
  default     = 500
}
