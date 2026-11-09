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
    network_security_group_id = "/subscriptions/0000/resourceGroups/rg-platform-network/providers/Microsoft.Network/networkSecurityGroups/vnet-platform-nsg"
    name                      = "NodeSubnet"
    address_prefixes          = ["100.0.1.0/24"]
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
    network_security_group_id = "/subscriptions/0000/resourceGroups/rg-platform-network/providers/Microsoft.Network/networkSecurityGroups/vnet-platform-nsg"
    name                      = "AciSubnet"
    address_prefixes          = ["100.0.4.0/24"]
    delegate_to               = "Microsoft.ContainerInstance/containerGroups"
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

run "network_watchers_delegation_actions_are_found_under_the_dotted_name" {
  command = plan

  module {
    source = "./modules/subnet"
  }

  variables {
    network_security_group_id = "/subscriptions/0000/resourceGroups/rg-platform-network/providers/Microsoft.Network/networkSecurityGroups/vnet-platform-nsg"
    name                      = "WatcherSubnet"
    address_prefixes          = ["100.0.6.0/24"]
    delegate_to               = "Microsoft.Network/networkWatchers."
  }

  assert {
    condition     = azurerm_subnet.this.delegation[0].service_delegation[0].actions == toset(["Microsoft.Network/virtualNetworks/subnets/action"])
    error_message = "azurerm names this delegation with a trailing dot, so the table key must carry it or the actions are never found"
  }
}

run "explicit_delegation_actions_win" {
  command = plan

  module {
    source = "./modules/subnet"
  }

  variables {
    network_security_group_id = "/subscriptions/0000/resourceGroups/rg-platform-network/providers/Microsoft.Network/networkSecurityGroups/vnet-platform-nsg"
    name                      = "DbSubnet"
    address_prefixes          = ["100.0.5.0/24"]
    delegate_to               = "Microsoft.DBforPostgreSQL/flexibleServers"
    delegate_to_actions       = ["Microsoft.Network/virtualNetworks/subnets/join/action"]
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
    network_security_group_id = "/subscriptions/0000/resourceGroups/rg-platform-network/providers/Microsoft.Network/networkSecurityGroups/vnet-platform-nsg"
    name                      = "StorageSubnet"
    address_prefixes          = ["100.0.7.0/24"]
    service_endpoints         = ["Microsoft.Storage", "Microsoft.KeyVault"]
  }

  assert {
    condition     = toset([for e in azurerm_subnet.this.service_endpoint : e.service]) == toset(["Microsoft.Storage", "Microsoft.KeyVault"])
    error_message = "service_endpoints should reach the subnet"
  }
}

run "an_nsg_id_is_associated_and_nothing_is_created" {
  command = plan

  module {
    source = "./modules/subnet"
  }

  variables {
    name                      = "NodeSubnet"
    address_prefixes          = ["100.0.1.0/24"]
    network_security_group_id = "/subscriptions/0000/resourceGroups/rg-platform-network/providers/Microsoft.Network/networkSecurityGroups/vnet-platform-nsg"
  }

  assert {
    condition     = length(module.nsg) == 0
    error_message = "an id means the group is owned elsewhere, so none should be created, and no rules with it"
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
      security_rules = {
        allow-gateway-in = {
          priority                     = 100
          direction                    = "Inbound"
          access                       = "Allow"
          protocol                     = "Tcp"
          source_address_prefixes      = ["10.233.4.224/27"]
          source_port_ranges           = ["*"]
          destination_address_prefixes = ["*"]
          destination_port_ranges      = ["443"]
        }
      }
    }
  }

  assert {
    condition     = module.nsg[0].name == "node-subnet-nsg"
    error_message = "the group should be created under the name given"
  }

  assert {
    condition     = module.nsg[0].resource_group_name == "rg-platform-network"
    error_message = "the group should default to the subnet's resource group"
  }

  assert {
    condition     = contains(module.nsg[0].rule_names, "allow-gateway-in")
    error_message = "the rule key should become a rule on the created group"
  }

  assert {
    condition     = contains(module.nsg[0].rule_names, "Deny-Any-Any-Any-In")
    error_message = "a direct caller should get the same default rules the root module gives its subnets"
  }

  assert {
    condition     = length(azurerm_subnet_network_security_group_association.this) == 1
    error_message = "a created group should be associated with the subnet"
  }
}

