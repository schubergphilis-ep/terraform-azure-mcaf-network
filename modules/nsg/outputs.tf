output "id" {
  description = "The ID of the network security group. Only available once its rules exist, so attaching it never exposes a group carrying just Azure's defaults."
  value       = azurerm_network_security_group.this.id

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
