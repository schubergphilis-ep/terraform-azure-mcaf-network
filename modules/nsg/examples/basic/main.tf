terraform {
  required_version = ">= 1.9"

  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 5"
    }
  }
}

provider "azurerm" {
  features {}
}

locals {
  nsgs = {
    # Only the default rules.
    "default" = {}

    # The default rules, plus one of ours. A rule with the name of a default rule replaces it.
    "custom" = {
      security_rules = {
        "Allow-Https-In-From-Office" = {
          priority                     = 200
          direction                    = "Inbound"
          access                       = "Allow"
          protocol                     = "Tcp"
          source_port_ranges           = ["*"]
          destination_port_ranges      = ["443"]
          source_address_prefixes      = ["203.0.113.0/24", "198.51.100.0/24"]
          destination_address_prefixes = ["VirtualNetwork"]
        }
      }
    }

    # Without the default rules: Azure's own, plus the ones given.
    "azure-default" = { include_default_rules = false }

    # For AzureBastionSubnet, so it also gets the rules Azure Bastion needs.
    "bastion" = { subnet_name = "AzureBastionSubnet" }
  }
}

module "nsg" {
  source   = "../.."
  for_each = local.nsgs

  name                = "my-vnet-${each.key}-nsg"
  location            = "westeurope"
  resource_group_name = "example-rsg"

  subnet_name           = try(each.value.subnet_name, null)
  include_default_rules = try(each.value.include_default_rules, true)
  security_rules        = try(each.value.security_rules, {})
}

output "network_security_group_ids" {
  description = "The ID of each group, by key."
  value       = { for key, nsg in module.nsg : key => nsg.id }
}
