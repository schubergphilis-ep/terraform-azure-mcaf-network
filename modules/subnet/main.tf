resource "azurerm_subnet" "this" {
  name                                          = var.name
  resource_group_name                           = var.resource_group_name
  virtual_network_name                          = var.virtual_network_name
  address_prefixes                              = var.address_prefixes
  default_outbound_access_enabled               = var.default_outbound_access_enabled
  private_endpoint_network_policies             = var.private_endpoint_network_policies
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
  # No id means the caller wants this module to own the group rather than associate an existing one.
  nsg_create    = var.network_security_group == null ? false : var.network_security_group.id == null
  nsg_associate = var.network_security_group == null ? false : var.network_security_group.associate

  nsg_resource_group_name = (
    var.network_security_group == null || var.network_security_group.resource_group_name == null
    ? var.resource_group_name
    : var.network_security_group.resource_group_name
  )

  nsg_id = (
    local.nsg_create
    ? module.nsg[0].id
    : var.network_security_group == null ? null : var.network_security_group.id
  )
}

# The group and its rules live in ./modules/nsg so the root module's shared group gets the same
# default rules from the same place.
module "nsg" {
  source = "../nsg"
  count  = local.nsg_create ? 1 : 0

  name                = var.network_security_group.name
  location            = var.location
  resource_group_name = local.nsg_resource_group_name
  tags                = var.tags

  security_rules        = var.network_security_group.security_rules
  include_default_rules = var.network_security_group.include_default_rules
  # A Bastion subnet must be named exactly this, so the name is a safe default for a direct caller.
  azure_bastion = coalesce(var.network_security_group.azure_bastion, var.name == "AzureBastionSubnet")

  default_rules                    = var.default_rules
  azure_bastion_security_rules     = var.azure_bastion_security_rules
  azure_bastion_source_ip_prefixes = var.azure_bastion_source_ip_prefixes
}

resource "azurerm_subnet_network_security_group_association" "this" {
  count = local.nsg_associate ? 1 : 0

  subnet_id                 = azurerm_subnet.this.id
  network_security_group_id = local.nsg_id

  # Rules before the attach, or the group is briefly associated carrying only Azure's defaults —
  # which drops whatever the rules were meant to permit while an apply is still running.
  depends_on = [module.nsg]
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

