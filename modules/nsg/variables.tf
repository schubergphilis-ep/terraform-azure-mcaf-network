variable "name" {
  type        = string
  description = "Name of the network security group."
  nullable    = false
}

variable "location" {
  type        = string
  description = "Azure region of the network security group."
  nullable    = false
}

variable "resource_group_name" {
  type        = string
  description = "Resource group of the network security group and its rules."
  nullable    = false
}

variable "tags" {
  type        = map(string)
  default     = null
  description = "Tags for the network security group."
}

variable "security_rules" {
  type = map(object({
    name                                       = optional(string)
    access                                     = string
    direction                                  = string
    priority                                   = number
    protocol                                   = string
    description                                = optional(string)
    destination_address_prefixes               = set(string)
    destination_application_security_group_ids = optional(set(string))
    destination_port_ranges                    = set(string)
    source_address_prefixes                    = set(string)
    source_application_security_group_ids      = optional(set(string))
    source_port_ranges                         = set(string)
    timeouts = optional(object({
      create = optional(string)
      delete = optional(string)
      read   = optional(string)
      update = optional(string)
    }))
  }))
  default     = {}
  nullable    = false
  description = "Rules specific to this group. A rule is named by `name`, or by its key when `name` is unset, and replaces a default rule of the same name. Ports and addresses are lists only, and all four lists are required and not empty. `*` and tags such as `VirtualNetwork` go as the single entry of a list, and several entries must be plain ports, ranges or CIDRs."

  validation {
    condition     = alltrue([for rule in values(var.security_rules) : alltrue([for list in [rule.source_port_ranges, rule.destination_port_ranges, rule.source_address_prefixes, rule.destination_address_prefixes] : length(list) > 0])])
    error_message = "Every rule needs at least one entry in each of source_port_ranges, destination_port_ranges, source_address_prefixes and destination_address_prefixes."
  }
}

variable "include_default_rules" {
  type        = bool
  default     = true
  nullable    = false
  description = "Whether to add `default_rules`. False leaves only Azure's own defaults plus `security_rules`."
}

variable "azure_bastion" {
  type        = bool
  default     = false
  nullable    = false
  description = "Whether this group is for AzureBastionSubnet and so needs `azure_bastion_security_rules`."
}

variable "default_rules" {
  type = map(object({
    name                                       = string
    access                                     = string
    direction                                  = string
    priority                                   = number
    protocol                                   = string
    description                                = optional(string)
    destination_address_prefixes               = set(string)
    destination_application_security_group_ids = optional(set(string), null)
    destination_port_ranges                    = set(string)
    source_address_prefixes                    = set(string)
    source_application_security_group_ids      = optional(set(string), null)
    source_port_ranges                         = set(string)
    timeouts = optional(object({
      create = optional(string, "30m")
      delete = optional(string, "30m")
      read   = optional(string, "5m")
      update = optional(string, "30m")
    }))
  }))
  default = {
    "Allow-Https-in-from-vnets" = {
      access                       = "Allow"
      name                         = "Allow-Https-in-from-vnets"
      description                  = "Allow HTTPS traffic from VNets"
      destination_address_prefixes = ["VirtualNetwork"]
      destination_port_ranges      = ["443"]
      direction                    = "Inbound"
      priority                     = 4095
      protocol                     = "Tcp"
      source_address_prefixes      = ["VirtualNetwork"]
      source_port_ranges           = ["*"]
    },
    "Allow-Http-out-to-vnets" = {
      access                       = "Allow"
      name                         = "Allow-Http-out-to-vnets"
      description                  = "Allow HTTP(S) traffic to VNets"
      destination_address_prefixes = ["VirtualNetwork"]
      destination_port_ranges      = ["80", "443"]
      direction                    = "Outbound"
      priority                     = 4095
      protocol                     = "Tcp"
      source_address_prefixes      = ["VirtualNetwork"]
      source_port_ranges           = ["*"]
    },
    "Deny-Any-Any-Any-In" = {
      access                       = "Deny"
      name                         = "Deny-Any-Any-Any-In"
      description                  = "Deny all inbound traffic"
      destination_address_prefixes = ["*"]
      destination_port_ranges      = ["*"]
      direction                    = "Inbound"
      priority                     = 4096
      protocol                     = "*"
      source_address_prefixes      = ["*"]
      source_port_ranges           = ["*"]
    },
    "Deny-Any-Any-Any-Out" = {
      access                       = "Deny"
      name                         = "Deny-Any-Any-Any-Out"
      description                  = "Deny all outbound traffic"
      destination_address_prefixes = ["*"]
      destination_port_ranges      = ["*"]
      direction                    = "Outbound"
      priority                     = 4096
      protocol                     = "*"
      source_address_prefixes      = ["*"]
      source_port_ranges           = ["*"]
    }
  }
  nullable    = false
  description = <<-EOT
  Rules added to every group made here unless `include_default_rules` is false. Keyed by any name;
  `name` is the rule's name in Azure. Passing a map replaces this set rather than extending it, and
  null keeps it. Rules from `security_rules` win over these by name.
  EOT

  validation {
    condition     = alltrue([for rule in values(var.default_rules) : alltrue([for list in [rule.source_port_ranges, rule.destination_port_ranges, rule.source_address_prefixes, rule.destination_address_prefixes] : length(list) > 0])])
    error_message = "Every rule needs at least one entry in each of source_port_ranges, destination_port_ranges, source_address_prefixes and destination_address_prefixes."
  }
}

