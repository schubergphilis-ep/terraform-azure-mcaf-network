variable "resource_group_name" {
  type        = string
  description = "Name of the resource group to create the virtual network in."
  nullable    = false
}

variable "location" {
  type        = string
  description = "Location of the virtual network."
  nullable    = false
}

variable "natgateway" {
  type = object({
    name                    = optional(string, null)
    public_ip_address_id    = optional(string, null)
    allocation_method       = optional(string, "Static")
    ddos_protection_mode    = optional(string, "VirtualNetworkInherited")
    ddos_protection_plan_id = optional(string, null)
    domain_name_label       = optional(string, null)
    idle_timeout_in_minutes = optional(number, 4)
    inherit_tags            = optional(bool, true)
    ip_address_resource_id  = optional(string, null)
    ip_version              = optional(string, "IPv4")
    lock_level              = optional(string, null)
    sku                     = optional(string, "Standard")
    sku_tier                = optional(string, "Regional")
    zones                   = optional(list(string))
  })
  default     = null
  nullable    = true
  description = <<DESCRIPTION
Creates a NAT gateway and attaches it to every subnet except GatewaySubnet. Leave null for none.

- `name`                 = (Required) - The name of the NAT gateway. Changing this forces a new resource to be created.
- `sku`                  = (Optional) - The SKU of the NAT gateway. Defaults to Standard.
- `zones`                = (Optional) - The zones of the NAT gateway, and of the public IP unless `public_ip.zones` is set. Changing this forces a new resource to be created.
- `public_ip_address_id` = (Optional) - An existing public IP to attach. When set, no public IP is created and `public_ip` is not used.

Accepted but not used: `allocation_method`, `ddos_protection_mode`, `ddos_protection_plan_id`, `domain_name_label`, `idle_timeout_in_minutes`, `inherit_tags`, `ip_address_resource_id`, `ip_version`, `lock_level` and `sku_tier`. Configure the created public IP through `public_ip`.

Example:

```hcl
natgateway = {
  name = "my-nat-gw"

  validation {
    condition     = var.natgateway == null || var.natgateway.name != null
    error_message = "natgateway.name is required: Azure needs a name for the NAT gateway."
  }

  validation {
    condition     = var.natgateway == null || var.natgateway.public_ip_address_id != null || var.public_ip != null
    error_message = "A NAT gateway needs a public IP: set natgateway.public_ip_address_id, or leave public_ip set so one is created."
  }
}
```
DESCRIPTION
}

variable "subnets" {
  type = map(object({
    name                            = optional(string)
    address_prefixes                = optional(list(string))
    default_outbound_access_enabled = optional(bool, false)
    delegate_to                     = optional(string, null)
    delegate_to_actions             = optional(list(string), null)
    nat_gateway = optional(object({
      id = string
    }))
    no_nsg_association            = optional(bool, false)
    create_network_security_group = optional(bool, false)
    network_security_group_config = optional(object({
      azure_default = optional(bool, false)
    }), null)
    network_security_group_id                     = optional(string, null)
    private_endpoint_network_policies             = optional(string, "Disabled")
    private_link_service_network_policies_enabled = optional(bool, true)
    role_assignments = optional(map(object({
      role_definition_id_or_name             = string
      principal_id                           = string
      description                            = optional(string, null)
      skip_service_principal_aad_check       = optional(bool, false)
      condition                              = optional(string, null)
      condition_version                      = optional(string, null)
      delegated_managed_identity_resource_id = optional(string, null)
      principal_type                         = optional(string, null)
    })))
    route_table = optional(object({
      id = string
    }))
    service_endpoint_policies = optional(map(object({
      id = string
    })))
    service_endpoints = optional(set(string))
    sharing_scope     = optional(string, null)
    timeouts = optional(object({
      create = optional(string)
      delete = optional(string)
      read   = optional(string)
      update = optional(string)
    }))
  }))
  default     = {}
  description = <<DESCRIPTION
The subnets to create in the virtual network, keyed by their name unless `name` is set. Each is created by ./modules/subnet.

- `address_prefixes`                             = (Required) - The address prefixes of the subnet, as a list.
- `name`                                         = (Optional) - The name of the subnet. Defaults to its key. A subnet named `AzureBastionSubnet` gets Azure Bastion's rules in a group of its own; `GatewaySubnet` takes no network security group.
- `default_outbound_access_enabled`              = (Optional) - Whether the subnet has default outbound access. Defaults to false.
- `delegate_to`                                  = (Optional) - The service to delegate the subnet to, for example `Microsoft.ContainerInstance/containerGroups`.
- `delegate_to_actions`                          = (Optional) - The delegation's actions. Defaults to the entry for `delegate_to` in `subnet_delegations_actions`.
- `private_endpoint_network_policies`            = (Optional) - Possible values are Disabled, Enabled, NetworkSecurityGroupEnabled and RouteTableEnabled. Defaults to Disabled.
- `private_link_service_network_policies_enabled` = (Optional) - Whether network policies apply to private link service on the subnet. Defaults to true.
- `route_table`                                  = (Optional) - The route table to associate, as `{ id = "..." }`. Not allowed on `AzureBastionSubnet`.
- `service_endpoints`                            = (Optional) - The service endpoints of the subnet.
- `create_network_security_group`                = (Optional) - Whether the subnet gets a group of its own, with the default rules plus `security_rules`. Without it the subnet is associated with the group shared by all subnets. Not allowed on `GatewaySubnet`. Defaults to false.
- `network_security_group_config`                = (Optional) - Only read with `create_network_security_group`. `azure_default = true` keeps just Azure's own default rules plus `security_rules`, and always associates.
- `network_security_group_id`                    = (Optional) - An existing group to associate instead of the shared one. Only read when `create_network_security_group` is false, and not on `AzureBastionSubnet` or `GatewaySubnet`.
- `no_nsg_association`                           = (Optional) - Skip associating a group with the subnet. A group the subnet asked for is still created. Defaults to false.

Accepted but not used, so setting them does nothing: `nat_gateway` (a NAT gateway attaches to every subnet but `GatewaySubnet`), `role_assignments`, `service_endpoint_policies`, `sharing_scope` and `timeouts`.

Example:

```hcl
subnets = {
  "CoreSubnet" = {
    address_prefixes                = ["100.0.1.0/24"]
    default_outbound_access_enabled = false
  }
  "DevopsSubnet" = {
    address_prefixes                = ["100.0.2.0/24"]
    default_outbound_access_enabled = false
    delegate_to                     = "Microsoft.ContainerInstance/containerGroups"
    create_network_security_group   = true
  }
  "ToolingSubnet" = {
    address_prefixes                = ["100.0.3.0/24"]
    default_outbound_access_enabled = false
    create_network_security_group   = true
    network_security_group_config = {
      azure_default = true
    }
  }
  "OtherSubnet" = {
    address_prefixes                = ["100.0.4.0/24"]
    default_outbound_access_enabled = false
    no_nsg_association              = true
  }
  "AzureBastionSubnet" = {
    address_prefixes                = ["100.0.5.0/24"]
    default_outbound_access_enabled = false
  }
}
```
DESCRIPTION

  validation {
    condition     = alltrue([for k, subnet in var.subnets : !(coalesce(subnet.name, k) == "GatewaySubnet" && subnet.create_network_security_group)])
    error_message = "create_network_security_group is not supported on GatewaySubnet: Azure does not support a network security group there, and one can stop the gateway working. Remove it for that subnet."
  }

  validation {
    condition     = alltrue([for _, subnet in var.subnets : try(length(subnet.address_prefixes), 0) > 0])
    error_message = "Each subnet needs at least one entry in `address_prefixes`. The singular `address_prefix` no longer exists, so move its value into `address_prefixes = [...]`."
  }
}

