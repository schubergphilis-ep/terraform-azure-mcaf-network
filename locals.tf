locals {
  # Subnet selections
  default_subnets = {
    for k, v in var.subnets :
    k => v if(
      !v.create_network_security_group &&
      k != "AzureBastionSubnet" &&
      k != "GatewaySubnet"
    )
  }
  azure_bastion_subnet = { for k, v in var.subnets : k => v if k == "AzureBastionSubnet" }

  subnets_with_nsg = {
    for k, v in var.subnets :
    k => v if(
      v.create_network_security_group &&
      v.network_security_group_config == null &&
      k != "AzureBastionSubnet"
    )
  }

  subnets_with_nsg_azure_default = {
    for k, v in var.subnets :
    k => v if(
      v.create_network_security_group &&
      try(v.network_security_group_config.azure_default, false) &&
      k != "AzureBastionSubnet"
    )
  }

  # What each subnet's group should be, now that the submodule owns every per-subnet group. Every
  # branch carries the same attributes because Terraform rejects a conditional whose branches differ
  # in shape; a name means "create one", an id means "associate this", null means neither.
  subnet_network_security_group = {
    for key, subnet in var.subnets : key => (
      # Bastion first, and only when association is wanted: its rule set is its own.
      contains(keys(local.azure_bastion_subnet), key) && !subnet.no_nsg_association ? {
        id    = null
        name  = lower("${var.vnet_name}-${key}-nsg")
        rules = local.nsg_rules_for.azure_bastion
      } :
      # Before no_nsg_association, because the azure_default association never honoured it.
      contains(keys(local.subnets_with_nsg_azure_default), key) ? {
        id    = null
        name  = lower("${var.vnet_name}-${key}-nsg")
        rules = local.nsg_rules_for.azure_default
      } :
      subnet.no_nsg_association ? null :
      contains(keys(local.subnets_with_nsg), key) ? {
        id    = null
        name  = lower("${var.vnet_name}-${key}-nsg")
        rules = local.nsg_rules_for.additional
      } :
      contains(keys(local.default_subnets), key) ? {
        id    = coalesce(subnet.network_security_group_id, azurerm_network_security_group.this.id)
        name  = null
        rules = null
      } :
      null
    )
  }

  ## Security rules
  preprocessed_security_rules = { for key, rule in var.security_rules : rule.name => rule }
  security_rules              = merge(var.default_rules, local.preprocessed_security_rules)
  azure_bastion_rules_map     = merge(var.azure_bastion_security_rules, local.security_rules)

  azure_bastion_security_rules = {
    for rule_key, rule in local.azure_bastion_rules_map : rule_key => rule_key == "Allow-Https-in-from-Internet" ? merge(rule, {
      source_address_prefixes = var.azure_bastion_source_ip_prefixes
    }) : rule
  }

  # One field mapping for all three sets: they only ever differed in which rules fed them. Shaped for
  # the submodule, which keys rules by name and so takes no name attribute.
  nsg_rules_for = {
    for set_name, rules in {
      additional    = local.security_rules
      azure_default = local.preprocessed_security_rules
      azure_bastion = local.azure_bastion_security_rules
      } : set_name => {
      for name, rule in rules : name => {
        priority                                   = rule.priority
        direction                                  = rule.direction
        access                                     = rule.access
        protocol                                   = rule.protocol
        description                                = rule.description
        source_port_range                          = rule.source_port_range
        source_port_ranges                         = rule.source_port_ranges
        destination_port_range                     = rule.destination_port_range
        destination_port_ranges                    = rule.destination_port_ranges
        source_address_prefix                      = rule.source_address_prefix
        source_address_prefixes                    = rule.source_address_prefixes
        destination_address_prefix                 = rule.destination_address_prefix
        destination_address_prefixes               = rule.destination_address_prefixes
        source_application_security_group_ids      = rule.source_application_security_group_ids
        destination_application_security_group_ids = rule.destination_application_security_group_ids
        timeouts                                   = rule.timeouts
      }
    }
  }

}

