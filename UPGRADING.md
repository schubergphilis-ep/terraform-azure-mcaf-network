# Upgrading Notes

This document captures required refactoring on your part when upgrading to a module version that contains breaking changes.

## Upgrading to v2.0.0

### Key Changes v2.0.0

Subnets moved out of the root module into `./modules/subnet`, which the root module now calls with `for_each`. Because the `for_each` moved from the resource to the module, every subnet address changes:

- Old address: `azurerm_subnet.this["<key>"]`
- New address: `module.subnet["<key>"].azurerm_subnet.this`

`address_prefixes` is now enforced on each subnet. The singular `address_prefix` is still accepted as an attribute but fails validation — it never produced a usable subnet, since `azurerm` removed the argument and no resource read it.

Root module outputs are unchanged, including `subnets`, `all_subnets` and `all_network_security_groups`.

> [!IMPORTANT]
> This module cannot ship the `moved` blocks for you — they cannot be generated with `for_each`, and a keyless block does not work when resources move from a module into a submodule. Without one block per subnet key, Terraform destroys and recreates every subnet and everything attached to them. The failure mode is silent replacement, not an error.

### How to upgrade v2.0.0

1. Upgrade from `v1.0.0`. Earlier versions are untested against this path.

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

4. Run `terraform plan` and confirm it reports `0 to add, 0 to change, 0 to destroy`. Anything else means a block is missing or a key is wrong — do not apply until the plan is clean.

5. Apply, then drop the `moved` blocks once every consumer has upgraded.
