resource "azurerm_virtual_network" "this" {
  name                = var.vnet_name
  location            = var.location
  resource_group_name = var.resource_group_name
  address_space       = var.vnet_address_space
  dns_servers         = var.vnet_dns_servers
  tags = merge(
    try(var.tags),
    tomap({
      "Resource Type" = "Virtual Network"
    })
  )
}

# Subnets live in ./modules/subnet so that callers whose virtual network is
# provisioned elsewhere can create just the subnets. Resource addresses are
# unchanged — moved.tf relocates existing state.
module "subnet" {
  source = "./modules/subnet"

  resource_group_name        = azurerm_virtual_network.this.resource_group_name
  virtual_network_name       = azurerm_virtual_network.this.name
  subnet_delegations_actions = var.subnet_delegations_actions

  # Projected down to the attributes the submodule implements, rather than
  # forwarding var.subnets wholesale. Network security groups, NAT gateways,
  # service endpoint policies and role assignments are composed by this
  # module's own resources against the subnet IDs it returns, so passing them
  # down would only let the submodule accept inputs it silently drops.
  subnets = {
    for key, subnet in var.subnets : key => {
      name                                          = subnet.name
      address_prefixes                              = subnet.address_prefixes
      default_outbound_access_enabled               = subnet.default_outbound_access_enabled
      delegate_to                                   = subnet.delegate_to
      delegate_to_actions                           = subnet.delegate_to_actions
      private_endpoint_network_policies             = subnet.private_endpoint_network_policies
      private_link_service_network_policies_enabled = subnet.private_link_service_network_policies_enabled
      service_endpoints                             = subnet.service_endpoints

      # Opt-in, because this module accepted `route_table` and never acted on it
      # up to v1.0.0. Honouring it unconditionally would attach route tables to
      # existing live subnets on upgrade — a routing change, not a no-op.
      route_table = var.manage_route_table_associations ? subnet.route_table : null
    }
  }
}
