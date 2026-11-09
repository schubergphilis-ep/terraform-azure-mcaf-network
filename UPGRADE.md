# Upgrading Notes

This document captures required refactoring on your part when upgrading to a module version that contains breaking changes.

## Upgrading to v3.0.0

### Key Changes v3.0.0

Subnets, and every per-subnet network security group, moved out of the root module into `./modules/subnet`, which the root module now calls with `for_each`. Because the `for_each` moved from the resource to the module, every one of their addresses changes. The shared group and its `default` rules move into `./modules/nsg`, which the subnet module also uses for its groups. This module ships the `moved` blocks for the shared group, so there is nothing to add for it.

| What | Old address | New address |
|---|---|---|
| Subnet | `azurerm_subnet.this["<key>"]` | `module.subnet["<key>"].azurerm_subnet.this` |
| Group association | `azurerm_subnet_network_security_group_association.<this\|simple\|additional\|azbastion>["<key>"]` | `module.subnet["<key>"].azurerm_subnet_network_security_group_association.this[0]` |
| Per-subnet group | `azurerm_network_security_group.<simple\|additional\|azbastion>["<key>"]` | `module.subnet["<key>"].module.nsg[0].azurerm_network_security_group.this` |
| Per-subnet rule | `azurerm_network_security_rule.<simple\|additional\|azbastion>["<subnet>_<priority>_<access>_<direction>"]` | `module.subnet["<key>"].module.nsg[0].azurerm_network_security_rule.this["<rule name>"]` |

`azurerm_network_security_group.this` and `azurerm_network_security_rule.default[...]` are the shared group and its rules. They move to `module.nsg` by themselves. The `<rule name>` is the rule's name in Azure, so no rule is renamed.

`AzureBastionSubnet` moves like every other subnet. The submodule creates the rules before it attaches the group, so the group never sits on the subnet carrying only Azure's default rules.

`address_prefixes` is now enforced on each subnet. The singular `address_prefix` is still accepted but ignored, as it always was: `azurerm` removed the argument and no resource read it. A subnet that only sets it now fails validation.

The provider requirement does not change: `v2.0.0` already moved the module to `azurerm` v5.

The `Resource Type` tag is no longer added to the virtual network, NAT gateway, public IP or network security groups, so the first apply removes it from them: an in-place update. If something depends on it, put a tag of your own in `tags`.

Which group a subnet gets, and whether it is associated, does not change. `no_nsg_association` still skips only the association, so a group the subnet asked for is created either way, and `network_security_group_config.azure_default` still associates even when `no_nsg_association` is set.

> [!WARNING]
> `route_table` on a subnet now takes effect. It was accepted and silently ignored through `v2.x`, because no resource read it. If you have been passing it, the first apply after upgrading creates the association — and replaces whatever route table is attached to that subnet today. Check `route_table` against live state before applying, or drop the attribute.
>
> On `AzureBastionSubnet` this is fatal rather than disruptive: Azure refuses the attachment with `RouteTableCannotBeAttachedForAzureBastionSubnet`. A `route_table` that was inert on `v2.x` therefore becomes an error, so it must be removed from that subnet before upgrading. The module now fails this at plan time instead of part-way through an apply.

Root module outputs keep their names and shape: `subnets`, `all_subnets` and `all_network_security_groups`.

> [!IMPORTANT]
> This module cannot ship the `moved` blocks for the subnets and their per-subnet groups. A `moved` block takes literal addresses, so it cannot be generated with `for_each`, and the subnet keys are yours. The one keyless block the module could ship, from `azurerm_subnet.this` to `module.subnet`, targets an address that does not exist once `module.subnet` has a `for_each`. Terraform accepts it without an error and plans to destroy and recreate every subnet and everything attached to them.

### How to upgrade v3.0.0

1. Upgrade from `v2.x`. If you are on `v1.x`, upgrade to `v2.0.0` first: it moves the module to `azurerm` v5 and is a separate step from this one.

2. Replace any singular `address_prefix` with `address_prefixes`:

   ```hcl
   "CoreSubnet" = { address_prefixes = ["100.0.1.0/24"] }
   ```

3. Bump the module source to `v3.0.0` and add every block below **in the same change**. A `moved` block is only valid once its source address has stopped existing in the configuration, so adding the blocks while still on `v2.x` fails with `Moved object still exists` for each one.

   Everything that moves is listed by:

   ```sh
   terraform state list | grep -E 'azurerm_(subnet\.this|subnet_network_security_group_association\.|network_security_group\.(simple|additional|azbastion)|network_security_rule\.(simple|additional|azbastion))'
   ```

   Adjust `module.network` in the blocks below to the name you call this module by.

4. Add one `moved` block per subnet key:

   ```hcl
   moved {
     from = module.network.azurerm_subnet.this["CoreSubnet"]
     to   = module.network.module.subnet["CoreSubnet"].azurerm_subnet.this
   }
   ```

5. Add a second block per subnet key that had a group associated, using whichever of `this`, `simple`, `additional` or `azbastion` the state list shows for it:

   ```hcl
   moved {
     from = module.network.azurerm_subnet_network_security_group_association.this["CoreSubnet"]
     to   = module.network.module.subnet["CoreSubnet"].azurerm_subnet_network_security_group_association.this[0]
   }
   ```

6. Add a block per subnet that owned a group, using whichever of `simple`, `additional` or `azbastion` applied to it. The group is `count`-based in the submodule, so the target carries `[0]`:

   ```hcl
   moved {
     from = module.network.azurerm_network_security_group.additional["CoreSubnet"]
     to   = module.network.module.subnet["CoreSubnet"].module.nsg[0].azurerm_network_security_group.this
   }
   ```

   `azurerm_network_security_group.this` is not in this list. The group shared by every subnet that does not ask for its own is moved by the module.

7. Add a block per rule on those groups. **The key changes**: the root keyed rules `<subnet>_<priority>_<access>_<direction>`, the NSG module keys them by rule name, so the target is not a copy of the source:

   ```hcl
   moved {
     from = module.network.azurerm_network_security_rule.additional["coresubnet_200_allow_inbound"]
     to   = module.network.module.subnet["CoreSubnet"].module.nsg[0].azurerm_network_security_rule.this["Allow-Https-Inbound"]
   }
   ```

8. Run `terraform plan` and confirm it reports `0 to add` and `0 to destroy`. The only changes should be in-place: the shared group's rules gain their `description`, and the `Resource Type` tag goes away. Anything else means a block is missing or a key is wrong — do not apply until the plan matches.

9. Apply, then drop the `moved` blocks once every consumer has upgraded.
