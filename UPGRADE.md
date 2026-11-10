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
| Per-subnet rule | `azurerm_network_security_rule.<simple\|additional\|azbastion>["<subnet>_<priority>_<access>_<direction>"]` (the whole key is lower-cased) | `module.subnet["<key>"].module.nsg[0].azurerm_network_security_rule.this["<rule name>"]` |

`azurerm_network_security_group.this` and `azurerm_network_security_rule.default[...]` are the shared group and its rules. They move to `module.nsg` by themselves. The `<rule name>` is the rule's name in Azure, so no rule is renamed.

One exception: if a key in `default_rules` or `azure_bastion_security_rules` differs from its `name`, `v2.x` named the per-subnet copies after the key and the shared ones after `name`. The per-subnet copies are then renamed, which replaces them, and the shared rules need one more block, because rules are now keyed by name:

```hcl
moved {
  from = module.network.module.nsg.azurerm_network_security_rule.this["<key>"]
  to   = module.network.module.nsg.azurerm_network_security_rule.this["<name>"]
}
```

`AzureBastionSubnet` moves like every other subnet. The submodule creates the rules before it attaches the group, so the group never sits on the subnet carrying only Azure's default rules.

`address_prefixes` is now checked on each subnet by this module, and the singular `address_prefix` is gone from the `subnets` type. It was accepted but ignored, because `azurerm` removed the argument and no resource read it, so a subnet that only sets it already failed at plan. It now fails with a clearer message.

The minimum stays `azurerm` v5, which `v2.0.0` already required. The constraint is widened from `~> 5` to `>= 5`.

The `Resource Type` tag is no longer added to the virtual network, NAT gateway, public IP or network security groups, so the first apply removes it from them: an in-place update. If something depends on it, put a tag of your own in `tags`.

Every subnet now has exactly one network security group, except `GatewaySubnet`, which has none. Which group a subnet gets does not change, apart from the subnets that used `no_nsg_association`, below.

> [!WARNING]
> `route_table` on a subnet now takes effect. It was accepted and silently ignored through `v2.x`, because no resource read it. If you have been passing it, the first apply after upgrading creates the association — and replaces whatever route table is attached to that subnet today. Check `route_table` against live state before applying, or drop the attribute.
>
> On `AzureBastionSubnet` this is fatal rather than disruptive: Azure refuses the attachment with `RouteTableCannotBeAttachedForAzureBastionSubnet`. A `route_table` that was inert on `v2.x` therefore becomes an error, so it must be removed from that subnet before upgrading. The module now fails this at plan time instead of part-way through an apply.

Root module outputs keep their names and shape: `subnets`, `all_subnets` and `all_network_security_groups`.

> [!IMPORTANT]
> This module cannot ship the `moved` blocks for the subnets and their per-subnet groups. A `moved` block takes literal addresses, so it cannot be generated with `for_each`, and the subnet keys are yours. The one keyless block the module could ship, from `azurerm_subnet.this` to `module.subnet.azurerm_subnet.this`, targets an address that does not exist once `module.subnet` has a `for_each`. Terraform accepts it without an error and plans to destroy and recreate every subnet and everything attached to them.

### Security rules take lists only

Every rule, in `security_rules`, `default_rules`, `azure_bastion_security_rules` and the subnet module's `network_security_group.security_rules`, now takes lists only. The singular attributes are gone:

| Old | New |
|---|---|
| `source_port_range = "*"` | `source_port_ranges = ["*"]` |
| `destination_port_range = "443"` | `destination_port_ranges = ["443"]` |
| `source_address_prefix = "VirtualNetwork"` | `source_address_prefixes = ["VirtualNetwork"]` |
| `destination_address_prefix = "*"` | `destination_address_prefixes = ["*"]` |

All four lists are required and must not be empty, and a rule that still uses a singular attribute fails at plan with a missing-attribute error. Azure takes `*` and tags such as `VirtualNetwork` only in the singular argument, and several entries only in the plural one. The module therefore sends a one-entry list as the singular argument and a longer list as the plural one. Give `*` and tags as the single entry of a list; several entries must be plain ports, ranges or CIDRs.

The built-in default rules reach Azure exactly as before. A rule you had written with a one-entry plural list, such as `source_address_prefixes = ["10.0.0.0/8"]`, now reaches Azure as the singular argument and is updated in place, and so is Bastion's `Allow-Https-in-from-Internet`, whose single prefix `0.0.0.0/0` was a one-entry list.

### Other behaviour changes

Each of these changes what an existing configuration plans. Check them against yours before applying.

- **`no_nsg_association` is removed**, and setting it fails at plan. It skipped only the association: a subnet with `create_network_security_group = true`, and `AzureBastionSubnet`, still got their group and rules created, left unattached, and only a subnet on the shared or an existing group ended up with none. Now every such subnet is associated with its group. Remove the attribute and the first apply attaches the group the subnet would have had: its own, the one named by `network_security_group_id`, or the shared one. `GatewaySubnet` is the only subnet that can be without a group.
- **`create_network_security_group = true` with `network_security_group_config = { azure_default = false }`** (or `{}`) used to give the subnet no group at all, not even the shared one. It now gets a group of its own with the default rules, and is associated. Those rules deny all other traffic, so check what the subnet relies on first.
- **`create_network_security_group = true` on `GatewaySubnet`** now fails at plan: Azure does not support a group there, and one can stop the gateway working. Remove it, and the first apply destroys the group, its rules and its association.
- **`AzureBastionSubnet` and `GatewaySubnet` are recognised by the subnet's name**, which defaults to its key, instead of by the key alone. It only differs when `name` is one of them under another key: a subnet named `AzureBastionSubnet` now gets Bastion's own group, which replaces its association, and a subnet named `GatewaySubnet` now gets no NAT gateway and no group association. The first apply destroys what no longer applies.
- **`natgateway.public_ip_address_id`** now means no public IP is created. Until now `public_ip` still created one beside it, unused, unless you set `public_ip = null`. If you had both, the first apply destroys that unused public IP.
- **`private_dns` with `zone_link_enabled = false`** is now honoured. It was ignored, so the link was always created. The first apply destroys the link and keeps the zone.

### How to upgrade v3.0.0

1. Upgrade from `v2.x`. If you are on `v1.x`, upgrade to `v2.0.0` first: it moves the module to `azurerm` v5 and is a separate step from this one.

2. Replace any singular `address_prefix` with `address_prefixes`, and rewrite every security rule with lists, as described under *Security rules take lists only*:

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

7. Add a block per rule on those groups. **The key changes**: the root keyed rules by the lower-cased `<subnet>_<priority>_<access>_<direction>`, the NSG module keys them by rule name, which `terraform state show` prints, so the target is not a copy of the source:

   ```hcl
   moved {
     from = module.network.azurerm_network_security_rule.additional["coresubnet_200_allow_inbound"]
     to   = module.network.module.subnet["CoreSubnet"].module.nsg[0].azurerm_network_security_rule.this["Allow-Https-Inbound"]
   }
   ```

8. Run `terraform plan` and confirm it reports `0 to add` and `0 to destroy`, apart from what the warnings and *Other behaviour changes* above describe: the route table associations `route_table` now creates, the associations for subnets that used `no_nsg_association`, and the groups, public IP and DNS link that come or go. The only other changes should be in-place: the shared group's rules gain their `description`, rules written with a one-entry plural list, and Bastion's Internet rule, move to the singular argument, and the `Resource Type` tag goes away. Anything else means a block is missing or a key is wrong — do not apply until the plan matches.

9. Apply, then drop the `moved` blocks once every consumer has upgraded.
