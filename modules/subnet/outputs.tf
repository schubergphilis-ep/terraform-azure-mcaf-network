output "id" {
  description = "The ID of the subnet."
  value       = azurerm_subnet.this.id
}

output "name" {
  description = "The name of the subnet."
  value       = azurerm_subnet.this.name
}

output "address_prefixes" {
  description = "The address prefixes of the subnet."
  value       = azurerm_subnet.this.address_prefixes
}

output "network_security_group_id" {
  description = "The ID of the associated network security group, whether this module created it or the caller passed it in."
  value       = local.nsg_id
}


output "network_security_group_name" {
  description = "Name of the group this module created, or null when it associated one it does not own."
  value       = local.nsg_create ? azurerm_network_security_group.this[0].name : null
}
