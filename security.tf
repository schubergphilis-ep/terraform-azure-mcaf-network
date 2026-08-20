resource "azurerm_network_security_group" "this" {
  name                = "${var.vnet_name}-nsg"
  location            = azurerm_virtual_network.this.location
  resource_group_name = azurerm_virtual_network.this.resource_group_name

  tags = merge(
    try(var.tags),
    tomap({
      "Resource Type" = "Network Security Group"
    })
  )
}

resource "azurerm_network_security_rule" "default" {
  for_each = local.security_rules

  name                                       = each.value.name
  priority                                   = each.value.priority
  direction                                  = each.value.direction
  access                                     = each.value.access
  protocol                                   = each.value.protocol
  source_port_range                          = each.value.source_port_range
  source_port_ranges                         = each.value.source_port_ranges
  destination_port_range                     = each.value.destination_port_range
  destination_port_ranges                    = each.value.destination_port_ranges
  destination_application_security_group_ids = each.value.destination_application_security_group_ids
  source_address_prefix                      = each.value.source_address_prefix
  source_address_prefixes                    = each.value.source_address_prefixes
  source_application_security_group_ids      = each.value.source_application_security_group_ids
  destination_address_prefix                 = each.value.destination_address_prefix
  destination_address_prefixes               = each.value.destination_address_prefixes
  resource_group_name                        = azurerm_network_security_group.this.resource_group_name
  network_security_group_name                = azurerm_network_security_group.this.name
}

## Simple NSG, Default Azure
