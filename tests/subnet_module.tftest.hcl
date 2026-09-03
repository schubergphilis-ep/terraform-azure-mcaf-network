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

run "an_nsg_id_is_associated_and_nothing_is_created" {
  command = plan

  module {
    source = "./modules/subnet"
  }

  variables {
    name             = "NodeSubnet"
    address_prefixes = ["100.0.1.0/24"]
    network_security_group = {
      id = "/subscriptions/0000/resourceGroups/rg-platform-network/providers/Microsoft.Network/networkSecurityGroups/vnet-platform-nsg"
    }
  }

  assert {
    condition     = length(azurerm_network_security_group.this) == 0
    error_message = "an id means the group is owned elsewhere, so none should be created"
  }

  assert {
    condition     = length(azurerm_network_security_rule.this) == 0
    error_message = "no rules should be created against a group owned elsewhere"
  }

  assert {
    condition     = length(azurerm_subnet_network_security_group_association.this) == 1
    error_message = "the passed group should still be associated with the subnet"
  }
}

run "a_named_nsg_is_created_with_its_rules" {
  command = plan

  module {
    source = "./modules/subnet"
  }

  variables {
    name             = "NodeSubnet"
    address_prefixes = ["100.0.1.0/24"]
    location         = "westeurope"
    network_security_group = {
      name = "node-subnet-nsg"
      rules = {
        allow-gateway-in = {
          priority                   = 100
          direction                  = "Inbound"
          access                     = "Allow"
          protocol                   = "Tcp"
          source_address_prefix      = "10.233.4.224/27"
          source_port_range          = "*"
          destination_address_prefix = "*"
          destination_port_range     = "443"
        }
      }
    }
  }

  assert {
    condition     = azurerm_network_security_group.this[0].name == "node-subnet-nsg"
    error_message = "the group should be created under the name given"
  }

  assert {
    condition     = azurerm_network_security_group.this[0].resource_group_name == "rg-platform-network"
    error_message = "the group should default to the subnet's resource group"
  }

  assert {
    condition     = azurerm_network_security_rule.this["allow-gateway-in"].priority == 100
    error_message = "the rule key should become a rule on the created group"
  }

  assert {
    condition     = length(azurerm_subnet_network_security_group_association.this) == 1
    error_message = "a created group should be associated with the subnet"
  }
}

run "reject_rules_alongside_an_nsg_id" {
  command = plan

  module {
    source = "./modules/subnet"
  }

  variables {
    name             = "NodeSubnet"
    address_prefixes = ["100.0.1.0/24"]
    network_security_group = {
      id = "/subscriptions/0000/resourceGroups/rg/providers/Microsoft.Network/networkSecurityGroups/existing"
      rules = {
        allow-in = { priority = 100, direction = "Inbound", access = "Allow", protocol = "Tcp" }
      }
    }
  }

  expect_failures = [
    var.network_security_group,
  ]
}

run "a_route_table_id_is_associated" {
  command = plan

  module {
    source = "./modules/subnet"
  }

  variables {
    name             = "NodeSubnet"
    address_prefixes = ["100.0.1.0/24"]
    route_table_id   = "/subscriptions/0000/resourceGroups/rg/providers/Microsoft.Network/routeTables/spoke-rt"
  }

  assert {
    condition     = length(azurerm_subnet_route_table_association.this) == 1
    error_message = "a route table id should produce an association"
  }
}

run "reject_a_route_table_on_the_bastion_subnet" {
  command = plan

  module {
    source = "./modules/subnet"
  }

  variables {
    name             = "AzureBastionSubnet"
    address_prefixes = ["100.0.5.0/24"]
    route_table_id   = "/subscriptions/0000/resourceGroups/rg/providers/Microsoft.Network/routeTables/spoke-rt"
  }

  expect_failures = [
    azurerm_subnet_route_table_association.this,
  ]
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
