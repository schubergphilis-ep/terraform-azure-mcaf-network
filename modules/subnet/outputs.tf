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

