###############################################################################
# Module: monitoring
# Purpose: Log Analytics workspace for centralized logging, diagnostic
#          settings for ADF and Databricks, and Azure budget alerts.
#
# Naming: log-retailmax-{env}, budget-retailmax-{env}
###############################################################################

# --------------------------------------------------------------------------
# Log Analytics Workspace
# --------------------------------------------------------------------------
resource "azurerm_log_analytics_workspace" "this" {
  name                = "log-retailmax-${var.env}"
  location            = var.location
  resource_group_name = var.resource_group_name
  sku                 = "PerGB2018"
  retention_in_days   = var.retention_days

  tags = var.tags
}

# --------------------------------------------------------------------------
# Diagnostic Settings - Azure Data Factory
# --------------------------------------------------------------------------
resource "azurerm_monitor_diagnostic_setting" "adf" {
  name                       = "diag-adf-retailmax-${var.env}"
  target_resource_id         = var.data_factory_id
  log_analytics_workspace_id = azurerm_log_analytics_workspace.this.id

  enabled_log {
    category = "PipelineRuns"
  }

  enabled_log {
    category = "TriggerRuns"
  }

  enabled_log {
    category = "ActivityRuns"
  }

  metric {
    category = "AllMetrics"
    enabled  = true
  }
}

# --------------------------------------------------------------------------
# Diagnostic Settings - Azure Databricks
# --------------------------------------------------------------------------
resource "azurerm_monitor_diagnostic_setting" "databricks" {
  name                       = "diag-dbx-retailmax-${var.env}"
  target_resource_id         = var.databricks_id
  log_analytics_workspace_id = azurerm_log_analytics_workspace.this.id

  enabled_log {
    category = "dbfs"
  }

  enabled_log {
    category = "clusters"
  }

  enabled_log {
    category = "accounts"
  }

  enabled_log {
    category = "jobs"
  }

  enabled_log {
    category = "notebook"
  }

  enabled_log {
    category = "workspace"
  }
}

# --------------------------------------------------------------------------
# Consumption Budget with Alert Thresholds
# --------------------------------------------------------------------------
data "azurerm_subscription" "current" {}

resource "azurerm_consumption_budget_resource_group" "this" {
  name              = "budget-retailmax-${var.env}"
  resource_group_id = var.resource_group_id
  amount            = var.monthly_budget
  time_grain        = "Monthly"

  time_period {
    start_date = var.budget_start_date
  }

  notification {
    enabled        = true
    threshold      = 80
    operator       = "GreaterThan"
    threshold_type = "Actual"

    contact_emails = var.alert_emails
  }

  notification {
    enabled        = true
    threshold      = 100
    operator       = "GreaterThan"
    threshold_type = "Actual"

    contact_emails = var.alert_emails
  }

  notification {
    enabled        = true
    threshold      = 100
    operator       = "GreaterThan"
    threshold_type = "Forecasted"

    contact_emails = var.alert_emails
  }
}
