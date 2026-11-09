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
    "AppSubnet" = { address_prefixes = ["10.0.1.0/24"], own_group = true }

    # The shared group.
    "DataSubnet" = { address_prefixes = ["10.0.2.0/24"], service_endpoints = ["Microsoft.Sql"] }
    "AciSubnet"  = { address_prefixes = ["10.0.3.0/24"], delegate_to = "Microsoft.ContainerInstance/containerGroups" }

    # Named like this, it gets Azure Bastion's rules on top of the defaults.
    "AzureBastionSubnet" = { address_prefixes = ["10.0.4.0/26"], own_group = true }

    # Azure does not support a group here, so this is the one subnet that takes neither.
    "GatewaySubnet" = { address_prefixes = ["10.0.5.0/27"], no_group = true }
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

  location = "westeurope"

  # Give it a group to create, or the id of one that exists. Exactly one, unless it is GatewaySubnet.
  network_security_group    = try(each.value.own_group, false) ? { name = lower("my-vnet-${each.key}-nsg") } : null
  network_security_group_id = try(each.value.own_group, false) || try(each.value.no_group, false) ? null : azurerm_network_security_group.shared.id
}

output "subnet_ids" {
  description = "The ID of each subnet, by name."
  value       = { for name, subnet in module.subnet : name => subnet.id }
}
