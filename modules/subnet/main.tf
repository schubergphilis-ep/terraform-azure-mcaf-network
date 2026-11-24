resource "azurerm_subnet" "this" {
  name                                          = var.name
  resource_group_name                           = var.resource_group_name
  virtual_network_name                          = var.virtual_network.name
  address_prefixes                              = var.address_prefixes
  default_outbound_access_enabled               = var.default_outbound_access_enabled
  private_endpoint_network_policies             = var.name == "GatewaySubnet" ? "Disabled" : var.private_endpoint_network_policies
  private_link_service_network_policies_enabled = var.private_link_service_network_policies_enabled

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

  dynamic "service_endpoint" {
    for_each = var.service_endpoints != null ? var.service_endpoints : []

    content {
      service = service_endpoint.value
    }
  }
}

locals {
  # Both objects are set or not, whatever their contents, so this is known at plan time. An existing group
  # takes the place of a created one, and GatewaySubnet has none.
  create_nsg = var.network_security_group != null && var.existing_network_security_group == null && var.name != "GatewaySubnet"
}

# The group and its rules live in ./modules/nsg so the root module's shared group gets the same
# default rules from the same place.
module "nsg" {
  source = "../nsg"
  count  = local.create_nsg ? 1 : 0

  name                = coalesce(var.network_security_group.name, lower("${var.virtual_network.name}-${var.name}-nsg"))
  location            = var.virtual_network.location
  resource_group_name = var.resource_group_name
  tags                = var.tags

  subnet_name           = var.name
  security_rules        = var.network_security_group.security_rules
  include_default_rules = var.network_security_group.include_default_rules

  default_rules                    = var.default_rules
  azure_bastion_security_rules     = var.azure_bastion_security_rules
  azure_bastion_source_ip_prefixes = var.azure_bastion_source_ip_prefixes
}

locals {
  # The created group's id only exists once its rules do, so attaching it never exposes a group
  # carrying just Azure's defaults.
  nsg_id = local.create_nsg ? module.nsg[0].id : (var.existing_network_security_group == null ? null : var.existing_network_security_group.id)
}

resource "azurerm_subnet_network_security_group_association" "this" {
  # Whether there is a group is told by an object being set, and not by an id: the id of a group created
  # in the same apply is unknown at plan time, and a count cannot depend on that.
  count = local.create_nsg || var.existing_network_security_group != null ? 1 : 0

  subnet_id                 = azurerm_subnet.this.id
  network_security_group_id = local.nsg_id
}

resource "azurerm_subnet_route_table_association" "this" {
  count = var.route_table_id != null ? 1 : 0

  subnet_id      = azurerm_subnet.this.id
  route_table_id = var.route_table_id

  # Caught at plan time because Azure answers 400 for this at apply, after any sibling association
  # has already been created.
  lifecycle {
    precondition {
      condition     = var.name != "AzureBastionSubnet"
      error_message = "Azure rejects a route table on AzureBastionSubnet with RouteTableCannotBeAttachedForAzureBastionSubnet. Remove route_table_id for this subnet."
    }
  }
}

