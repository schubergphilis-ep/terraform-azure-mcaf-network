resource "azurerm_subnet" "this" {
  name                                          = var.name
  resource_group_name                           = var.resource_group_name
  virtual_network_name                          = var.virtual_network_name
  address_prefixes                              = var.address_prefixes
  default_outbound_access_enabled               = var.default_outbound_access_enabled
  private_endpoint_network_policies             = var.private_endpoint_network_policies
  private_link_service_network_policies_enabled = var.private_link_service_network_policies_enabled
  service_endpoints                             = var.service_endpoints

  dynamic "delegation" {
    for_each = var.delegate_to != null ? [var.delegate_to] : []

    content {
      name = split("/", var.delegate_to)[1]
      service_delegation {
        name    = var.delegate_to
        actions = var.delegate_to_actions != null ? var.delegate_to_actions : lookup(var.subnet_delegations_actions, var.delegate_to, null)
      }
    }
  }
}

