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

# Subnets live in ./modules/subnet so callers with an external VNet can use them alone.
module "subnet" {
  source   = "./modules/subnet"
  for_each = var.subnets

  name                 = each.value.name != null ? each.value.name : each.key
  resource_group_name  = azurerm_virtual_network.this.resource_group_name
  virtual_network_name = azurerm_virtual_network.this.name
  address_prefixes     = each.value.address_prefixes

  # id only: the root owns its groups and their rules, so the submodule associates and nothing more.
  network_security_group = lookup(local.subnet_network_security_group, each.key, null)
  route_table_id         = each.value.route_table == null ? null : each.value.route_table.id

  default_outbound_access_enabled               = each.value.default_outbound_access_enabled
  delegate_to                                   = each.value.delegate_to
  delegate_to_actions                           = each.value.delegate_to_actions
  private_endpoint_network_policies             = each.value.private_endpoint_network_policies
  private_link_service_network_policies_enabled = each.value.private_link_service_network_policies_enabled
  service_endpoints                             = each.value.service_endpoints
  subnet_delegations_actions                    = var.subnet_delegations_actions
}
