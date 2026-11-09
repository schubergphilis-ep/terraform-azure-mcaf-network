# Tests for ./modules/nsg exercised directly. Kept here rather than under modules/nsg/tests/
# because CI runs a bare `terraform test` at the repository root.

mock_provider "azurerm" {}

variables {
  name                = "test-nsg"
  location            = "westeurope"
  resource_group_name = "rg-platform-network"
}

run "default_rules_are_added" {
  command = plan

  module {
    source = "./modules/nsg"
  }

  variables {
    tags = { Environment = "Production" }
  }

  assert {
    condition     = length(azurerm_network_security_rule.this) == 4 && contains(keys(azurerm_network_security_rule.this), "Deny-Any-Any-Any-In")
    error_message = "the four built-in default rules should be created"
  }

  assert {
    condition     = azurerm_network_security_group.this.tags == tomap({ Environment = "Production" })
    error_message = "the group should carry the tags given, and no others"
  }
}

run "no_default_rules_leaves_only_custom" {
  command = plan

  module {
    source = "./modules/nsg"
  }

  variables {
    include_default_rules = false
    security_rules = {
      allow-https = {
        access                       = "Allow"
        direction                    = "Inbound"
        priority                     = 100
        protocol                     = "Tcp"
        source_address_prefixes      = ["*"]
        source_port_ranges           = ["*"]
        destination_address_prefixes = ["*"]
        destination_port_ranges      = ["443"]
      }
    }
  }

  assert {
    condition     = keys(azurerm_network_security_rule.this) == ["allow-https"]
    error_message = "only the custom rule should exist, named by its key when it has no name"
  }
}

run "a_custom_rule_replaces_a_default_by_name" {
  command = plan

  module {
    source = "./modules/nsg"
  }

  variables {
    security_rules = {
      anything = {
        name                         = "Deny-Any-Any-Any-In"
        access                       = "Allow"
        direction                    = "Inbound"
        priority                     = 4096
        protocol                     = "*"
        source_address_prefixes      = ["*"]
        source_port_ranges           = ["*"]
        destination_address_prefixes = ["*"]
        destination_port_ranges      = ["*"]
      }
    }
  }

  assert {
    condition     = length(azurerm_network_security_rule.this) == 4 && azurerm_network_security_rule.this["Deny-Any-Any-Any-In"].access == "Allow"
    error_message = "the custom rule should take the default's place rather than sit beside it"
  }
}

run "null_default_rules_keep_the_built_in_set" {
  command = plan

  module {
    source = "./modules/nsg"
  }

  variables {
    default_rules = null
  }

  assert {
    condition     = length(azurerm_network_security_rule.this) == 4
    error_message = "null is how the root and the subnet module say 'no override', and must keep the built-in defaults"
  }
}

run "passed_default_rules_replace_the_built_in_set" {
  command = plan

  module {
    source = "./modules/nsg"
  }

  variables {
    default_rules = {
      only = {
        name                         = "only"
        access                       = "Deny"
        direction                    = "Inbound"
        priority                     = 4096
        protocol                     = "*"
        source_address_prefixes      = ["*"]
        source_port_ranges           = ["*"]
        destination_address_prefixes = ["*"]
        destination_port_ranges      = ["*"]
      }
    }
  }

  assert {
    condition     = keys(azurerm_network_security_rule.this) == ["only"]
    error_message = "a passed default_rules map replaces the built-in set"
  }
}

run "bastion_adds_its_rules_and_limits_the_internet_source" {
  command = plan

  module {
    source = "./modules/nsg"
  }

  variables {
    subnet_name                      = "AzureBastionSubnet"
    azure_bastion_source_ip_prefixes = ["203.0.113.0/24", "198.51.100.0/24"]
  }

  assert {
    condition     = length(azurerm_network_security_rule.this) == 15
    error_message = "Bastion's eleven rules should sit beside the four defaults"
  }

  assert {
    condition     = azurerm_network_security_rule.this["Allow-Https-in-from-Internet"].source_address_prefixes == toset(["203.0.113.0/24", "198.51.100.0/24"])
    error_message = "the Internet rule should only allow the configured source prefixes"
  }
}

run "a_custom_rule_replaces_a_default_whose_key_differs_from_its_name" {
  command = plan

  module {
    source = "./modules/nsg"
  }

  variables {
    default_rules = {
      some-key = {
        name                         = "Deny-All-In"
        access                       = "Deny"
        direction                    = "Inbound"
        priority                     = 4096
        protocol                     = "*"
        source_address_prefixes      = ["*"]
        source_port_ranges           = ["*"]
        destination_address_prefixes = ["*"]
        destination_port_ranges      = ["*"]
      }
    }
    security_rules = {
      mine = {
        name                         = "Deny-All-In"
        access                       = "Allow"
        direction                    = "Inbound"
        priority                     = 4096
        protocol                     = "*"
        source_address_prefixes      = ["*"]
        source_port_ranges           = ["*"]
        destination_address_prefixes = ["*"]
        destination_port_ranges      = ["*"]
      }
    }
  }

  assert {
    condition     = keys(azurerm_network_security_rule.this) == ["Deny-All-In"] && azurerm_network_security_rule.this["Deny-All-In"].access == "Allow"
    error_message = "rules are matched by name, so two entries naming the same rule must collapse to the custom one"
  }
}

