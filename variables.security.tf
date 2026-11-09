variable "security_rules" {
  type = map(object({
    name                                       = string
    access                                     = string
    description                                = optional(string)
    destination_address_prefix                 = optional(string)
    destination_address_prefixes               = optional(set(string))
    destination_application_security_group_ids = optional(set(string))
    destination_port_range                     = optional(string)
    destination_port_ranges                    = optional(set(string))
    direction                                  = string
    priority                                   = number
    protocol                                   = string
    source_address_prefix                      = optional(string)
    source_address_prefixes                    = optional(set(string))
    source_application_security_group_ids      = optional(set(string))
    source_port_range                          = optional(string)
    source_port_ranges                         = optional(set(string))
    timeouts = optional(object({
      create = optional(string)
      delete = optional(string)
      read   = optional(string)
      update = optional(string)
    }))
  }))
  default     = {}
  nullable    = false
  description = <<DESCRIPTION
    A map of security rules to be created in **every** Network Security Group. The key of the map is the name of the security rule.

  - `access` - (Required) Specifies whether network traffic is allowed or denied. Possible values are `Allow` and `Deny`.
  - `name` - (Required) Name of the network security rule to be created.
  - `description` - (Optional) A description for this rule. Restricted to 140 characters.
  - `destination_address_prefix` - (Optional) CIDR or destination IP range or * to match any IP. Tags such as `VirtualNetwork`, `AzureLoadBalancer` and `Internet` can also be used. Besides, it also supports all available Service Tags like ‘Sql.WestEurope‘, ‘Storage.EastUS‘, etc. You can list the available service tags with the CLI: ```shell az network list-service-tags --location westcentralus```. For further information please see [Azure CLI
  - `destination_address_prefixes` - (Optional) List of destination address prefixes. Tags may not be used. This is required if `destination_address_prefix` is not specified.
  - `destination_application_security_group_ids` - (Optional) A List of destination Application Security Group IDs
  - `destination_port_range` - (Optional) Destination Port or Range. Integer or range between `0` and `65535` or `*` to match any. This is required if `destination_port_ranges` is not specified.
  - `destination_port_ranges` - (Optional) List of destination ports or port ranges. This is required if `destination_port_range` is not specified.
  - `direction` - (Required) The direction specifies if rule will be evaluated on incoming or outgoing traffic. Possible values are `Inbound` and `Outbound`.
  - `name` - (Required) The name of the security rule. This needs to be unique across all Rules in the Network Security Group. Changing this forces a new resource to be created.
  - `priority` - (Required) Specifies the priority of the rule. The value can be between 100 and 4096. The priority number must be unique for each rule in the collection. The lower the priority number, the higher the priority of the rule.
  - `protocol` - (Required) Network protocol this rule applies to. Possible values include `Tcp`, `Udp`, `Icmp`, `Esp`, `Ah` or `*` (which matches all).
  - `resource_group_name` - (Required) The name of the resource group in which to create the Network Security Rule. Changing this forces a new resource to be created.
  - `source_address_prefix` - (Optional) CIDR or source IP range or * to match any IP. Tags such as `VirtualNetwork`, `AzureLoadBalancer` and `Internet` can also be used. This is required if `source_address_prefixes` is not specified.
  - `source_address_prefixes` - (Optional) List of source address prefixes. Tags may not be used. This is required if `source_address_prefix` is not specified.
  - `source_application_security_group_ids` - (Optional) A List of source Application Security Group IDs
  - `source_port_range` - (Optional) Source Port or Range. Integer or range between `0` and `65535` or `*` to match any. This is required if `source_port_ranges` is not specified.
  - `source_port_ranges` - (Optional) List of source ports or port ranges. This is required if `source_port_range` is not specified.

  ---
  `timeouts` block supports the following:
  - `create` - (Defaults to 30 minutes) Used when creating the Network Security Rule.
  - `delete` - (Defaults to 30 minutes) Used when deleting the Network Security Rule.
  - `read` - (Defaults to 5 minutes) Used when retrieving the Network Security Rule.
  - `update` - (Defaults to 30 minutes) Used when updating the Network Security Rule.

```hcl
security_rules = {
  "test" = {
    access                     = "Allow"
    name                       = "Allow-HTTPS-Internet"
    description                = "Allow HTTPS traffic to the Internet"
    destination_address_prefix = "Internet"
    destination_port_range     = "443"
    direction                  = "Outbound"
    priority                   = 555
    protocol                   = "Tcp"
    source_address_prefix      = "VirtualNetwork"
    source_port_range          = "*"
  }
}
```hcl

  DESCRIPTION
}

variable "default_rules" {
  type = map(object({
    name                                       = string
    access                                     = string
    direction                                  = string
    priority                                   = number
    protocol                                   = string
    description                                = optional(string)
    destination_address_prefix                 = optional(string, null)
    destination_address_prefixes               = optional(set(string), null)
    destination_application_security_group_ids = optional(set(string), null)
    destination_port_range                     = optional(string, null)
    destination_port_ranges                    = optional(set(string), null)
    source_address_prefix                      = optional(string, null)
    source_address_prefixes                    = optional(set(string), null)
    source_application_security_group_ids      = optional(set(string), null)
    source_port_range                          = optional(string, null)
    source_port_ranges                         = optional(set(string), null)
    timeouts = optional(object({
      create = optional(string, "30")
      delete = optional(string, "30")
      read   = optional(string, "5")
      update = optional(string, "30")
    }))
  }))
  default     = null
  description = <<-EOT
    Rules added to every network security group this module makes, except for subnets using
    `network_security_group_config.azure_default`. Null keeps the built-in set listed in
    [./modules/nsg](./modules/nsg/variables.tf); a map replaces it. `security_rules` win over these by name.
  EOT
}

variable "azure_bastion_source_ip_prefixes" {
  description = "The source IP prefixes that can access the Azure Bastion service over HTTPS. Null allows the whole Internet (`0.0.0.0/0`), so narrow it."
  type        = set(string)
  default     = null
}

variable "azure_bastion_security_rules" {
  type = map(object({
    name                                       = string
    access                                     = string
    direction                                  = string
    priority                                   = number
    protocol                                   = string
    description                                = optional(string)
    destination_address_prefix                 = optional(string, null)
    destination_address_prefixes               = optional(set(string), null)
    destination_application_security_group_ids = optional(set(string), null)
    destination_port_range                     = optional(string, null)
    destination_port_ranges                    = optional(set(string), null)
    source_address_prefix                      = optional(string, null)
    source_address_prefixes                    = optional(set(string), null)
    source_application_security_group_ids      = optional(set(string), null)
    source_port_range                          = optional(string, null)
    source_port_ranges                         = optional(set(string), null)
    timeouts = optional(object({
      create = optional(string, "30")
      delete = optional(string, "30")
      read   = optional(string, "5")
      update = optional(string, "30")
    }))
  }))
  default     = null
  description = <<-EOT
    Rules Azure Bastion needs on the AzureBastionSubnet group. Null keeps the built-in set listed in
    [./modules/nsg](./modules/nsg/variables.tf); a map replaces it. `default_rules` and `security_rules` win over
    these by name.
  EOT
}
