locals {
  # Rules are keyed by name. When two rules have the same name, the one from the set with the higher
  # precedence replaces the other. Precedence, highest first: security_rules, default_rules, Bastion rules.
  # Bastion's Internet rule gets azure_bastion_source_ip_prefixes before the merge. A rule with the same
  # name from a higher set replaces it, so that rule then wins the precedence.
  bastion_rules = {
    for name, rule in var.azure_bastion_security_rules : name => (
      name == "Allow-Https-in-from-Internet" ? merge(rule, {
        source_address_prefixes = var.azure_bastion_source_ip_prefixes
      }) : rule
    )
  }

  rules = merge(
    var.subnet_name == "AzureBastionSubnet" ? local.bastion_rules : {},
    var.include_default_rules ? var.default_rules : {},
    var.security_rules,
  )
}

resource "azurerm_network_security_group" "this" {
  name                = var.name
  location            = var.location
  resource_group_name = var.resource_group_name

  tags = var.tags
}

# Standalone rules rather than inline `security_rule` blocks, which cannot coexist with these and
# would rewrite the group's whole rule list on every change.
resource "azurerm_network_security_rule" "this" {
  for_each = local.rules

  name                        = each.key
  network_security_group_name = azurerm_network_security_group.this.name
  resource_group_name         = azurerm_network_security_group.this.resource_group_name

  priority    = each.value.priority
  direction   = each.value.direction
  access      = each.value.access
  protocol    = each.value.protocol
  description = each.value.description

  # Rules take lists only. Azure accepts `*` and tags such as VirtualNetwork in the singular argument
  # alone, and several entries in the plural one alone, so one entry goes to the first and more to the second.
  source_port_range       = length(each.value.source_port_ranges) == 1 ? one(each.value.source_port_ranges) : null
  source_port_ranges      = length(each.value.source_port_ranges) > 1 ? each.value.source_port_ranges : null
  destination_port_range  = length(each.value.destination_port_ranges) == 1 ? one(each.value.destination_port_ranges) : null
  destination_port_ranges = length(each.value.destination_port_ranges) > 1 ? each.value.destination_port_ranges : null

  source_address_prefix        = length(each.value.source_address_prefixes) == 1 ? one(each.value.source_address_prefixes) : null
  source_address_prefixes      = length(each.value.source_address_prefixes) > 1 ? each.value.source_address_prefixes : null
  destination_address_prefix   = length(each.value.destination_address_prefixes) == 1 ? one(each.value.destination_address_prefixes) : null
  destination_address_prefixes = length(each.value.destination_address_prefixes) > 1 ? each.value.destination_address_prefixes : null

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
