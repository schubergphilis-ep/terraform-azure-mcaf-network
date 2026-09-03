variable "name" {
  type        = string
  description = "Name of the subnet. Changing this forces a new resource to be created."
  nullable    = false
}

variable "resource_group_name" {
  type        = string
  description = "Name of the resource group holding the virtual network. Subnets are created in the same resource group as their virtual network."
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

variable "location" {
  type        = string
  default     = null
  description = "Azure region. Only required when this module creates a network security group; subnets themselves have no location."
}

variable "tags" {
  type        = map(string)
  default     = null
  description = "Tags for the network security group, when this module creates one."
}

variable "network_security_group" {
  type = object({
    id                  = optional(string)
    name                = optional(string)
    resource_group_name = optional(string)
    rules = optional(map(object({
      priority                                   = number
      direction                                  = string
      access                                     = string
      protocol                                   = string
      description                                = optional(string)
      source_port_range                          = optional(string)
      source_port_ranges                         = optional(set(string))
      destination_port_range                     = optional(string)
      destination_port_ranges                    = optional(set(string))
      source_address_prefix                      = optional(string)
      source_address_prefixes                    = optional(set(string))
      destination_address_prefix                 = optional(string)
      destination_address_prefixes               = optional(set(string))
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
    Network security group for the subnet, associated either way. Give `id` to associate a group
    owned elsewhere, and nothing else is done to it. Give `name` instead to have this module create
    the group and its `rules`, in `resource_group_name` or alongside the virtual network. Rule keys
    become rule names.
  EOT

  validation {
    condition = (
      var.network_security_group == null
      || var.network_security_group.id != null
      || var.network_security_group.name != null
    )
    error_message = "network_security_group needs either id, to associate an existing group, or name, to create one."
  }

  validation {
    condition = (
      var.network_security_group == null
      || var.network_security_group.id == null
      || var.network_security_group.name == null
    )
    error_message = "network_security_group takes id or name, not both: an id associates a group owned elsewhere, a name creates one here."
  }

  validation {
    condition = (
      var.network_security_group == null
      || var.network_security_group.id == null
      || length(var.network_security_group.rules) == 0
    )
    error_message = "network_security_group.rules cannot be given alongside id: rules are only created on a group this module owns. Declare them where the group is created."
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
  description = "List of delegation actions when delegations of subnets is used, will be used for querying"

}
