# Migration guide

## Subnets moved into `./modules/subnet`

Subnets used to be declared inline in the root module. They now live in
`./modules/subnet`, which the root module calls. The extraction exists so that
callers whose virtual network is provisioned elsewhere — by a platform team, in
a separate state, in another repository — can create only the subnets:

```hcl
module "subnets" {
  source = "schubergphilis-ep/mcaf-network/azure//modules/subnet"

  resource_group_name  = "rg-platform-network"
  virtual_network_name = "vnet-platform"

  subnets = {
    "NodeSubnet" = {
      address_prefixes = ["100.0.1.0/24"]
    }
  }
}
```

### Upgrading the root module: no subnet is replaced

Resource arguments and `for_each` keys are unchanged, so the extraction is a
state move rather than a replacement. `moved.tf` handles it, and no action is
required. A plan across the upgrade reports the relocation and no changes:

```
# module.network.azurerm_subnet.this["CoreSubnet"] has moved to module.network.module.subnet.azurerm_subnet.this["CoreSubnet"]
# module.network.azurerm_subnet.this["RoutedSubnet"] has moved to module.network.module.subnet.azurerm_subnet.this["RoutedSubnet"]
Plan: 0 to add, 0 to change, 0 to destroy.
```

Do not delete `moved.tf`. Without it Terraform reads the old addresses as gone
and the new ones as new, which destroys and recreates every subnet along with
anything attached to them. It can only be removed in a major version whose notes
require consumers to upgrade through this version first.

Root module outputs are unchanged, including `subnets`, `all_subnets` and
`all_network_security_groups`.

## `route_table` is now effective, behind an opt-in

Up to and including `v1.0.0` the `route_table` attribute on a subnet was accepted
and silently ignored: no resource read it. It is now implemented as
`azurerm_subnet_route_table_association`, gated on a new root variable:

```hcl
manage_route_table_associations = false  # default
```

The default reproduces the old behaviour exactly, so upgrading changes nothing.

**Before enabling it, check what is already attached.** A subnet accepts only one
route table, so if these subnets already have one — attached by hand, by policy,
or by a resource in your own configuration — enabling this puts Terraform in
charge of an association that already exists. Where nothing is attached yet,
enabling it changes how traffic leaves those subnets. Neither case replaces a
subnet, but neither is a no-op either.

Consumers who set `route_table` expecting it to work were, in effect, running
without it. Enabling the flag is what they want, but it should be a deliberate
step with a plan reviewed first.

Calling `./modules/subnet` directly always honours `route_table`; the flag exists
only to protect existing root-module state. The route table itself is not created
by either module — pass the ID of one you own.

## `address_prefix` is rejected in favour of `address_prefixes`

The singular `address_prefix` never worked. `azurerm` removed that argument from
`azurerm_subnet`, and no resource in this module read it, so a subnet configured
with only `address_prefix` planned cleanly and then failed at apply with Azure
rejecting a subnet that has no prefix.

The root module still accepts the attribute, so existing configurations do not
fail with "unsupported attribute", but validation now requires the plural:

```
Each subnet needs at least one entry in `address_prefixes`. The singular
`address_prefix` is ignored — azurerm has no such argument — so move its value
into `address_prefixes = [...]`.
```

Move the value across:

```hcl
# before — never created a usable subnet
"CoreSubnet" = { address_prefix = "100.0.1.0/24" }

# after
"CoreSubnet" = { address_prefixes = ["100.0.1.0/24"] }
```

Configurations that set `address_prefixes`, with or without the singular
alongside it, are unaffected. `./modules/subnet` does not accept the singular at
all.

## `./modules/subnet` accepts a narrower `subnets` type

The submodule's `subnets` type lists only what it implements. These attributes
are **not** accepted there, and setting one is a type error rather than a value
that gets discarded:

`nat_gateway`, `no_nsg_association`, `create_network_security_group`,
`network_security_group_config`, `network_security_group_id`, `role_assignments`,
`service_endpoint_policies`, `sharing_scope`, `timeouts`

They remain available on the **root** module, which composes those resources
around the subnets itself. Nothing changes for root-module callers.

If you call `./modules/subnet` directly and need network security groups or a NAT
gateway, declare them in your own configuration against the returned IDs:

```hcl
resource "azurerm_subnet_network_security_group_association" "nodes" {
  subnet_id                 = module.subnets.subnet_ids["NodeSubnet"]
  network_security_group_id = azurerm_network_security_group.nodes.id
}
```

`subnet_ids` is keyed by the `subnets` input key, so a lookup does not depend on
whether `name` was overridden.
