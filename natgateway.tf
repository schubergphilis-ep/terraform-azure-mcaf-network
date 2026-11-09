resource "azurerm_nat_gateway" "this" {
  count = var.natgateway != null ? 1 : 0

  name                = var.natgateway.name
  location            = azurerm_virtual_network.this.location
  resource_group_name = azurerm_virtual_network.this.resource_group_name
  sku_name            = var.natgateway.sku
  zones               = var.natgateway.zones

  tags = var.tags
}

resource "azurerm_public_ip" "this" {
  # A public IP passed in by id is the one used, so there is nothing to create beside it.
  count = var.natgateway != null && var.public_ip != null && var.natgateway.public_ip_address_id == null ? 1 : 0

  name                = var.public_ip.name == null ? "${var.natgateway.name}-pip" : var.public_ip.name
  location            = azurerm_virtual_network.this.location
  resource_group_name = azurerm_virtual_network.this.resource_group_name
  allocation_method   = var.public_ip.allocation_method
  ip_version          = var.public_ip.ip_version
  sku                 = var.public_ip.sku
  sku_tier            = var.public_ip.sku_tier
  zones               = var.public_ip.zones == null ? var.natgateway.zones : var.public_ip.zones

  tags = var.tags
}

resource "azurerm_nat_gateway_public_ip_association" "this" {
  count = var.natgateway != null ? 1 : 0

  nat_gateway_id       = azurerm_nat_gateway.this[0].id
  public_ip_address_id = var.natgateway.public_ip_address_id != null ? var.natgateway.public_ip_address_id : azurerm_public_ip.this[0].id
}

resource "azurerm_subnet_nat_gateway_association" "this" {
  for_each = var.natgateway != null ? { for k, v in var.subnets : k => v if local.subnet_names[k] != "GatewaySubnet" } : {}

  subnet_id      = module.subnet[each.key].id
  nat_gateway_id = azurerm_nat_gateway.this[0].id
}
