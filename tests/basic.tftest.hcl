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

  # Subnets moved into ./modules/subnet. Test assertions cannot address child
  # module resources, so this goes through the output instead.
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
