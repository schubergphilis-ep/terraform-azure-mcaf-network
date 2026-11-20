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
}
