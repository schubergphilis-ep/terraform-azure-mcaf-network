output "id" {
  description = "The ID of the network security group."
  value       = azurerm_network_security_group.this.id

  # Resolves after the rules, so a subnet is never associated while only Azure's defaults apply.
  depends_on = [azurerm_network_security_rule.this]
}

output "name" {
  description = "The name of the network security group."
  value       = azurerm_network_security_group.this.name
}

output "resource_group_name" {
  description = "The resource group of the network security group and its rules."
  value       = azurerm_network_security_group.this.resource_group_name
}

output "rule_names" {
  description = "The names of the rules on the group, after default, Bastion and custom rules are merged."
  value       = keys(local.rules)
}

output "location" {
  description = "The Azure region of the network security group, as Azure reports it."
  value       = azurerm_network_security_group.this.location
}
