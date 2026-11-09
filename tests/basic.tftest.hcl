mock_provider "azurerm" {}

variables {
  resource_group_name = "example-rsg"

  vnet_name          = "my-vnet"
  vnet_address_space = ["10.0.0.0/8"]

  natgateway = {
    name = "my-nat-gw"
  }

  subnets = {
    "CoreSubnet" = {
      address_prefixes                  = ["100.0.1.0/24"]
      default_outbound_access_enabled   = false
      delegate_to                       = "Microsoft.ContainerInstance/containerGroups"
      private_endpoint_network_policies = "NetworkSecurityGroupEnabled"
    }
  }

  private_dns = {
    "keyvault" = {
      zone_name = "privatelink.vaultcore.azure.net"
    }
  }

  location = "eastus"

  tags = {
    Environment = "Production"
  }
}

run "plan" {
  command = plan

  assert {
    condition     = module.nsg.name == "my-vnet-nsg" && contains(module.nsg.rule_names, "Deny-Any-Any-Any-In")
    error_message = "the shared group should be named after the vnet and carry the default rules"
  }

  assert {
    condition     = azurerm_virtual_network.this.name == "my-vnet"
    error_message = "Unexpected virtual network name"
  }

  assert {
    condition     = contains(azurerm_virtual_network.this.address_space, "10.0.0.0/8")
    error_message = "Unexpected virtual network address space"
  }

  # Test assertions cannot address child module resources, so this goes through the output instead.
  assert {
    condition     = output.subnets["CoreSubnet"].name == "CoreSubnet"
    error_message = "Unexpected subnet name"
  }
}

# A virtual network with no subnets at all: subnets defaults to {}, so the
# for_each'd subnet module expands to nothing.
run "vnet_only_no_subnets" {
  command = plan

  variables {
    subnets    = {}
    natgateway = null
  }

  assert {
    condition     = azurerm_virtual_network.this.name == "my-vnet"
    error_message = "the virtual network should still be created"
  }

  assert {
    condition     = length(module.subnet) == 0
    error_message = "no subnet module instances should be created"
  }

  assert {
    condition     = length(output.subnets) == 0
    error_message = "the subnets output should be empty"
  }

  assert {
    condition     = length(output.all_subnets) == 0
    error_message = "the all_subnets output should be empty"
  }
}

# The four branches of local.subnet_network_security_group. None were covered before the per-subnet
# groups moved into the submodule, so a wrong branch would have gone unnoticed.
run "subnet_owned_nsg_is_created" {
  command = plan

  variables {
    subnets = {
      "AppSubnet" = {
        address_prefixes              = ["100.0.2.0/24"]
        create_network_security_group = true
      }
    }
  }

  assert {
    condition     = output.all_network_security_groups["AppSubnet"].name == "my-vnet-appsubnet-nsg"
    error_message = "A subnet asking for its own group should get one named after the vnet and the key"
  }
}

run "azure_default_nsg_is_created" {
  command = plan

  variables {
    subnets = {
      "DefaultedSubnet" = {
        address_prefixes              = ["100.0.3.0/24"]
        create_network_security_group = true
        network_security_group_config = { azure_default = true }
      }
    }
  }

  assert {
    condition     = output.all_network_security_groups["DefaultedSubnet"].name == "my-vnet-defaultedsubnet-nsg"
    error_message = "azure_default still creates a group, only its rule set differs"
  }
}

run "bastion_gets_its_own_nsg" {
  command = plan

  variables {
    subnets = {
      "AzureBastionSubnet" = {
        address_prefixes = ["100.0.4.0/26"]
      }
    }
  }

  assert {
    condition     = output.all_network_security_groups["AzureBastionSubnet"].name == "my-vnet-azurebastionsubnet-nsg"
    error_message = "Bastion needs its own group regardless of create_network_security_group"
  }
}

run "reject_no_nsg_association" {
  command = plan

  variables {
    subnets = {
      "BareSubnet" = {
        address_prefixes   = ["100.0.5.0/24"]
        no_nsg_association = true
      }
    }
  }

  expect_failures = [
    var.subnets,
  ]
}

run "azure_default_false_still_gets_its_own_group" {
  command = plan

  variables {
    subnets = {
      "OwnSubnet" = {
        address_prefixes              = ["100.0.7.0/24"]
        create_network_security_group = true
        network_security_group_config = { azure_default = false }
      }
    }
  }

  assert {
    condition     = output.all_network_security_groups["OwnSubnet"].name == "my-vnet-ownsubnet-nsg"
    error_message = "create_network_security_group means a group of its own, whatever else network_security_group_config says"
  }
}

run "reject_a_network_security_group_on_the_gateway_subnet" {
  command = plan

  variables {
    subnets = {
      "GatewaySubnet" = {
        address_prefixes              = ["100.0.8.0/27"]
        create_network_security_group = true
      }
    }
  }

  expect_failures = [
    var.subnets,
  ]
}

run "bastion_is_recognised_by_name_not_key" {
  command = plan

  variables {
    subnets = {
      "bastion" = {
        name             = "AzureBastionSubnet"
        address_prefixes = ["100.0.4.0/26"]
      }
    }
  }

  assert {
    condition     = output.all_network_security_groups["bastion"].name == "my-vnet-bastion-nsg"
    error_message = "a subnet named AzureBastionSubnet needs Bastion's own group, whatever key it has"
  }
}

run "the_gateway_subnet_is_recognised_by_name_for_the_nat_gateway" {
  command = plan

  variables {
    subnets = {
      "gw" = {
        name             = "GatewaySubnet"
        address_prefixes = ["100.0.8.0/27"]
      }
      "core" = {
        address_prefixes = ["100.0.1.0/24"]
      }
    }
  }

  assert {
    condition     = keys(azurerm_subnet_nat_gateway_association.this) == ["core"]
    error_message = "a NAT gateway attaches to every subnet but the one named GatewaySubnet"
  }
}

run "a_supplied_public_ip_id_creates_no_public_ip" {
  command = plan

  variables {
    natgateway = {
      name                 = "my-nat-gw"
      public_ip_address_id = "/subscriptions/0000/resourceGroups/rg/providers/Microsoft.Network/publicIPAddresses/mine"
    }
  }

  assert {
    condition     = length(azurerm_public_ip.this) == 0
    error_message = "the public IP passed in is the one used, so none should be created beside it"
  }
}

run "a_zone_without_a_link_is_still_created" {
  command = plan

  variables {
    private_dns = {
      "kv"   = { zone_name = "privatelink.vaultcore.azure.net", zone_link_enabled = false }
      "blob" = { zone_name = "privatelink.blob.core.windows.net" }
    }
  }

  assert {
    condition     = length(azurerm_private_dns_zone.this) == 2 && keys(azurerm_private_dns_zone_virtual_network_link.this) == ["blob"]
    error_message = "zone_link_enabled = false should skip only the link"
  }
}
