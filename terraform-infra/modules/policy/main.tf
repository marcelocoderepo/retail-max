###############################################################################
# Module: policy
# Purpose: Azure Policy definitions and assignments for governance.
#
# Policies:
#   1. Require tags - enforces mandatory tags on all resources
#   2. Allowed locations - restricts resource deployment to approved regions
#
# Scope: Subscription level
###############################################################################

# --------------------------------------------------------------------------
# Policy 1: Require Tags
# Uses the built-in "Require a tag on resources" policy definition
# (one assignment per required tag)
# --------------------------------------------------------------------------
data "azurerm_policy_definition" "require_tag" {
  display_name = "Require a tag on resources"
}

resource "azurerm_subscription_policy_assignment" "require_tags" {
  for_each = toset(var.required_tags)

  name                 = "require-tag-${each.value}-${var.env}"
  display_name         = "Require tag: ${each.value} (${var.env})"
  description          = "Enforces the '${each.value}' tag on all resources in the ${var.env} environment."
  policy_definition_id = data.azurerm_policy_definition.require_tag.id
  subscription_id      = "/subscriptions/${var.subscription_id}"
  enforce              = var.enforce_policies

  parameters = jsonencode({
    tagName = {
      value = each.value
    }
  })
}

# --------------------------------------------------------------------------
# Policy 2: Allowed Locations
# Uses the built-in "Allowed locations" policy definition
# --------------------------------------------------------------------------
data "azurerm_policy_definition" "allowed_locations" {
  display_name = "Allowed locations"
}

resource "azurerm_subscription_policy_assignment" "allowed_locations" {
  name                 = "allowed-locations-${var.env}"
  display_name         = "Allowed locations (${var.env})"
  description          = "Restricts resource deployment to approved Azure regions for the ${var.env} environment."
  policy_definition_id = data.azurerm_policy_definition.allowed_locations.id
  subscription_id      = "/subscriptions/${var.subscription_id}"
  enforce              = var.enforce_policies

  parameters = jsonencode({
    listOfAllowedLocations = {
      value = var.allowed_locations
    }
  })
}
