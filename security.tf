# The group shared by every subnet that does not ask for its own, and only created when one uses it.
# shortcut: a subnet that brings its own network_security_group_id still counts as a user, because that
# id can be unknown at plan time and a count cannot depend on it; revisit if that creates unused groups.
module "nsg" {
  source = "./modules/nsg"
  count  = length(local.default_subnets) > 0 ? 1 : 0

  name                = "${var.vnet_name}-nsg"
  location            = azurerm_virtual_network.this.location
  resource_group_name = azurerm_virtual_network.this.resource_group_name
  tags                = var.tags

  security_rules = var.security_rules
  default_rules  = var.default_rules
}
