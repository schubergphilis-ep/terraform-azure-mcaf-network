locals {
  # Azure decides by name what a subnet is, and the name defaults to the key.
  subnet_names = { for k, v in var.subnets : k => coalesce(v.name, k) }

  # Subnet selections. A GatewaySubnet cannot ask for a group of its own: variables.tf rejects it.
  default_subnets = {
    for k, v in var.subnets :
    k => v if(
      !v.create_network_security_group &&
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

  # What each subnet's group should be. Every branch carries the same attributes because Terraform
  # rejects a conditional whose branches differ in shape; a name means "create one", an id means
  # "associate this", null means neither. no_nsg_association skips only the association: the groups
  # below are created either way. Which rules a created group gets is ./modules/nsg's business.
  subnet_network_security_group = {
    for key, subnet in var.subnets : key => (
      contains(keys(local.azure_bastion_subnet), key) ? {
        id                    = null
        name                  = lower("${var.vnet_name}-${key}-nsg")
        associate             = !subnet.no_nsg_association
        include_default_rules = true
        azure_bastion         = true
        security_rules        = var.security_rules
      } :
      # Always associated: azure_default never honoured no_nsg_association.
      contains(keys(local.subnets_with_nsg_azure_default), key) ? {
        id                    = null
        name                  = lower("${var.vnet_name}-${key}-nsg")
        associate             = true
        include_default_rules = false
        azure_bastion         = false
        security_rules        = var.security_rules
      } :
      contains(keys(local.subnets_with_nsg), key) ? {
        id                    = null
        name                  = lower("${var.vnet_name}-${key}-nsg")
        associate             = !subnet.no_nsg_association
        include_default_rules = true
        azure_bastion         = false
        security_rules        = var.security_rules
      } :
      # The shared group is only ever associated, so there is nothing to keep without association.
      contains(keys(local.default_subnets), key) && !subnet.no_nsg_association ? {
        id                    = coalesce(subnet.network_security_group_id, module.nsg.id)
        name                  = null
        associate             = true
        include_default_rules = true
        azure_bastion         = false
        security_rules        = null
      } :
      null
    )
  }
}
