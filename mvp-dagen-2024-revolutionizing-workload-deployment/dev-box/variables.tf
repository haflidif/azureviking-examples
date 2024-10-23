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
  default     = "devbox"
}

variable "region" {
  type        = string
  default     = "swedencentral"
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