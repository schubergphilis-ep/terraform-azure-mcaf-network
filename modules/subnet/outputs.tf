output "subnets" {
  description = "Map of subnet name to its name, ID and address prefixes. Shape matches the root module's `subnets` output."
  value = {
    for subnet in azurerm_subnet.this : subnet.name => {
      name             = subnet.name
      id               = subnet.id
      address_prefixes = subnet.address_prefixes
    }
  }
}

output "subnet_ids" {
  description = "Map of the `subnets` input key to the created subnet ID. Keyed by input key rather than subnet name, so callers can look a subnet up without knowing whether `name` was overridden."
  value       = { for key, subnet in azurerm_subnet.this : key => subnet.id }
}

output "route_table_association_ids" {
  description = "Map of the `subnets` input key to the route table association ID, for subnets that set `route_table`."
  value       = { for key, association in azurerm_subnet_route_table_association.this : key => association.id }
}
