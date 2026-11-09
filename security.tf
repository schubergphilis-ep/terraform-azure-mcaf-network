# The group shared by every subnet that does not ask for its own.
module "nsg" {
  source = "./modules/nsg"

  name                = "${var.vnet_name}-nsg"
  location            = azurerm_virtual_network.this.location
  resource_group_name = azurerm_virtual_network.this.resource_group_name
  tags                = var.tags

  security_rules = var.security_rules
  default_rules  = var.default_rules
}
