locals {
  tags = {
    "scenario" = "private-networking-mvp-dagen"
  }
}

#region Terraform Configuration
terraform {
  required_version = ">= 1.9"
  required_providers {
    azapi = {
      source  = "azure/azapi"
      version = "~> 1.14"
    }
    azuread = {
      source  = "hashicorp/azuread"
      version = "~> 2.53"
    }
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 3.113"
    }
    random = {
      source  = "hashicorp/random"
      version = "~> 3.5"
    }
    github = {
      source  = "integrations/github"
      version = "~> 6.3"
    }
  }

  backend "azurerm" {}

}

provider "azurerm" {
  features {}
}

provider "azapi" {}

resource "random_string" "name" {
  length  = 6
  numeric = true
  special = false
  upper   = false
}

#region Resource Group

# Creating Resource Group for the DevCenter and DevBox.
resource "azurerm_resource_group" "this" {
  location = var.region
  name     = "rg-${random_string.name.result}-${var.suffix}"
  tags = merge(local.tags, {
    "hidden-title" = "private-network-demo-${var.suffix}"
  })
}

#region Provider Registration
# Information about the required resource providers.
locals {
  resource_providers_to_register = {
    dev_center = {
      resource_provider = "Microsoft.DevCenter"
    }
  }
}

data "azurerm_client_config" "this" {}

data "azurerm_subscription" "this" {
  subscription_id = data.azurerm_client_config.this.subscription_id
}

# Registering the required resource providers on the subscription, if not already registered.
resource "azapi_resource_action" "resource_provider_registration" {
  for_each = local.resource_providers_to_register

  resource_id = "/subscriptions/${data.azurerm_client_config.this.subscription_id}"
  type        = "Microsoft.Resources/subscriptions@2021-04-01"
  action      = "providers/${each.value.resource_provider}/register"
  method      = "POST"
}

#region Network
# Creating a Public IP and NAT Gateway for the Managed DevOps Pool, as the subnet is created with outbound traffic blocked.
resource "azurerm_public_ip" "this" {
  allocation_method   = "Static"
  location            = azurerm_resource_group.this.location
  name                = "pip-${random_string.name.result}-${var.suffix}"
  resource_group_name = azurerm_resource_group.this.name
  sku                 = "Standard"
}

resource "azurerm_nat_gateway" "this" {
  location            = azurerm_resource_group.this.location
  name                = "nat-${random_string.name.result}-${var.suffix}"
  resource_group_name = azurerm_resource_group.this.name
  sku_name            = "Standard"
}

resource "azurerm_nat_gateway_public_ip_association" "this" {
  nat_gateway_id       = azurerm_nat_gateway.this.id
  public_ip_address_id = azurerm_public_ip.this.id
}

# Creating a Virtual Network with two subnets, one for the Managed DevOps Pool and one for the Private Endpoint.
module "virtual_network" {
  source              = "Azure/avm-res-network-virtualnetwork/azurerm"
  version             = "0.4.0"
  address_space       = [var.network_address_prefixes["virtual_network"]]
  location            = azurerm_resource_group.this.location
  name                = "vnet-${random_string.name.result}-${var.suffix}"
  resource_group_name = azurerm_resource_group.this.name
  subnets = {
    subnet0 = {
      name             = "subnet-${random_string.name.result}-${var.suffix}"
      address_prefixes = [var.network_address_prefixes["subnet_0"]]
      nat_gateway = {
        id = azurerm_nat_gateway.this.id
      }
    }
  }
  enable_telemetry = var.enable_telemetry
}

output "virtual_network_name" {
  value = module.virtual_network.name
}

output "virtual_network_id" {
  value = module.virtual_network.resource_id
}

output "virtual_network_subnets" {
  value = module.virtual_network.subnets
}

#region DevCenter
resource "azapi_resource" "devcenter" {
  type      = "Microsoft.DevCenter/devcenters@2024-08-01-preview"
  name      = "dc-${random_string.name.result}-${var.suffix}"
  parent_id = azurerm_resource_group.this.id
  location  = azurerm_resource_group.this.location
  identity {
    type = "SystemAssigned"
  }

  body = {
    properties = {
    }
  }
  response_export_values = ["*"]
}

