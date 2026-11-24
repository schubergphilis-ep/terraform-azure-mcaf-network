locals {
  # Azure decides by name what a subnet is, and the name defaults to the key.
  subnet_names = { for k, v in var.subnets : k => coalesce(v.name, k) }

  # Subnet selections. A GatewaySubnet cannot ask for a group of its own: variables.tf rejects it.
  default_subnets = {
    for k, v in var.subnets :
    k => v if(
      !v.create_network_security_group &&
      !v.no_nsg_association &&
      !contains(["AzureBastionSubnet", "GatewaySubnet"], local.subnet_names[k])
    )
  }
  azure_bastion_subnet = { for k, v in var.subnets : k => v if local.subnet_names[k] == "AzureBastionSubnet" }

  subnets_with_nsg = {
    for k, v in var.subnets :
    k => v if(
      v.create_network_security_group &&
      !try(v.network_security_group_config.azure_default, false) &&
      local.subnet_names[k] != "AzureBastionSubnet"
    )
  }

  subnets_with_nsg_azure_default = {
    for k, v in var.subnets :
    k => v if(
      v.create_network_security_group &&
      try(v.network_security_group_config.azure_default, false) &&
      local.subnet_names[k] != "AzureBastionSubnet"
    )
  }

  # A subnet has one group, or none: no_nsg_association and GatewaySubnet. The module either creates
  # the group (below) or is given one that exists (further below). Which rules a created group carries
  # is ./modules/nsg's business.
  subnet_network_security_group = {
    for key, subnet in var.subnets : key => (
      subnet.no_nsg_association ? null :
      contains(keys(local.azure_bastion_subnet), key) ? {
        name                  = lower("${var.vnet_name}-${key}-nsg")
        include_default_rules = true
        security_rules        = var.security_rules
      } :
      contains(keys(local.subnets_with_nsg_azure_default), key) ? {
        name                  = lower("${var.vnet_name}-${key}-nsg")
        include_default_rules = false
        security_rules        = var.security_rules
      } :
      contains(keys(local.subnets_with_nsg), key) ? {
        name                  = lower("${var.vnet_name}-${key}-nsg")
        include_default_rules = true
        security_rules        = var.security_rules
      } :
      null
    )
  }

  # The shared group, or an existing one, for the subnets that do not create their own.
  subnet_existing_network_security_group = {
    for key, subnet in var.subnets : key => (
      contains(keys(local.default_subnets), key) ? {
        id = coalesce(subnet.network_security_group_id, one(module.nsg[*].id))
      } : null
    )
  }
}
