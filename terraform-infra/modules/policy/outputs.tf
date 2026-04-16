###############################################################################
# Module: policy - Outputs
###############################################################################

output "tag_policy_assignment_ids" {
  description = "Map of tag name to policy assignment ID for each required tag"
  value       = { for k, v in azurerm_subscription_policy_assignment.require_tags : k => v.id }
}

output "location_policy_assignment_id" {
  description = "ID of the allowed locations policy assignment"
  value       = azurerm_subscription_policy_assignment.allowed_locations.id
}
