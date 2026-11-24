# Plans an example that hands the subnet module a group id which only exists after apply, as a real
# caller does. The mock provider leaves ids unknown at plan time, so a count that depends on them fails here.
mock_provider "azurerm" {}

run "subnet_multiple_example_plans_with_an_unknown_group_id" {
  command = plan

  module {
    source = "./modules/subnet/examples/multiple"
  }

  assert {
    condition     = length(output.subnet_ids) == 6
    error_message = "every subnet of the example should plan, with a group created, a group given by id, or none"
  }

  # These are the explicit-null paths, which a test's own variables cannot express.
  assert {
    condition     = module.subnet["ScratchSubnet"].network_security_group_id == null && module.subnet["GatewaySubnet"].network_security_group_id == null
    error_message = "a subnet that asks for null, and GatewaySubnet, should have no group"
  }

  assert {
    condition     = endswith(module.subnet["AppSubnet"].network_security_group_name, "-appsubnet-nsg") && module.subnet["DataSubnet"].network_security_group_name == null
    error_message = "a subnet that says nothing should get a group of its own, and one given an existing group should create none (its id is unknown at plan, so only the name is checked)"
  }
}
