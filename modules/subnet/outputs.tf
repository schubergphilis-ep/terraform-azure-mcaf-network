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

output "route_table_association_id" {
  description = "The ID of the route table association, or null when `route_table` is unset."
  value       = try(azurerm_subnet_route_table_association.this[0].id, null)
}
