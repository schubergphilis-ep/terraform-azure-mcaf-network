# Upgrading Notes

This document captures required refactoring on your part when upgrading to a module version that contains breaking changes.

## Upgrading to v2.0.0

### Key Changes v2.0.0

Subnets moved out of the root module into `./modules/subnet`, which the root module now calls with `for_each`. Because the `for_each` moved from the resource to the module, every subnet address changes:

- Old address: `azurerm_subnet.this["<key>"]`
- New address: `module.subnet["<key>"].azurerm_subnet.this`

`address_prefixes` is now enforced on each subnet. The singular `address_prefix` is still accepted as an attribute but fails validation — it never produced a usable subnet, since `azurerm` removed the argument and no resource read it.

The submodule also performs the network security group association, so three of the four association resources move with it. Every group and every rule stays exactly where it was, in the root module:

| Old address | New address |
|---|---|
| `azurerm_subnet_network_security_group_association.this["<key>"]` | `module.subnet["<key>"].azurerm_subnet_network_security_group_association.this[0]` |
| `azurerm_subnet_network_security_group_association.simple["<key>"]` | same |
| `azurerm_subnet_network_security_group_association.additional["<key>"]` | same |

`AzureBastionSubnet` is the exception and does not move: Bastion rejects a group that lacks its required rules, and that ordering cannot be expressed from inside the submodule's `for_each`.

Which group a subnet is associated with does not change, `no_nsg_association` included — down to `create_network_security_group` with `network_security_group_config.azure_default` continuing to associate even when `no_nsg_association` is set, which is how it behaved before.

> [!WARNING]
> `route_table` on a subnet now takes effect. It was accepted and silently ignored in `v1.x`, because no resource read it. If you have been passing it, the first apply after upgrading creates the association — and replaces whatever route table is attached to that subnet today. Check `route_table` against live state before applying, or drop the attribute.

Root module outputs are unchanged, including `subnets`, `all_subnets` and `all_network_security_groups`.

> [!IMPORTANT]
> This module cannot ship the `moved` blocks for you — they cannot be generated with `for_each`, and a keyless block does not work when resources move from a module into a submodule. Without one block per subnet key, Terraform destroys and recreates every subnet and everything attached to them. The failure mode is silent replacement, not an error.

### How to upgrade v2.0.0

1. Upgrade from `v1.x`. Earlier versions are untested against this path.

2. Replace any singular `address_prefix` with `address_prefixes`:

   ```hcl
   "CoreSubnet" = { address_prefixes = ["100.0.1.0/24"] }
   ```

3. Add one `moved` block per subnet key, adjusting `module.network` to the name you call this module by:

   ```hcl
   moved {
     from = module.network.azurerm_subnet.this["CoreSubnet"]
     to   = module.network.module.subnet["CoreSubnet"].azurerm_subnet.this
   }
   ```

4. Add a second block per subnet key that had a group associated, using whichever of `this`, `simple` or `additional` applied to it. `terraform state list | grep subnet_network_security_group_association` prints exactly which, so the names do not have to be worked out from the configuration:

   ```hcl
   moved {
     from = module.network.azurerm_subnet_network_security_group_association.this["CoreSubnet"]
     to   = module.network.module.subnet["CoreSubnet"].azurerm_subnet_network_security_group_association.this[0]
   }
   ```

   Skip `AzureBastionSubnet` — its association stays in the root module.

5. Run `terraform plan` and confirm it reports `0 to add, 0 to change, 0 to destroy`. Anything else means a block is missing or a key is wrong — do not apply until the plan is clean.

6. Apply, then drop the `moved` blocks once every consumer has upgraded.
