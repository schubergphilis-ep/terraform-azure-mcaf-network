################################################################################
# Subnets on a virtual network this module does not own.
#
# The root module creates a virtual network and calls this to populate it. Call
# it directly when the network is provisioned elsewhere — a platform team, a
# separate state, another repository — and only the subnets are yours.
#
# Subnet resource addresses are identical to the root module's former inline
# ones, so the root can adopt this via a `moved` block with no replacements.
# See MIGRATION.md.
################################################################################

resource "azurerm_subnet" "this" {
  for_each = var.subnets

  name                                          = each.value.name != null ? each.value.name : each.key
  resource_group_name                           = var.resource_group_name
  default_outbound_access_enabled               = each.value.default_outbound_access_enabled
  virtual_network_name                          = var.virtual_network_name
  address_prefixes                              = each.value.address_prefixes
  private_endpoint_network_policies             = each.value.private_endpoint_network_policies != null ? each.value.private_endpoint_network_policies : "Disabled"
  private_link_service_network_policies_enabled = each.value.private_link_service_network_policies_enabled != null ? each.value.private_link_service_network_policies_enabled : true

  dynamic "delegation" {
    for_each = each.value.delegate_to != null ? [each.value.delegate_to] : []

    content {
      name = split("/", each.value.delegate_to)[1]
      service_delegation {
        name    = each.value.delegate_to
        actions = each.value.delegate_to_actions != null ? each.value.delegate_to_actions : lookup(var.subnet_delegations_actions, each.value.delegate_to, null)
      }
    }
  }

  service_endpoints = each.value.service_endpoints
}

# Honours the `route_table` attribute on a subnet. Before this submodule the
# attribute was accepted by the root module and silently ignored, because no
# resource read it — see MIGRATION.md, this is the one behavioural change.
resource "azurerm_subnet_route_table_association" "this" {
  for_each = { for key, subnet in var.subnets : key => subnet if subnet.route_table != null }

  subnet_id      = azurerm_subnet.this[each.key].id
  route_table_id = each.value.route_table.id
}
