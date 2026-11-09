output "name" {
  description = "The name of the virtual network"
  value       = azurerm_virtual_network.this.name
}

output "vnet_id" {
  description = "The ID of the virtual network"
  value       = azurerm_virtual_network.this.id
}

output "subnets" {
  description = "A map of subnet names to their corresponding names, IDs and address prefixes"
  value = {
    for subnet in module.subnet : subnet.name => {
      name             = subnet.name
      id               = subnet.id
      address_prefixes = subnet.address_prefixes
    }
  }
}

output "private_dns_zone_list" {
  description = "A map of private DNS zone names to their corresponding names and IDs"
  value = {
    for private_dns_zone in azurerm_private_dns_zone.this : private_dns_zone.name => {
      name = private_dns_zone.name
      id   = private_dns_zone.id
    }
  }
}

output "all_subnets" {
  description = "A list of all subnets created"
  value = [for subnet in module.subnet : {
    name = subnet.name
    id   = subnet.id
  }]
}

output "all_network_security_groups" {
  description = "The network security groups created for individual subnets, keyed by subnet key. The shared group is not in it."
  value = {
    for key, subnet in module.subnet : key => {
      name     = subnet.network_security_group_name
      id       = subnet.network_security_group_id
      location = subnet.network_security_group_location
    } if subnet.network_security_group_name != null
  }
}

output "subnets_with_nsg" {
  description = "The subnets that asked for a network security group of their own."
  value       = local.subnets_with_nsg
}

output "subnets_with_nsg_azure_default" {
  description = "The subnets whose own group keeps only Azure's default rules plus `security_rules`."
  value       = local.subnets_with_nsg_azure_default
}

output "subnets_with_default_nsg" {
  description = "The subnets that use the shared group, or an existing one, unless `no_nsg_association` is set."
  value       = local.default_subnets
}
