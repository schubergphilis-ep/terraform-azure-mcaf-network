# The shared group and its rules moved into ./modules/nsg. Unlike the per-subnet resources these can
# be moved here, because the module is called at most once and the rule keys do not change.
moved {
  from = azurerm_network_security_group.this
  to   = module.nsg[0].azurerm_network_security_group.this
}

moved {
  from = azurerm_network_security_rule.default
  to   = module.nsg[0].azurerm_network_security_rule.this
}