run "a_subnet_named_azurebastionsubnet_gets_the_bastion_rules" {
  command = plan

  module {
    source = "./modules/subnet"
  }

  variables {
    name             = "AzureBastionSubnet"
    address_prefixes = ["100.0.4.0/26"]
    location         = "westeurope"
    network_security_group = {
      name = "bastion-nsg"
    }
  }

  assert {
    condition     = contains(module.nsg[0].rule_names, "Allow-Https-in-from-GatewayManager") && contains(module.nsg[0].rule_names, "Deny-Any-Any-Any-In")
    error_message = "the subnet's name is enough to get Bastion's rules, on top of the defaults"
  }
}

run "a_group_can_skip_the_default_rules" {
  command = plan

  module {
    source = "./modules/subnet"
  }

  variables {
    name             = "NodeSubnet"
    address_prefixes = ["100.0.1.0/24"]
    location         = "westeurope"
    network_security_group = {
      name                  = "node-subnet-nsg"
      include_default_rules = false
      security_rules = {
        allow-https = {
          priority                     = 100
          direction                    = "Inbound"
          access                       = "Allow"
          protocol                     = "Tcp"
          source_address_prefixes      = ["*"]
          source_port_ranges           = ["*"]
          destination_address_prefixes = ["*"]
          destination_port_ranges      = ["443"]
        }
      }
    }
  }

  assert {
    condition     = module.nsg[0].rule_names == ["allow-https"]
    error_message = "include_default_rules = false should leave only the rules given"
  }
}

run "reject_a_subnet_without_a_network_security_group" {
  command = plan

  module {
    source = "./modules/subnet"
  }

  variables {
    name             = "NodeSubnet"
    address_prefixes = ["100.0.1.0/24"]
  }

  expect_failures = [
    var.network_security_group_id,
  ]
}

run "reject_both_a_new_and_an_existing_network_security_group" {
  command = plan

  module {
    source = "./modules/subnet"
  }

  variables {
    name                      = "NodeSubnet"
    address_prefixes          = ["100.0.1.0/24"]
    location                  = "westeurope"
    network_security_group    = { name = "node-nsg" }
    network_security_group_id = "/subscriptions/0000/resourceGroups/rg-platform-network/providers/Microsoft.Network/networkSecurityGroups/vnet-platform-nsg"
  }

  expect_failures = [
    var.network_security_group_id,
  ]
}

run "the_gateway_subnet_takes_no_network_security_group" {
  command = plan

  module {
    source = "./modules/subnet"
  }

  variables {
    name             = "GatewaySubnet"
    address_prefixes = ["100.0.8.0/27"]
  }

  assert {
    condition     = length(azurerm_subnet_network_security_group_association.this) == 0 && length(module.nsg) == 0 && output.network_security_group_id == null
    error_message = "GatewaySubnet is the one subnet with no group, created or associated"
  }
}

run "reject_a_network_security_group_on_the_gateway_subnet" {
  command = plan

  module {
    source = "./modules/subnet"
  }

  variables {
    name                      = "GatewaySubnet"
    address_prefixes          = ["100.0.8.0/27"]
    network_security_group_id = "/subscriptions/0000/resourceGroups/rg-platform-network/providers/Microsoft.Network/networkSecurityGroups/vnet-platform-nsg"
  }

  expect_failures = [
    var.network_security_group_id,
  ]
}

run "a_route_table_id_is_associated" {
  command = plan

  module {
    source = "./modules/subnet"
  }

  variables {
    network_security_group_id = "/subscriptions/0000/resourceGroups/rg-platform-network/providers/Microsoft.Network/networkSecurityGroups/vnet-platform-nsg"
    name                      = "NodeSubnet"
    address_prefixes          = ["100.0.1.0/24"]
    route_table_id            = "/subscriptions/0000/resourceGroups/rg/providers/Microsoft.Network/routeTables/spoke-rt"
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
    network_security_group_id = "/subscriptions/0000/resourceGroups/rg-platform-network/providers/Microsoft.Network/networkSecurityGroups/vnet-platform-nsg"
    name                      = "AzureBastionSubnet"
    address_prefixes          = ["100.0.5.0/24"]
    route_table_id            = "/subscriptions/0000/resourceGroups/rg/providers/Microsoft.Network/routeTables/spoke-rt"
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
    network_security_group_id = "/subscriptions/0000/resourceGroups/rg-platform-network/providers/Microsoft.Network/networkSecurityGroups/vnet-platform-nsg"
    name                      = "BadSubnet"
    address_prefixes          = []
  }

  expect_failures = [
    var.address_prefixes,
  ]
}
