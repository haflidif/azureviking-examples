variable "enable_telemetry" {
  type        = bool
  default     = false
  description = <<DESCRIPTION
This variable controls whether or not telemetry is enabled for the module.
For more information see <https://aka.ms/avm/telemetryinfo>.
If it is set to false, then no telemetry will be collected.
DESCRIPTION
}

variable "suffix" {
  type        = string
  description = "The suffix to use for all resources in this demo."
  default     = "pvtnet"
}

variable "region" {
  type        = string
  default     = "uksouth"
  description = <<DESCRIPTION
  The Azure region to deploy all resources in this demo.
  
  Currently supported regions are:
  - eastus
  - eastus2
  - westus2
  - westus3
  - centralus
  - northcentralus
  - australiaeast
  - japaneast
  - francecentral
  - germanywestcentral
  - northeurope
  - norwayeast
  - swedencentral
  - switzerlandnorth
  - uksouth
  - southeastasia
  - koreacentral
DESCRIPTION

  validation {
    condition     = contains(["eastus", "eastus2", "westus2", "westus3", "centralus", "northcentralus", "australiaeast", "japaneast", "francecentral", "germanywestcentral", "northeurope", "norwayeast", "swedencentral", "switzerlandnorth", "uksouth", "southeastasia", "koreacentral"], var.region)
    error_message = "GitHub Private Networking is currently supported in: eastus, eastus2, westus2, westus3, centralus, northcentralus, australiaeast, japaneast, francecentral, germanywestcentral, northeurope, norwayeast, swedencentral, switzerlandnorth, uksouth, southeastasia, koreacentral, please choose one of these regions."
  }
}

variable "github_organization_name" {
  type        = string
  description = "The GitHub organization to use for the demo."
}

variable "remote_state_config" {
  type        = map(string)
  description = "The configuration for the remote state."
}

variable "network_address_prefixes" {
  type = map(string)
  default = {
    virtual_network = "10.32.0.0/16"
    runners         = "10.32.0.0/24"
    pvte            = "10.32.1.0/24"
  }
}