variable "azure_bastion_source_ip_prefixes" {
  description = "Source prefixes allowed by Allow-Https-in-from-Internet when `azure_bastion` is true. The default allows the whole Internet, so narrow it."
  type        = set(string)
  default     = ["0.0.0.0/0"]
  nullable    = false

  validation {
    condition     = length(var.azure_bastion_source_ip_prefixes) > 0
    error_message = "azure_bastion_source_ip_prefixes needs at least one entry."
  }
}

variable "azure_bastion_security_rules" {
  type = map(object({
    name                                       = string
    access                                     = string
    direction                                  = string
    priority                                   = number
    protocol                                   = string
    description                                = optional(string)
    destination_address_prefixes               = set(string)
    destination_application_security_group_ids = optional(set(string), null)
    destination_port_ranges                    = set(string)
    source_address_prefixes                    = set(string)
    source_application_security_group_ids      = optional(set(string), null)
    source_port_ranges                         = set(string)
    timeouts = optional(object({
      create = optional(string, "30m")
      delete = optional(string, "30m")
      read   = optional(string, "5m")
      update = optional(string, "30m")
    }))
  }))
  default = {
    "Allow-Https-in-from-Internet" = {
      access                       = "Allow"
      name                         = "Allow-Https-in-from-Internet"
      description                  = "Allow HTTPS traffic from the Internet"
      destination_address_prefixes = ["*"]
      destination_port_ranges      = ["443"]
      direction                    = "Inbound"
      priority                     = 4040
      protocol                     = "Tcp"
      source_address_prefixes      = ["Internet"] # replaced by azure_bastion_source_ip_prefixes
      source_port_ranges           = ["*"]
    },
    "Allow-Https-in-from-GatewayManager" = {
      access                       = "Allow"
      name                         = "Allow-Https-in-from-GatewayManager"
      description                  = "Allow HTTPS traffic from the GatewayManager"
      destination_address_prefixes = ["*"]
      destination_port_ranges      = ["443"]
      direction                    = "Inbound"
      priority                     = 4041
      protocol                     = "Tcp"
      source_address_prefixes      = ["GatewayManager"]
      source_port_ranges           = ["*"]
    },
    "Allow-DataPlane-in-from-VirtualNetwork" = {
      access                       = "Allow"
      name                         = "Allow-DataPlane-in-from-VirtualNetwork"
      description                  = "Allow DataPlane traffic from the VirtualNetwork"
      destination_address_prefixes = ["VirtualNetwork"]
      destination_port_ranges      = ["8080"]
      direction                    = "Inbound"
      priority                     = 4042
      protocol                     = "Tcp"
      source_address_prefixes      = ["VirtualNetwork"]
      source_port_ranges           = ["*"]
    },
    "Allow-DataPlane-in-from-VirtualNetwork-5701" = {
      access                       = "Allow"
      name                         = "Allow-DataPlane-in-from-VirtualNetwork-5701"
      description                  = "Allow DataPlane traffic from the VirtualNetwork on port 5701"
      destination_address_prefixes = ["VirtualNetwork"]
      destination_port_ranges      = ["5701"]
      direction                    = "Inbound"
      priority                     = 4043
      protocol                     = "Tcp"
      source_address_prefixes      = ["VirtualNetwork"]
      source_port_ranges           = ["*"]
    },
    "Allow-Https-in-from-AzureLoadBalancer" = {
      access                       = "Allow"
      name                         = "Allow-Https-in-from-AzureLoadBalancer"
      description                  = "Allow HTTPS traffic from the AzureLoadBalancer"
      destination_address_prefixes = ["*"]
      destination_port_ranges      = ["443"]
      direction                    = "Inbound"
      priority                     = 4044
      protocol                     = "Tcp"
      source_address_prefixes      = ["AzureLoadBalancer"]
      source_port_ranges           = ["*"]
    },
    "Allow-Rdp-out-to-VirtualNetwork" = {
      access                       = "Allow"
      name                         = "Allow-Rdp-out-to-VirtualNetwork"
      description                  = "Allow RDP traffic to the VirtualNetwork"
      destination_address_prefixes = ["VirtualNetwork"]
      destination_port_ranges      = ["3389"]
      direction                    = "Outbound"
      priority                     = 4040
      protocol                     = "Tcp"
      source_address_prefixes      = ["*"]
      source_port_ranges           = ["*"]
    },
    "Allow-Ssh-out-to-VirtualNetwork" = {
      access                       = "Allow"
      name                         = "Allow-Ssh-out-to-VirtualNetwork"
      description                  = "Allow SSH traffic to the VirtualNetwork"
      destination_address_prefixes = ["VirtualNetwork"]
      destination_port_ranges      = ["22"]
      direction                    = "Outbound"
      priority                     = 4041
      protocol                     = "Tcp"
      source_address_prefixes      = ["*"]
      source_port_ranges           = ["*"]
    },
    "Allow-DataPlane-out-to-VirtualNetwork-8080" = {
      access                       = "Allow"
      name                         = "Allow-DataPlane-out-to-VirtualNetwork-8080"
      description                  = "Allow DataPlane traffic to the VirtualNetwork on port 8080"
      destination_address_prefixes = ["VirtualNetwork"]
      destination_port_ranges      = ["8080"]
      direction                    = "Outbound"
      priority                     = 4042
      protocol                     = "Tcp"
      source_address_prefixes      = ["*"]
      source_port_ranges           = ["*"]
    },
    "Allow-DataPlane-out-to-VirtualNetwork-5701" = {
      access                       = "Allow"
      name                         = "Allow-DataPlane-out-to-VirtualNetwork-5701"
      description                  = "Allow DataPlane traffic to the VirtualNetwork on port 5701"
      destination_address_prefixes = ["VirtualNetwork"]
      destination_port_ranges      = ["5701"]
      direction                    = "Outbound"
      priority                     = 4043
      protocol                     = "Tcp"
      source_address_prefixes      = ["*"]
      source_port_ranges           = ["*"]
    },
    "Allow-Https-out-to-AzureCloud" = {
      access                       = "Allow"
      name                         = "Allow-Https-out-to-AzureCloud"
      description                  = "Allow HTTPS traffic to the AzureCloud"
      destination_address_prefixes = ["AzureCloud"]
      destination_port_ranges      = ["443"]
      direction                    = "Outbound"
      priority                     = 4044
      protocol                     = "Tcp"
      source_address_prefixes      = ["*"]
      source_port_ranges           = ["*"]
    },
    "Allow-Http-out-to-Internet" = {
      access                       = "Allow"
      name                         = "Allow-Http-out-to-Internet"
      description                  = "Allow HTTP traffic to the Internet"
      destination_address_prefixes = ["Internet"]
      destination_port_ranges      = ["80"]
      direction                    = "Outbound"
      priority                     = 4045
      protocol                     = "Tcp"
      source_address_prefixes      = ["*"]
      source_port_ranges           = ["*"]
    }
  }
  nullable    = false
  description = <<-EOT
  Rules Azure Bastion needs, added when `azure_bastion` is true. Passing a map replaces this set
  rather than extending it, and null keeps it. Both `default_rules` and `security_rules` win over
  these by name.
  EOT

  validation {
    condition     = alltrue([for rule in values(var.azure_bastion_security_rules) : alltrue([for list in [rule.source_port_ranges, rule.destination_port_ranges, rule.source_address_prefixes, rule.destination_address_prefixes] : length(list) > 0])])
    error_message = "Every rule needs at least one entry in each of source_port_ranges, destination_port_ranges, source_address_prefixes and destination_address_prefixes."
  }
}
