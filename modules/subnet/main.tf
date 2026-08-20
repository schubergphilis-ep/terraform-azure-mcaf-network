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

locals {
  # No id means the caller wants this module to own the group rather than associate an existing one.
  nsg_create = var.network_security_group == null ? false : var.network_security_group.id == null

  # Only ever rules on a group created here, so no instance of this module can write into a group
  # another instance also writes into.
  nsg_rules = local.nsg_create ? var.network_security_group.rules : {}

  nsg_resource_group_name = (
    var.network_security_group == null || var.network_security_group.resource_group_name == null
    ? var.resource_group_name
    : var.network_security_group.resource_group_name
  )

  nsg_id = (
    local.nsg_create
    ? azurerm_network_security_group.this[0].id
    : var.network_security_group == null ? null : var.network_security_group.id
  )
}

resource "azurerm_network_security_group" "this" {
  count = local.nsg_create ? 1 : 0

  name                = var.network_security_group.name
  resource_group_name = local.nsg_resource_group_name
  location            = var.location
  tags                = var.tags

  lifecycle {
    precondition {
      condition     = var.location != null
      error_message = "location is required when this module creates the network security group."
    }
  }
}

# Standalone rules rather than inline `security_rule` blocks, which cannot coexist with these and
# would rewrite the group's whole rule list on every change.
resource "azurerm_network_security_rule" "this" {
  for_each = local.nsg_rules

  name                        = each.key
  network_security_group_name = azurerm_network_security_group.this[0].name
  resource_group_name         = azurerm_network_security_group.this[0].resource_group_name

  priority    = each.value.priority
  direction   = each.value.direction
  access      = each.value.access
  protocol    = each.value.protocol
  description = each.value.description

  source_port_range       = each.value.source_port_range
  source_port_ranges      = each.value.source_port_ranges
  destination_port_range  = each.value.destination_port_range
  destination_port_ranges = each.value.destination_port_ranges

  source_address_prefix        = each.value.source_address_prefix
  source_address_prefixes      = each.value.source_address_prefixes
  destination_address_prefix   = each.value.destination_address_prefix
  destination_address_prefixes = each.value.destination_address_prefixes

  source_application_security_group_ids      = each.value.source_application_security_group_ids
  destination_application_security_group_ids = each.value.destination_application_security_group_ids

  dynamic "timeouts" {
    for_each = each.value.timeouts == null ? [] : [each.value.timeouts]

    content {
      create = timeouts.value.create
      delete = timeouts.value.delete
      read   = timeouts.value.read
      update = timeouts.value.update
    }
  }
}

resource "azurerm_subnet_network_security_group_association" "this" {
  count = var.network_security_group != null ? 1 : 0

  subnet_id                 = azurerm_subnet.this.id
  network_security_group_id = local.nsg_id

  # Rules before the attach, or the group is briefly associated carrying only Azure's defaults —
  # which drops whatever the rules were meant to permit while an apply is still running.
  depends_on = [azurerm_network_security_rule.this]
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

