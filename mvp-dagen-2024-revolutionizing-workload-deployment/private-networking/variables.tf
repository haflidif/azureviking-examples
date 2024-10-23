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
  default     = "swedencentral"
  description = <<DESCRIPTION
  The Azure region to deploy all resources in this demo.
  
  Currently supported regions are:
  - australiaeast
  - brazilsouth
  - canadacentral
  - centralindia
  - centralus
  - eastasia
  - eastus
  - eastus2
  - germanywestcentral
  - italynorth
  - northeurope
  - norwayeast
  - southafricanorth
  - southcentralus
  - southeastasia
  - swedencentral
  - switzerlandnorth
  - uksouth
  - westeurope
  - westus3
DESCRIPTION

  validation {
    condition     = contains(["australiaeast", "brazilsouth", "canadacentral", "centralindia", "centralus", "eastasia", "eastus", "eastus2", "germanywestcentral", "italynorth", "northeurope", "norwayeast", "southafricanorth", "southcentralus", "southeastasia", "swedencentral", "switzerlandnorth", "uksouth", "westeurope", "westus3"], var.region)
    error_message = "Managed DevOps Pools is currently supported in: australiaeast, brazilsouth, canadacentral, centralindia, centralus, eastasia, eastus, eastus2, germanywestcentral, italynorth, northeurope, norwayeast, southafricanorth, southcentralus, southeastasia, swedencentral, switzerlandnorth, uksouth, westeurope, westus3, please choose one of these regions."
  }
}

variable "remote_state_config" {
  type        = map(string)
  description = "The configuration for the remote state."
}

variable "network_address_prefixes" {
  type = map(string)
  default = {
    virtual_network = "10.31.0.0/16"
    pool            = "10.31.0.0/24"
    pvte            = "10.31.1.0/24"
  }
}
