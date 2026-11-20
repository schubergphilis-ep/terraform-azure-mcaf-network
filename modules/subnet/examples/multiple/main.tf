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

# A network security group that exists already and is shared by most of the subnets below.
resource "azurerm_network_security_group" "shared" {
  name                = "my-vnet-nsg"
  location            = "westeurope"
  resource_group_name = "example-rsg"
}

locals {
  subnets = {
    # Own group, with the default rules.
    "AppSubnet" = { address_prefixes = ["10.0.1.0/24"], group = { name = "my-vnet-appsubnet-nsg", location = "westeurope" } }

    # The shared group.
    "DataSubnet" = { address_prefixes = ["10.0.2.0/24"], service_endpoints = ["Microsoft.Sql"], group = { id = azurerm_network_security_group.shared.id } }
    "AciSubnet"  = { address_prefixes = ["10.0.3.0/24"], delegate_to = "Microsoft.ContainerInstance/containerGroups", group = { id = azurerm_network_security_group.shared.id } }

    # Named like this, it gets Azure Bastion's rules on top of the defaults.
    "AzureBastionSubnet" = { address_prefixes = ["10.0.4.0/26"], group = { name = "my-vnet-azurebastionsubnet-nsg", location = "westeurope" } }

    # No group. GatewaySubnet has to go without, because Azure does not support one there, and any
    # other subnet can too.
    "GatewaySubnet" = { address_prefixes = ["10.0.5.0/27"] }
    "ScratchSubnet" = { address_prefixes = ["10.0.6.0/24"] }
  }
}

module "subnet" {
  source   = "../.."
  for_each = local.subnets

  name                 = each.key
  resource_group_name  = "example-rsg"
  virtual_network_name = "my-vnet"
  address_prefixes     = each.value.address_prefixes
  delegate_to          = try(each.value.delegate_to, null)
  service_endpoints    = try(each.value.service_endpoints, null)

  # A group to create (name, location), the id of one that exists, or null for none. lookup() and not
  # try(): try() turns a group whose id is only known after apply into an unknown value as a whole.
  network_security_group = lookup(each.value, "group", null)
}

output "subnet_ids" {
  description = "The ID of each subnet, by name."
  value       = { for name, subnet in module.subnet : name => subnet.id }
}
