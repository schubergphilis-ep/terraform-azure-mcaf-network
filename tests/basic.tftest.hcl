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

run "no_nsg_association_creates_nothing" {
  command = plan

  variables {
    subnets = {
      "BareSubnet" = {
        address_prefixes              = ["100.0.5.0/24"]
        create_network_security_group = true
        no_nsg_association            = true
      }
    }
  }

  assert {
    condition     = length(output.all_network_security_groups) == 0
    error_message = "no_nsg_association should leave the subnet with no group at all"
  }
}
