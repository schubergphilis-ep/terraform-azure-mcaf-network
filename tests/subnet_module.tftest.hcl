# Tests for ./modules/subnet exercised directly, not through the root module.
#
# These live here rather than under modules/subnet/tests/ because CI runs a bare
# `terraform test` at the repository root; a test directory inside the submodule
# would never execute. The `module` block in each run points the run at the
# submodule, so the assertions still cover its own interface.

mock_provider "azurerm" {}

variables {
  resource_group_name  = "rg-platform-network"
  virtual_network_name = "vnet-platform"
}

run "name_defaults_to_the_map_key" {
  command = plan

  module {
    source = "./modules/subnet"
  }

  variables {
    subnets = {
      "NodeSubnet" = {
        address_prefixes = ["100.0.1.0/24"]
      }
    }
  }

  assert {
    condition     = azurerm_subnet.this["NodeSubnet"].name == "NodeSubnet"
    error_message = "name should fall back to the map key"
  }

  assert {
    condition     = azurerm_subnet.this["NodeSubnet"].virtual_network_name == "vnet-platform"
    error_message = "the subnet should be created in the virtual network passed in"
  }

  assert {
    condition     = azurerm_subnet.this["NodeSubnet"].resource_group_name == "rg-platform-network"
    error_message = "the subnet should be created in the resource group passed in"
  }

  # Defaults that the root module used to apply inline.
  assert {
    condition     = azurerm_subnet.this["NodeSubnet"].private_endpoint_network_policies == "Disabled"
    error_message = "private_endpoint_network_policies should default to Disabled"
  }

  assert {
    condition     = azurerm_subnet.this["NodeSubnet"].private_link_service_network_policies_enabled == true
    error_message = "private_link_service_network_policies_enabled should default to true"
  }

  assert {
    condition     = azurerm_subnet.this["NodeSubnet"].default_outbound_access_enabled == false
    error_message = "default_outbound_access_enabled should default to false"
  }
}

run "explicit_name_overrides_the_map_key" {
  command = plan

  module {
    source = "./modules/subnet"
  }

  variables {
    subnets = {
      "nodes" = {
        name             = "snet-nodes-prod"
        address_prefixes = ["100.0.1.0/24"]
      }
    }
  }

  assert {
    condition     = azurerm_subnet.this["nodes"].name == "snet-nodes-prod"
    error_message = "an explicit name should win over the map key"
  }
}

# route_table is opt-in at the root module, but the submodule always honours it.
run "route_table_creates_an_association" {
  command = plan

  module {
    source = "./modules/subnet"
  }

  variables {
    subnets = {
      "RoutedSubnet" = {
        address_prefixes = ["100.0.2.0/24"]
        route_table = {
          id = "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/rg-platform-network/providers/Microsoft.Network/routeTables/rt-egress"
        }
      }
      "PlainSubnet" = {
        address_prefixes = ["100.0.3.0/24"]
      }
    }
  }

  assert {
    condition     = length(azurerm_subnet_route_table_association.this) == 1
    error_message = "only the subnet that sets route_table should get an association"
  }

  assert {
    condition     = contains(keys(azurerm_subnet_route_table_association.this), "RoutedSubnet")
    error_message = "the association should be keyed by the subnets input key"
  }

  assert {
    condition     = azurerm_subnet_route_table_association.this["RoutedSubnet"].route_table_id == "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/rg-platform-network/providers/Microsoft.Network/routeTables/rt-egress"
    error_message = "the association should point at the route table passed in"
  }
}

run "no_associations_without_route_table" {
  command = plan

  module {
    source = "./modules/subnet"
  }

  variables {
    subnets = {
      "PlainSubnet" = {
        address_prefixes = ["100.0.3.0/24"]
      }
    }
  }

  assert {
    condition     = length(azurerm_subnet_route_table_association.this) == 0
    error_message = "no association should be created when route_table is unset"
  }
}

# delegate_to resolves its actions from subnet_delegations_actions unless
# delegate_to_actions is given explicitly.
run "delegation_actions_come_from_the_lookup_table" {
  command = plan

  module {
    source = "./modules/subnet"
  }

  variables {
    subnets = {
      "AciSubnet" = {
        address_prefixes = ["100.0.4.0/24"]
        delegate_to      = "Microsoft.ContainerInstance/containerGroups"
      }
    }
  }

  assert {
    condition     = azurerm_subnet.this["AciSubnet"].delegation[0].name == "containerGroups"
    error_message = "the delegation name should be the second segment of delegate_to"
  }

  assert {
    condition     = azurerm_subnet.this["AciSubnet"].delegation[0].service_delegation[0].name == "Microsoft.ContainerInstance/containerGroups"
    error_message = "service_delegation name should be delegate_to"
  }

  assert {
    condition     = azurerm_subnet.this["AciSubnet"].delegation[0].service_delegation[0].actions == toset(["Microsoft.Network/virtualNetworks/subnets/action"])
    error_message = "actions should be looked up from subnet_delegations_actions"
  }
}

run "explicit_delegation_actions_win" {
  command = plan

  module {
    source = "./modules/subnet"
  }

  variables {
    subnets = {
      "DbSubnet" = {
        address_prefixes    = ["100.0.5.0/24"]
        delegate_to         = "Microsoft.DBforPostgreSQL/flexibleServers"
        delegate_to_actions = ["Microsoft.Network/virtualNetworks/subnets/join/action"]
      }
    }
  }

  assert {
    condition     = azurerm_subnet.this["DbSubnet"].delegation[0].service_delegation[0].actions == toset(["Microsoft.Network/virtualNetworks/subnets/join/action"])
    error_message = "delegate_to_actions should override the lookup table"
  }
}

run "no_delegation_block_by_default" {
  command = plan

  module {
    source = "./modules/subnet"
  }

  variables {
    subnets = {
      "PlainSubnet" = {
        address_prefixes = ["100.0.6.0/24"]
      }
    }
  }

  assert {
    condition     = length(azurerm_subnet.this["PlainSubnet"].delegation) == 0
    error_message = "no delegation block should be emitted when delegate_to is unset"
  }
}

run "service_endpoints_are_passed_through" {
  command = plan

  module {
    source = "./modules/subnet"
  }

  variables {
    subnets = {
      "StorageSubnet" = {
        address_prefixes  = ["100.0.7.0/24"]
        service_endpoints = ["Microsoft.Storage", "Microsoft.KeyVault"]
      }
    }
  }

  assert {
    condition     = azurerm_subnet.this["StorageSubnet"].service_endpoints == toset(["Microsoft.Storage", "Microsoft.KeyVault"])
    error_message = "service_endpoints should reach the subnet"
  }
}

run "several_subnets_are_created_independently" {
  command = plan

  module {
    source = "./modules/subnet"
  }

  variables {
    subnets = {
      "A" = { address_prefixes = ["100.0.8.0/24"] }
      "B" = { address_prefixes = ["100.0.9.0/24"] }
      "C" = { address_prefixes = ["100.0.10.0/24"] }
    }
  }

  assert {
    condition     = length(azurerm_subnet.this) == 3
    error_message = "one subnet should be created per map entry"
  }
}

run "empty_subnets_creates_nothing" {
  command = plan

  module {
    source = "./modules/subnet"
  }

  assert {
    condition     = length(azurerm_subnet.this) == 0
    error_message = "an empty subnets map should create no subnets"
  }
}

run "reject_empty_address_prefixes" {
  command = plan

  module {
    source = "./modules/subnet"
  }

  variables {
    subnets = {
      "BadSubnet" = {
        address_prefixes = []
      }
    }
  }

  expect_failures = [
    var.subnets,
  ]
}
