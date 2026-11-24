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

# The virtual network and a network security group that both exist already. A resource or data source
# is passed to the module as it is.
data "azurerm_virtual_network" "this" {
  name                = "my-vnet"
  resource_group_name = "example-rsg"
}

resource "azurerm_network_security_group" "shared" {
  name                = "my-vnet-nsg"
  location            = "westeurope"
  resource_group_name = "example-rsg"
}

locals {
  subnets = {
    # Own group, with the default rules.
    "AppSubnet" = { address_prefixes = ["10.0.1.0/24"], network_security_group = {} }

    # The shared group.
    "DataSubnet" = { address_prefixes = ["10.0.2.0/24"], service_endpoints = ["Microsoft.Sql"], existing_network_security_group = azurerm_network_security_group.shared }
    "AciSubnet"  = { address_prefixes = ["10.0.3.0/24"], delegate_to = "Microsoft.ContainerInstance/containerGroups", existing_network_security_group = azurerm_network_security_group.shared }

    # Named like this, it gets Azure Bastion's rules on top of the defaults.
    "AzureBastionSubnet" = { address_prefixes = ["10.0.4.0/26"], network_security_group = {} }

    # No group. GatewaySubnet has to go without, because Azure does not support one there, and any
    # other subnet can too.
    "GatewaySubnet" = { address_prefixes = ["10.0.5.0/27"] }
    "ScratchSubnet" = { address_prefixes = ["10.0.6.0/24"] }
  }
}

module "subnet" {
  source   = "../.."
  for_each = local.subnets

  name                = each.key
  resource_group_name = "example-rsg"
  virtual_network     = data.azurerm_virtual_network.this
  address_prefixes    = each.value.address_prefixes
  delegate_to         = try(each.value.delegate_to, null)
  service_endpoints   = try(each.value.service_endpoints, null)

  # A group to create, one that exists, or neither. lookup() and not try(): try() turns a value that
  # holds something only known after apply into an unknown value as a whole, and then whether a group is
  # given is unknown too.
  network_security_group          = lookup(each.value, "network_security_group", null)
  existing_network_security_group = lookup(each.value, "existing_network_security_group", null)
}

output "subnet_ids" {
  description = "The ID of each subnet, by name."
  value       = { for name, subnet in module.subnet : name => subnet.id }
}