#region DevBox Definition

locals {
  devbox_definitions = {
    "dbd-win11-gen2" = {
      hibernatesupport = "Disabled"
      osstoragetype    = "ssd_256gb"
      skuname          = "general_i_8c32gb256ssd_v2"
      imagereferenceid = "microsoftvisualstudio_windowsplustools_base-win11-gen2"
    }
    "dbd-win11-gen2-hibernate" = {
      hibernatesupport = "Enabled"
      osstoragetype    = "ssd_256gb"
      skuname          = "general_i_8c32gb256ssd_v2"
      imagereferenceid = "microsoftvisualstudio_windowsplustools_base-win11-gen2"
    }
  }
}

resource "azapi_resource" "devbox_definition" {
  for_each  = local.devbox_definitions
  type      = "Microsoft.DevCenter/devcenters/devboxdefinitions@2024-08-01-preview"
  name      = each.key
  location  = azurerm_resource_group.this.location
  parent_id = azapi_resource.devcenter.id
  body = {
    properties = {
      hibernateSupport = each.value.hibernatesupport
      imageReference = {
        id = "${azapi_resource.devcenter.id}/galleries/default/images/${each.value.imagereferenceid}"
      }
      osStorageType = each.value.osstoragetype
      sku = {
        name = each.value.skuname
      }
    }
  }
}

#region DevBox Pool
resource "azapi_resource" "devcenter_project" {
  type      = "Microsoft.DevCenter/projects@2024-08-01-preview"
  name      = "dcp-${random_string.name.result}-${var.suffix}"
  parent_id = azurerm_resource_group.this.id
  location  = azurerm_resource_group.this.location

  body = {
    properties = {
      description        = "Devbox project for the ${local.tags.scenario}"
      maxDevBoxesPerUser = 2
      devCenterId        = azapi_resource.devcenter.id
    }
  }
  response_export_values = ["*"]
}

resource "azapi_resource" "network_connection" {
  type      = "Microsoft.DevCenter/networkConnections@2024-08-01-preview"
  name      = "nc-${random_string.name.result}-${var.suffix}"
  location  = azurerm_resource_group.this.location
  parent_id = azurerm_resource_group.this.id
  body = {
    properties = {
      domainJoinType              = "AzureADJoin"
      networkingResourceGroupName = "${azurerm_resource_group.this.name}-nic"
      subnetId                    = module.virtual_network.subnets["subnet0"].resource_id
    }
  }
}

resource "azapi_resource" "attached_networks" {
  type      = "Microsoft.DevCenter/devcenters/attachednetworks@2024-08-01-preview"
  name      = "anw-${random_string.name.result}-${var.suffix}"
  parent_id = azapi_resource.devcenter.id
  body = {
    properties = {
      networkConnectionId = azapi_resource.network_connection.id
    }
  }
}

resource "azapi_resource" "dbpool" {
  for_each  = local.devbox_definitions
  type      = "Microsoft.DevCenter/projects/pools@2024-08-01-preview"
  name      = "dbpool-${random_string.name.result}-${var.suffix}-${each.key}"
  location  = azurerm_resource_group.this.location
  parent_id = azapi_resource.devcenter_project.id
  body = {
    properties = {
      devBoxDefinitionName  = azapi_resource.devbox_definition[each.key].name
      licenseType           = "Windows_Client"
      localAdministrator    = "Disabled"
      networkConnectionName = azapi_resource.attached_networks.name
      # stopOnDisconnect = {
      #   gracePeriodMinutes = 60
      #   status = "Enabled"
      # }
    }
  }
}

locals {
  poolsschedulestime = "19:00"
}

resource "azapi_resource" "dcschedule" {
  for_each  = local.devbox_definitions
  type      = "Microsoft.DevCenter/projects/pools/schedules@2024-08-01-preview"
  name      = "default"
  parent_id = azapi_resource.dbpool[each.key].id
  body = {
    properties = {
      type      = "StopDevBox",
      frequency = "Daily",
      time      = local.poolsschedulestime,
      timeZone  = "Europe/Oslo",
      state     = "Enabled"
    }
  }
}
