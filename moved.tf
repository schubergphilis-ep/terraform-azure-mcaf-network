################################################################################
# State relocation for the ./modules/subnet extraction.
#
# Subnets used to be declared inline in this module. They now live in
# ./modules/subnet with identical resource arguments and identical for_each
# keys, so upgrading is a state move rather than a replacement: Terraform
# reports "moved" and plans no changes to Azure.
#
# Keep this block. Removing it would make Terraform see the old addresses as
# gone and the new ones as new — destroying and recreating every subnet, and
# with them anything attached. It can only be dropped in a major version whose
# notes state that consumers must upgrade through this version first.
################################################################################

moved {
  from = azurerm_subnet.this
  to   = module.subnet.azurerm_subnet.this
}
