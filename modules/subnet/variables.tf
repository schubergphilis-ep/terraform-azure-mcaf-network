variable "name" {
  type        = string
  description = "Name of the subnet. Changing this forces a new resource to be created."
  nullable    = false
}

variable "resource_group_name" {
  type        = string
  description = "Name of the resource group holding the virtual network. Subnets are created in the same resource group as their virtual network, and so is any network security group this module creates."
  nullable    = false
}

variable "virtual_network_name" {
  type        = string
  description = "Name of the virtual network to create the subnet in. The network may be managed elsewhere; this module never creates or modifies it."
  nullable    = false
}

variable "address_prefixes" {
  type        = list(string)
  description = "Address prefixes for the subnet. Changing this forces a new resource to be created."
  nullable    = false

  validation {
    condition     = length(var.address_prefixes) > 0
    error_message = "At least one address prefix is required."
  }
}

variable "tags" {
  type        = map(string)
  default     = null
  description = "Tags for the network security group, when this module creates one."
}

variable "network_security_group" {
  type = object({
    name                  = string
    location              = string
    include_default_rules = optional(bool, true)
    security_rules = optional(map(object({
      name                                       = optional(string)
      priority                                   = number
      direction                                  = string
      access                                     = string
      protocol                                   = string
      description                                = optional(string)
      source_port_ranges                         = set(string)
      destination_port_ranges                    = set(string)
      source_address_prefixes                    = set(string)
      destination_address_prefixes               = set(string)
      source_application_security_group_ids      = optional(set(string))
      destination_application_security_group_ids = optional(set(string))
      timeouts = optional(object({
        create = optional(string)
        delete = optional(string)
        read   = optional(string)
        update = optional(string)
      }))
    })), {})
  })
  default     = null
  description = <<-EOT
    A network security group for this module to create and associate with the subnet, in
    `resource_group_name` next to the virtual network, with the rules ./modules/nsg builds: its
    default rules unless `include_default_rules` is false, `security_rules` on top, and Azure
    Bastion's for a subnet named AzureBastionSubnet. To associate a group that exists already, use
    `network_security_group_id` instead.
  EOT

  validation {
    condition     = var.network_security_group == null || alltrue([for rule in values(var.network_security_group.security_rules) : alltrue([for list in [rule.source_port_ranges, rule.destination_port_ranges, rule.source_address_prefixes, rule.destination_address_prefixes] : length(list) > 0])])
    error_message = "Every rule needs at least one entry in each of source_port_ranges, destination_port_ranges, source_address_prefixes and destination_address_prefixes."
  }
}

variable "network_security_group_id" {
  type        = string
  default     = null
  description = <<-EOT
    The ID of a network security group that exists already, to associate with the subnet. Nothing
    else is done to it. Use `network_security_group` instead to have one created. A subnet needs
    one or the other, except GatewaySubnet, which takes neither.
  EOT

  validation {
    condition     = var.network_security_group_id == null || var.network_security_group == null
    error_message = "Give network_security_group, to create a group, or network_security_group_id, to associate an existing one, not both."
  }

  validation {
    condition     = var.name == "GatewaySubnet" || var.network_security_group != null || var.network_security_group_id != null
    error_message = "A subnet needs a network security group: give network_security_group to create one, or network_security_group_id to associate an existing one. Only GatewaySubnet takes none."
  }

  validation {
    condition     = var.name != "GatewaySubnet" || (var.network_security_group == null && var.network_security_group_id == null)
    error_message = "GatewaySubnet takes no network security group: Azure does not support one there."
  }
}

variable "default_rules" {
  type        = any
  default     = null
  description = "Replaces the default rules of a group created here. Null keeps the built-in set. Same shape as `default_rules` in ./modules/nsg, which checks it."
}

variable "azure_bastion_security_rules" {
  type        = any
  default     = null
  description = "Replaces the Azure Bastion rules of a group created here. Null keeps the built-in set. Same shape as `azure_bastion_security_rules` in ./modules/nsg, which checks it."
}

variable "azure_bastion_source_ip_prefixes" {
  type        = set(string)
  default     = null
  description = "Source prefixes allowed by the Bastion Internet rule of a group created here. Null keeps the built-in default, which allows the whole Internet."

  validation {
    condition     = var.azure_bastion_source_ip_prefixes == null || length(var.azure_bastion_source_ip_prefixes) > 0
    error_message = "azure_bastion_source_ip_prefixes needs at least one entry, or null for the default."
  }
}

variable "route_table_id" {
  type        = string
  default     = null
  description = "Route table to associate with the subnet. Never created here — a table is normally shared by several subnets, so it belongs to the caller."
}

variable "default_outbound_access_enabled" {
  type        = bool
  default     = false
  description = "Whether to allow default outbound internet access from the subnet."
}

variable "delegate_to" {
  type        = string
  default     = null
  description = "Service to delegate the subnet to, for example `Microsoft.ContainerInstance/containerGroups`. Changing this forces a new resource to be created."
}

