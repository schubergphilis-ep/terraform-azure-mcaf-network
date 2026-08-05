# Migration guide

## Subnets moved into `./modules/subnet`

Subnets used to be declared inline in the root module. They now live in
`./modules/subnet`, which handles exactly one subnet; the root module calls it
with `for_each`. Callers whose virtual network is provisioned elsewhere can call
it directly:

```hcl
module "subnet" {
  source  = "schubergphilis-ep/mcaf-network/azure//modules/subnet"
  version = "2.0.0"

  name                 = "NodeSubnet"
  resource_group_name  = "rg-platform-network"
  virtual_network_name = "vnet-platform"
  address_prefixes     = ["100.0.1.0/24"]
}
```

For several subnets, `for_each` the module:

```hcl
module "subnet" {
  source   = "schubergphilis-ep/mcaf-network/azure//modules/subnet"
  version  = "2.0.0"
  for_each = local.subnets

  name                 = each.key
  resource_group_name  = "rg-platform-network"
  virtual_network_name = "vnet-platform"
  address_prefixes     = each.value.address_prefixes
}
```

### Upgrading the root module requires `moved` blocks you write yourself

Subnet resource addresses change, because the `for_each` moved from the resource
to the module:

```
azurerm_subnet.this["CoreSubnet"]  ->  module.subnet["CoreSubnet"].azurerm_subnet.this
```

**Without a `moved` block per subnet, Terraform destroys and recreates every
subnet**, and anything attached to them. `moved` blocks cannot be generated with
`for_each`, so this module cannot ship them for you — add one per subnet key to
your own configuration before upgrading:

```hcl
moved {
  from = module.network.azurerm_subnet.this["CoreSubnet"]
  to   = module.network.module.subnet["CoreSubnet"].azurerm_subnet.this
}

moved {
  from = module.network.azurerm_subnet.this["RoutedSubnet"]
  to   = module.network.module.subnet["RoutedSubnet"].azurerm_subnet.this
}
```

Adjust `module.network` to whatever you call this module. A correct set of blocks
plans as:

```
# module.network.azurerm_subnet.this["CoreSubnet"] has moved to module.network.module.subnet["CoreSubnet"].azurerm_subnet.this
Plan: 0 to add, 0 to change, 0 to destroy.
```

Anything other than `0 to add, 0 to change, 0 to destroy` means a block is
missing or a key is wrong. **Do not apply until the plan is clean** — the failure
mode is silent replacement, not an error. A whole-resource block without the
instance keys does not work: Terraform ignores it and plans the replacement
anyway.

Root module outputs are unchanged, including `subnets`, `all_subnets` and
`all_network_security_groups`.

## `route_table` is now effective, behind an opt-in

Up to and including `v1.0.0` the `route_table` attribute on a subnet was accepted
and silently ignored: no resource read it. It is now implemented as
`azurerm_subnet_route_table_association`, gated on a new root variable:

```hcl
manage_route_table_associations = false  # default
```

The default reproduces the old behaviour, so upgrading changes nothing here.

**Before enabling it, check what is already attached.** A subnet accepts only one
route table, so if these subnets already have one — attached by hand, by policy,
or by a resource in your own configuration — enabling this puts Terraform in
charge of an association that already exists. Where nothing is attached yet,
enabling it changes how traffic leaves those subnets. Neither case replaces a
subnet, but neither is a no-op either.

Calling `./modules/subnet` directly always honours `route_table`; the flag exists
only to protect existing root-module state.

## `address_prefix` is rejected in favour of `address_prefixes`

The singular `address_prefix` never worked. `azurerm` removed that argument from
`azurerm_subnet`, and no resource in this module read it, so a subnet configured
with only `address_prefix` planned cleanly and then failed at apply with Azure
rejecting a subnet that has no prefix.

The root module still accepts the attribute, so existing configurations do not
fail with "unsupported attribute", but validation now requires the plural:

```hcl
# before — never created a usable subnet
"CoreSubnet" = { address_prefix = "100.0.1.0/24" }

# after
"CoreSubnet" = { address_prefixes = ["100.0.1.0/24"] }
```

`./modules/subnet` does not accept the singular at all.

## `./modules/subnet` covers the subnet only

The submodule takes one subnet and its own attributes. Network security groups,
NAT gateways, service endpoint policies and role assignments are **not** part of
it — the root module composes those around the subnets it creates.

Calling the submodule directly, declare them yourself against the returned ID:

```hcl
resource "azurerm_subnet_network_security_group_association" "nodes" {
  subnet_id                 = module.subnet.id
  network_security_group_id = azurerm_network_security_group.nodes.id
}
```

Nothing changes for root-module callers; those attributes stay on the root
`subnets` variable.
