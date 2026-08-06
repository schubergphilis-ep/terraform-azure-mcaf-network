# Tests for ./modules/subnet exercised directly. These live here rather than
# under modules/subnet/tests/ because CI runs a bare `terraform test` at the
# repository root.

mock_provider "azurerm" {}

variables {
  resource_group_name  = "rg-platform-network"
  virtual_network_name = "vnet-platform"
}

run "creates_one_subnet_with_defaults" {
  command = plan

  module {
    source = "./modules/subnet"
  }

  variables {
    name             = "NodeSubnet"
    address_prefixes = ["100.0.1.0/24"]
  }

  assert {
    condition     = azurerm_subnet.this.name == "NodeSubnet"
    error_message = "name should come from var.name"
  }

  assert {
    condition     = azurerm_subnet.this.virtual_network_name == "vnet-platform"
    error_message = "the subnet should be created in the virtual network passed in"
  }

  assert {
    condition     = azurerm_subnet.this.resource_group_name == "rg-platform-network"
    error_message = "the subnet should be created in the resource group passed in"
  }

  assert {
    condition     = azurerm_subnet.this.private_endpoint_network_policies == "Disabled"
    error_message = "private_endpoint_network_policies should default to Disabled"
  }

  assert {
    condition     = azurerm_subnet.this.private_link_service_network_policies_enabled == true
    error_message = "private_link_service_network_policies_enabled should default to true"
  }

  assert {
    condition     = azurerm_subnet.this.default_outbound_access_enabled == false
    error_message = "default_outbound_access_enabled should default to false"
  }

  assert {
    condition     = length(azurerm_subnet.this.delegation) == 0
    error_message = "no delegation block should be emitted when delegate_to is unset"
  }
}

run "delegation_actions_come_from_the_lookup_table" {
  command = plan

  module {
    source = "./modules/subnet"
  }

  variables {
    name             = "AciSubnet"
    address_prefixes = ["100.0.4.0/24"]
    delegate_to      = "Microsoft.ContainerInstance/containerGroups"
  }

  assert {
    condition     = azurerm_subnet.this.delegation[0].name == "containerGroups"
    error_message = "the delegation name should be the second segment of delegate_to"
  }

  assert {
    condition     = azurerm_subnet.this.delegation[0].service_delegation[0].name == "Microsoft.ContainerInstance/containerGroups"
    error_message = "service_delegation name should be delegate_to"
  }

  assert {
    condition     = azurerm_subnet.this.delegation[0].service_delegation[0].actions == toset(["Microsoft.Network/virtualNetworks/subnets/action"])
    error_message = "actions should be looked up from subnet_delegations_actions"
  }
}

run "explicit_delegation_actions_win" {
  command = plan

  module {
    source = "./modules/subnet"
  }

  variables {
    name                = "DbSubnet"
    address_prefixes    = ["100.0.5.0/24"]
    delegate_to         = "Microsoft.DBforPostgreSQL/flexibleServers"
    delegate_to_actions = ["Microsoft.Network/virtualNetworks/subnets/join/action"]
  }

  assert {
    condition     = azurerm_subnet.this.delegation[0].service_delegation[0].actions == toset(["Microsoft.Network/virtualNetworks/subnets/join/action"])
    error_message = "delegate_to_actions should override the lookup table"
  }
}

run "service_endpoints_are_passed_through" {
  command = plan

  module {
    source = "./modules/subnet"
  }

  variables {
    name              = "StorageSubnet"
    address_prefixes  = ["100.0.7.0/24"]
    service_endpoints = ["Microsoft.Storage", "Microsoft.KeyVault"]
  }

  assert {
    condition     = azurerm_subnet.this.service_endpoints == toset(["Microsoft.Storage", "Microsoft.KeyVault"])
    error_message = "service_endpoints should reach the subnet"
  }
}

run "reject_empty_address_prefixes" {
  command = plan

  module {
    source = "./modules/subnet"
  }

  variables {
    name             = "BadSubnet"
    address_prefixes = []
  }

  expect_failures = [
    var.address_prefixes,
  ]
}
