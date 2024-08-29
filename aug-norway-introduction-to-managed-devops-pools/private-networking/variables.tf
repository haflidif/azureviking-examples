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
  - australiaeast
  - brazilsouth
  - canadacentral
  - centralus
  - westeurope
  - northeurope
  - germanywestcentral
  - italynorth
  - uksouth
  - eastus
  - eastus2
  - southafricanorth
  - southcentralus
  - southeastasia
  - switzerlandnorth
  - westus3
  - centralindia
  - eastasia
DESCRIPTION

  validation {
    condition     = contains(["australiaeast", "brazilsouth", "canadacentral", "centralus", "westeurope", "germanywestcentral", "italynorth", "uksouth", "eastus", "eastus2", "southafricanorth", "southcentralus", "southeastasia", "switzerlandnorth", "westus3", "centralindia", "eastasia", "northeurope"], var.region)
    error_message = "Managed DevOps Pools is currently supported in: australiaeast, brazilsouth, canadacentral, centralus, westeurope, germanywestcentral, italynorth, uksouth, eastus, eastus2, southafricanorth, southcentralus, southeastasia, switzerlandnorth, westus3, centralindia, eastasia, northeurope, please choose one of these regions."
  }
}