run "bastion_internet_rule_defaults_to_the_whole_internet" {
  command = plan

  module {
    source = "./modules/nsg"
  }

  variables {
    subnet_name                      = "AzureBastionSubnet"
    azure_bastion_source_ip_prefixes = null
  }

  assert {
    condition     = azurerm_network_security_rule.this["Allow-Https-in-from-Internet"].source_address_prefix == "0.0.0.0/0"
    error_message = "null should keep the built-in default source, which allows the whole Internet"
  }
}

run "a_custom_rule_named_like_a_bastion_rule_is_left_as_written" {
  command = plan

  module {
    source = "./modules/nsg"
  }

  variables {
    subnet_name                      = "AzureBastionSubnet"
    azure_bastion_source_ip_prefixes = ["203.0.113.0/24"]
    security_rules = {
      mine = {
        name                         = "Allow-Https-in-from-Internet"
        access                       = "Allow"
        direction                    = "Inbound"
        priority                     = 4040
        protocol                     = "Tcp"
        source_address_prefixes      = ["198.51.100.7"]
        source_port_ranges           = ["*"]
        destination_address_prefixes = ["*"]
        destination_port_ranges      = ["443"]
      }
    }
  }

  assert {
    condition     = azurerm_network_security_rule.this["Allow-Https-in-from-Internet"].source_address_prefix == "198.51.100.7" && azurerm_network_security_rule.this["Allow-Https-in-from-Internet"].source_address_prefixes == null
    error_message = "the Bastion source limit must not be merged into a rule the caller wrote"
  }
}

run "one_entry_goes_to_the_singular_argument_and_more_stay_a_list" {
  command = plan

  module {
    source = "./modules/nsg"
  }

  variables {
    include_default_rules = false
    security_rules = {
      mixed = {
        access                       = "Allow"
        direction                    = "Inbound"
        priority                     = 100
        protocol                     = "Tcp"
        source_port_ranges           = ["*"]
        destination_port_ranges      = ["80", "443"]
        source_address_prefixes      = ["VirtualNetwork"]
        destination_address_prefixes = ["10.0.0.0/8", "10.1.0.0/16"]
      }
    }
  }

  assert {
    condition = (
      azurerm_network_security_rule.this["mixed"].source_port_range == "*"
      && azurerm_network_security_rule.this["mixed"].source_port_ranges == null
      && azurerm_network_security_rule.this["mixed"].source_address_prefix == "VirtualNetwork"
      && azurerm_network_security_rule.this["mixed"].source_address_prefixes == null
    )
    error_message = "a one-entry list must reach Azure as the singular argument, the only one that takes `*` and tags"
  }

  assert {
    condition = (
      azurerm_network_security_rule.this["mixed"].destination_port_range == null
      && azurerm_network_security_rule.this["mixed"].destination_port_ranges == toset(["80", "443"])
      && azurerm_network_security_rule.this["mixed"].destination_address_prefix == null
      && azurerm_network_security_rule.this["mixed"].destination_address_prefixes == toset(["10.0.0.0/8", "10.1.0.0/16"])
    )
    error_message = "a list of several entries must reach Azure as the plural argument"
  }
}

run "reject_an_empty_list_in_default_rules" {
  command = plan

  module {
    source = "./modules/nsg"
  }

  variables {
    include_default_rules = false
    default_rules = {
      bad = {
        name                         = "bad"
        access                       = "Allow"
        direction                    = "Inbound"
        priority                     = 100
        protocol                     = "Tcp"
        source_port_ranges           = []
        destination_port_ranges      = ["443"]
        source_address_prefixes      = ["*"]
        destination_address_prefixes = ["*"]
      }
    }
  }

  expect_failures = [
    var.default_rules,
  ]
}

run "reject_an_empty_list_in_azure_bastion_security_rules" {
  command = plan

  module {
    source = "./modules/nsg"
  }

  variables {
    include_default_rules = false
    azure_bastion_security_rules = {
      bad = {
        name                         = "bad"
        access                       = "Allow"
        direction                    = "Inbound"
        priority                     = 100
        protocol                     = "Tcp"
        source_port_ranges           = []
        destination_port_ranges      = ["443"]
        source_address_prefixes      = ["*"]
        destination_address_prefixes = ["*"]
      }
    }
  }

  expect_failures = [
    var.azure_bastion_security_rules,
  ]
}

run "reject_empty_azure_bastion_source_ip_prefixes" {
  command = plan

  module {
    source = "./modules/nsg"
  }

  variables {
    include_default_rules            = false
    azure_bastion_source_ip_prefixes = []
  }

  expect_failures = [
    var.azure_bastion_source_ip_prefixes,
  ]
}
