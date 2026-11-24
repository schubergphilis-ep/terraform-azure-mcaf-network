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
    # Own group, with the default rules. That is what a subnet gets when it says nothing.
    "AppSubnet" = { address_prefixes = ["10.0.1.0/24"] }

    # The shared group.
    "DataSubnet" = { address_prefixes = ["10.0.2.0/24"], service_endpoints = ["Microsoft.Sql"], existing_network_security_group = azurerm_network_security_group.shared }
    "AciSubnet"  = { address_prefixes = ["10.0.3.0/24"], delegate_to = "Microsoft.ContainerInstance/containerGroups", existing_network_security_group = azurerm_network_security_group.shared }

    # Named like this, it gets Azure Bastion's rules on top of the defaults.
    "AzureBastionSubnet" = { address_prefixes = ["10.0.4.0/26"] }

    # Azure does not support a group here, so it gets none whatever it says.
    "GatewaySubnet" = { address_prefixes = ["10.0.5.0/27"] }

    # No group, by asking for null.
    "ScratchSubnet" = { address_prefixes = ["10.0.6.0/24"], network_security_group = null }
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

  # Both arguments are looked up with a default because a module call in a for_each cannot leave one out;
  # {} is the module's own default. lookup() and not try() for the existing group: try() turns a value
  # that holds something only known after apply into an unknown value as a whole, and then whether a
  # group is given is unknown too.
  network_security_group          = lookup(each.value, "network_security_group", {})
  existing_network_security_group = lookup(each.value, "existing_network_security_group", null)
}

output "subnet_ids" {
  description = "The ID of each subnet, by name."
  value       = { for name, subnet in module.subnet : name => subnet.id }
}
