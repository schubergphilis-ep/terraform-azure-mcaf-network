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

# One subnet in a virtual network that is managed elsewhere, with a network security group of its
# own: the default rules, plus one of ours.
module "subnet" {
  source = "../.."

  name                 = "AppSubnet"
  resource_group_name  = "example-rsg"
  virtual_network_name = "my-vnet"
  address_prefixes     = ["10.0.1.0/24"]

  location = "westeurope"

  tags = {
    Environment = "Production"
  }

  network_security_group = {
    name = "my-vnet-appsubnet-nsg"

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
}