variable "delegate_to_actions" {
  type        = list(string)
  default     = null
  description = "Delegation actions. Defaults to the entry for `delegate_to` in `subnet_delegations_actions`."
}

variable "private_endpoint_network_policies" {
  type        = string
  default     = "Disabled"
  description = "Enable or disable network policies for private endpoints on the subnet. Possible values are `Disabled`, `Enabled`, `NetworkSecurityGroupEnabled` and `RouteTableEnabled`."
}

variable "private_link_service_network_policies_enabled" {
  type        = bool
  default     = true
  description = "Whether network policies for private link service are enabled on the subnet."
}

variable "service_endpoints" {
  type        = set(string)
  default     = null
  description = "Service endpoints to enable on the subnet."
}

variable "subnet_delegations_actions" {
  type = map(list(string))
  default = {
    "GitHub.Network/networkSettings"         = ["Microsoft.Network/virtualNetworks/subnets/action"]
    "Microsoft.ApiManagement/service"        = ["Microsoft.Network/virtualNetworks/subnets/action"]
    "Microsoft.App/environments"             = ["Microsoft.Network/virtualNetworks/subnets/join/action"]
    "Microsoft.App/testClients"              = ["Microsoft.Network/virtualNetworks/subnets/action"]
    "Microsoft.Apollo/npu"                   = ["Microsoft.Network/virtualNetworks/subnets/action"]
    "Microsoft.AVS/PrivateClouds"            = ["Microsoft.Network/virtualNetworks/subnets/action"]
    "Microsoft.AzureCosmosDB/clusters"       = ["Microsoft.Network/virtualNetworks/subnets/action"]
    "Microsoft.BareMetal/AzureHPC"           = ["Microsoft.Network/virtualNetworks/subnets/action"]
    "Microsoft.BareMetal/AzureHostedService" = ["Microsoft.Network/virtualNetworks/subnets/action"]
    "Microsoft.BareMetal/AzurePaymentHSM"    = ["Microsoft.Network/virtualNetworks/subnets/action"]
    "Microsoft.BareMetal/AzureVMware" = [
      "Microsoft.Network/networkinterfaces/*", "Microsoft.Network/virtualNetworks/subnets/join/action"
    ]
    "Microsoft.BareMetal/CrayServers" = [
      "Microsoft.Network/networkinterfaces/*", "Microsoft.Network/virtualNetworks/subnets/join/action"
    ]
    "Microsoft.BareMetal/MonitoringServers"       = ["Microsoft.Network/virtualNetworks/subnets/action"]
    "Microsoft.Batch/batchAccounts"               = ["Microsoft.Network/virtualNetworks/subnets/action"]
    "Microsoft.CloudTest/hostedpools"             = ["Microsoft.Network/virtualNetworks/subnets/action"]
    "Microsoft.CloudTest/images"                  = ["Microsoft.Network/virtualNetworks/subnets/action"]
    "Microsoft.CloudTest/pools"                   = ["Microsoft.Network/virtualNetworks/subnets/action"]
    "Microsoft.Codespaces/plans"                  = ["Microsoft.Network/virtualNetworks/subnets/action"]
    "Microsoft.ContainerInstance/containerGroups" = ["Microsoft.Network/virtualNetworks/subnets/action"]
    "Microsoft.ContainerService/managedClusters"  = ["Microsoft.Network/virtualNetworks/subnets/action"]
    "Microsoft.ContainerService/TestClients"      = ["Microsoft.Network/virtualNetworks/subnets/action"]
    "Microsoft.Databricks/workspaces" = [
      "Microsoft.Network/virtualNetworks/subnets/join/action",
      "Microsoft.Network/virtualNetworks/subnets/prepareNetworkPolicies/action",
      "Microsoft.Network/virtualNetworks/subnets/unprepareNetworkPolicies/action"
    ]
    "Microsoft.DBforMySQL/flexibleServers"      = ["Microsoft.Network/virtualNetworks/subnets/action"]
    "Microsoft.DBforMySQL/servers"              = ["Microsoft.Network/virtualNetworks/subnets/action"]
    "Microsoft.DBforMySQL/serversv2"            = ["Microsoft.Network/virtualNetworks/subnets/action"]
    "Microsoft.DBforPostgreSQL/flexibleServers" = ["Microsoft.Network/virtualNetworks/subnets/action"]
    "Microsoft.DBforPostgreSQL/serversv2"       = ["Microsoft.Network/virtualNetworks/subnets/join/action"]
    "Microsoft.DBforPostgreSQL/singleServers"   = ["Microsoft.Network/virtualNetworks/subnets/action"]
    "Microsoft.DelegatedNetwork/controller"     = ["Microsoft.Network/virtualNetworks/subnets/action"]
    "Microsoft.DevCenter/networkConnection"     = ["Microsoft.Network/virtualNetworks/subnets/action"]
    "Microsoft.DevOpsInfrastructure/pools"      = ["Microsoft.Network/virtualNetworks/subnets/join/action"]
    "Microsoft.DocumentDB/cassandraClusters"    = ["Microsoft.Network/virtualNetworks/subnets/action"]
    "Microsoft.Fidalgo/networkSettings"         = ["Microsoft.Network/virtualNetworks/subnets/action"]
    "Microsoft.HardwareSecurityModules/dedicatedHSMs" = [
      "Microsoft.Network/networkinterfaces/*", "Microsoft.Network/virtualNetworks/subnets/join/action"
    ]
    "Microsoft.Kusto/clusters"                       = ["Microsoft.Network/virtualNetworks/subnets/action"]
    "Microsoft.LabServices/labplans"                 = ["Microsoft.Network/virtualNetworks/subnets/action"]
    "Microsoft.Logic/integrationServiceEnvironments" = ["Microsoft.Network/virtualNetworks/subnets/action"]
    "Microsoft.MachineLearningServices/workspaces"   = ["Microsoft.Network/virtualNetworks/subnets/action"]
    "Microsoft.Netapp/volumes" = [
      "Microsoft.Network/networkinterfaces/*", "Microsoft.Network/virtualNetworks/subnets/join/action"
    ]
    "Microsoft.Network/applicationGateways"          = ["Microsoft.Network/virtualNetworks/subnets/join/action"]
    "Microsoft.Network/dnsResolvers"                 = ["Microsoft.Network/virtualNetworks/subnets/join/action"]
    "Microsoft.Network/fpgaNetworkInterfaces"        = ["Microsoft.Network/virtualNetworks/subnets/action"]
    "Microsoft.Network/managedResolvers"             = ["Microsoft.Network/virtualNetworks/subnets/action"]
    "Microsoft.Network/networkWatchers."             = ["Microsoft.Network/virtualNetworks/subnets/action"]
    "Microsoft.Network/virtualNetworkGateways"       = ["Microsoft.Network/virtualNetworks/subnets/action"]
    "Microsoft.Orbital/orbitalGateways"              = ["Microsoft.Network/virtualNetworks/subnets/action"]
    "Microsoft.PowerPlatform/enterprisePolicies"     = ["Microsoft.Network/virtualNetworks/subnets/action"]
    "Microsoft.PowerPlatform/vnetaccesslinks"        = ["Microsoft.Network/virtualNetworks/subnets/action"]
    "Microsoft.ServiceFabricMesh/networks"           = ["Microsoft.Network/virtualNetworks/subnets/action"]
    "Microsoft.ServiceNetworking/trafficControllers" = ["Microsoft.Network/virtualNetworks/subnets/action"]
    "Microsoft.Singularity/accounts/networks"        = ["Microsoft.Network/virtualNetworks/subnets/action"]
    "Microsoft.Singularity/accounts/npu"             = ["Microsoft.Network/virtualNetworks/subnets/action"]
    "Microsoft.Sql/managedInstances" = [
      "Microsoft.Network/virtualNetworks/subnets/join/action",
      "Microsoft.Network/virtualNetworks/subnets/prepareNetworkPolicies/action",
      "Microsoft.Network/virtualNetworks/subnets/unprepareNetworkPolicies/action"
    ]
    "Microsoft.Sql/managedInstancesOnebox"    = ["Microsoft.Network/virtualNetworks/subnets/action"]
    "Microsoft.Sql/managedInstancesStage"     = ["Microsoft.Network/virtualNetworks/subnets/action"]
    "Microsoft.Sql/managedInstancesTest"      = ["Microsoft.Network/virtualNetworks/subnets/action"]
    "Microsoft.Sql/servers"                   = ["Microsoft.Network/virtualNetworks/subnets/action"]
    "Microsoft.StoragePool/diskPools"         = ["Microsoft.Network/virtualNetworks/subnets/action"]
    "Microsoft.StreamAnalytics/streamingJobs" = ["Microsoft.Network/virtualNetworks/subnets/join/action"]
    "Microsoft.Synapse/workspaces"            = ["Microsoft.Network/virtualNetworks/subnets/action"]
    "Microsoft.Web/hostingEnvironments"       = ["Microsoft.Network/virtualNetworks/subnets/action"]
    "Microsoft.Web/serverFarms"               = ["Microsoft.Network/virtualNetworks/subnets/action"]
    "NGINX.NGINXPLUS/nginxDeployments"        = ["Microsoft.Network/virtualNetworks/subnets/action"]
    "PaloAltoNetworks.Cloudngfw/firewalls"    = ["Microsoft.Network/virtualNetworks/subnets/action"]
    "Qumulo.Storage/fileSystems"              = ["Microsoft.Network/virtualNetworks/subnets/action"]
  }
  nullable    = false
  description = "Maps a delegation service name to its actions, used when `delegate_to` is set without `delegate_to_actions`. Passing null keeps this built-in table; a map replaces it."

}
