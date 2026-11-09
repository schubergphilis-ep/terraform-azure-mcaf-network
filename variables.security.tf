variable "security_rules" {
  type = map(object({
    name                                       = string
    access                                     = string
    description                                = optional(string)
    destination_address_prefixes               = optional(set(string), [])
    destination_application_security_group_ids = optional(set(string))
    destination_port_ranges                    = optional(set(string), [])
    direction                                  = string
    priority                                   = number
    protocol                                   = string
    source_address_prefixes                    = optional(set(string), [])
    source_application_security_group_ids      = optional(set(string))
    source_port_ranges                         = optional(set(string), [])
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
Rules added to every network security group this module creates, the shared one included, on top of `default_rules`. A rule replaces a default or Bastion rule with the same `name`. The attributes are those of `azurerm_network_security_rule`, minus `resource_group_name` and `network_security_group_name`, which are set for you, and with ports and addresses as lists only: `source_port_ranges`, `destination_port_ranges`, `source_address_prefixes` and `destination_address_prefixes`, each needing at least one entry. `*` and tags such as `VirtualNetwork` are accepted by Azure only on their own, so give them as the single entry of a list; several entries must be plain ports, ranges or CIDRs. `timeouts` take durations such as `30m`. The key is free-form.

```hcl
security_rules = {
  "test" = {
    access                       = "Allow"
    name                         = "Allow-HTTPS-Internet"
    description                  = "Allow HTTPS traffic to the Internet"
    destination_address_prefixes = ["Internet"]
    destination_port_ranges      = ["443"]
    direction                    = "Outbound"
    priority                     = 555
    protocol                     = "Tcp"
    source_address_prefixes      = ["VirtualNetwork"]
    source_port_ranges           = ["*"]
  }
}
```
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
    destination_address_prefixes               = optional(set(string), [])
    destination_application_security_group_ids = optional(set(string), null)
    destination_port_ranges                    = optional(set(string), [])
    source_address_prefixes                    = optional(set(string), [])
    source_application_security_group_ids      = optional(set(string), null)
    source_port_ranges                         = optional(set(string), [])
    timeouts = optional(object({
      create = optional(string, "30m")
      delete = optional(string, "30m")
      read   = optional(string, "5m")
      update = optional(string, "30m")
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
    destination_address_prefixes               = optional(set(string), [])
    destination_application_security_group_ids = optional(set(string), null)
    destination_port_ranges                    = optional(set(string), [])
    source_address_prefixes                    = optional(set(string), [])
    source_application_security_group_ids      = optional(set(string), null)
    source_port_ranges                         = optional(set(string), [])
    timeouts = optional(object({
      create = optional(string, "30m")
      delete = optional(string, "30m")
      read   = optional(string, "5m")
      update = optional(string, "30m")
    }))
  }))
  default     = null
  description = <<-EOT
    Rules Azure Bastion needs on the AzureBastionSubnet group. Null keeps the built-in set listed in
    [./modules/nsg](./modules/nsg/variables.tf); a map replaces it. `default_rules` and `security_rules` win over
    these by name.
  EOT
}