variable "tags" {
  description = "A map of tags to assign to every resource this module creates."
  type        = map(string)
  default     = {}
}

variable "vnet_address_space" {
  description = "The address space that is used by the virtual network."
  type        = list(string)
  default     = ["10.0.0.0/16"]
}

variable "vnet_dns_servers" {
  description = "The DNS servers to be used by the virtual network."
  type        = list(string)
  default     = []
}

variable "vnet_name" {
  description = "The name of the virtual network."
  type        = string
}

variable "private_dns" {
  type = map(object({
    zone_name           = string
    zone_link_enabled   = optional(bool, true)
    zone_link_name      = optional(string)
    resource_group_name = optional(string)
  }))
  default     = null
  description = <<DESCRIPTION
This object describes the private DNS zones to create, and to link to the virtual network.

- `zone_name`           = (Required) - The name of the private DNS zone.
- `zone_link_enabled`   = (Optional) - Whether to link the private DNS zone to the virtual network. Defaults to true.
- `zone_link_name`      = (Optional) - The name of the link. Defaults to `<key>_link`. Changing this forces a new resource to be created.
- `resource_group_name` = (Optional) - The resource group to create the zone in. Defaults to the virtual network's. Changing this forces a new resource to be created.

Example:

```hcl
private_dns = {
  "keyvault" = {
    zone_name = "privatelink.vaultcore.azure.net"
  }
  "blob" = {
    zone_name = "privatelink.blob.core.windows.net"
  }
  "azurecr" = {
    zone_name = "privatelink.azurecr.io"
  }
}
```
DESCRIPTION
}

variable "public_ip" {
  type = object({
    name              = optional(string, null)
    allocation_method = optional(string, "Static")
    ip_version        = optional(string, "IPv4")
    sku               = optional(string, "Standard")
    sku_tier          = optional(string, "Regional")
    zones             = optional(list(string))
  })
  default     = {}
  nullable    = true
  description = <<DESCRIPTION
The public IP created for the NAT gateway. Not used when `natgateway.public_ip_address_id` is set, and set to null it creates none.

- `allocation_method` = (Optional) - Defines the allocation method for this IP address. Possible values are Static or Dynamic, default is Static.
- `ip_version`        = (Optional) - The IP Version to use, IPv6 or IPv4. Changing this forces a new resource to be created. Only static IP address allocation is supported for IPv6, Default is IPv4.
- `name`              = (Optional) - The name of the Public IP. Defaults to `<natgateway.name>-pip`. Changing this forces a new resource to be created.
- `sku`               = (Optional) - The SKU of the Public IP. Accepted values are Basic and Standard. Defaults to Standard. Changing this forces a new resource to be created.
- `sku_tier`          = (Optional) - The SKU Tier that should be used for the Public IP. Possible values are Regional and Global. Defaults to Regional. Changing this forces a new resource to be created.
- `zones`             = (Optional) - The availability zones to allocate the Public IP in. Defaults to the NAT gateway's `zones`. Changing this forces a new resource to be created. Availability Zones are only supported with a Standard SKU and in select regions.
DESCRIPTION
}

variable "subnet_delegations_actions" {
  type        = map(list(string))
  default     = null
  description = "Maps a delegation service name to its actions. Null keeps the built-in table in ./modules/subnet; a map replaces it. Used when a subnet sets `delegate_to` without `delegate_to_actions`."
}
