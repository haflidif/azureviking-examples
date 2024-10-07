variable "azure_devops_organization_name" {
  type        = string
  description = "Azure DevOps Organisation Name"
}

variable "azure_devops_personal_access_token" {
  type        = string
  description = "The personal access token used for authentication to Azure DevOps."
  sensitive   = true
}

locals {
  tags = {
    scenario = "private-networking"
  }
}

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
    azuredevops = {
      source  = "microsoft/azuredevops"
      version = "~> 1.1"
    }
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 3.113"
    }
    random = {
      source  = "hashicorp/random"
      version = "~> 3.5"
    }
  }

  backend "azurerm" {}

}

provider "azurerm" {
  features {}
}

locals {
  azure_devops_organization_url = "https://dev.azure.com/${var.azure_devops_organization_name}"
}

provider "azuredevops" {
  personal_access_token = var.azure_devops_personal_access_token
  org_service_url       = local.azure_devops_organization_url
}

resource "random_string" "name" {
  length  = 6
  numeric = true
  special = false
  upper   = false
}

# Creating Resource Group for the federated credentials
resource "azurerm_resource_group" "identity" {
  name     = "rg-${random_string.name.result}-identity-${var.suffix}"
  location = var.region
  tags = {
    "hidden-title" = "mdp-demo-identity-${var.suffix}"
  }
}

# Creating a User Assigned Managed Identity to use for the Azure DevOps Service Connection.
resource "azurerm_user_assigned_identity" "this" {
  location            = var.region
  name                = "uai-${random_string.name.result}-${var.suffix}"
  resource_group_name = azurerm_resource_group.identity.name

  lifecycle {
    create_before_destroy = true
  }
}

# Creating a Federated Identity Credential, which will be used to authenticate the Azure DevOps Service Connection.
resource "azurerm_federated_identity_credential" "this" {
  name                = "federated-identity-${random_string.name.result}-${var.suffix}"
  resource_group_name = azurerm_resource_group.identity.name
  parent_id           = azurerm_user_assigned_identity.this.id
  audience            = ["api://AzureADTokenExchange"]
  issuer              = azuredevops_serviceendpoint_azurerm.this.workload_identity_federation_issuer
  subject             = azuredevops_serviceendpoint_azurerm.this.workload_identity_federation_subject

  lifecycle {
    create_before_destroy = true
  }
}

# Creating a Role Assignment for the User Assigned Managed Identity.
resource "azurerm_role_assignment" "this" {
  scope                = data.azurerm_subscription.this.id
  role_definition_name = "Contributor"
  principal_id         = azurerm_user_assigned_identity.this.principal_id
}

# Creating Resource Group for the Managed DevOps Pool and associated resources.
resource "azurerm_resource_group" "this" {
  location = var.region
  name     = "rg-${random_string.name.result}-${var.suffix}"
  tags = {
    "hidden-title" = "mdp-demo-${var.suffix}"
  }
}

# Creating a Log Analytics Workspace for diagnostic logs from the Managed DevOps Pool.
resource "azurerm_log_analytics_workspace" "this" {
  location            = azurerm_resource_group.this.location
  name                = "law-${random_string.name.result}-${var.suffix}"
  resource_group_name = azurerm_resource_group.this.name
}

# Information about the required resource providers.
locals {
  resource_providers_to_register = {
    dev_center = {
      resource_provider = "Microsoft.DevCenter"
    }
    devops_infrastructure = {
      resource_provider = "Microsoft.DevOpsInfrastructure"
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

# Creating a custom role definition for the Virtual Network changes, required for the Managed DevOps Pool.
resource "azurerm_role_definition" "this" {
  name        = "Virtual Network Contributor for DevOpsInfrastructure (${random_string.name.result}-${var.suffix})"
  scope       = azurerm_resource_group.this.id
  description = "Custom Role for Virtual Network Contributor for DevOpsInfrastructure (${random_string.name.result}-${var.suffix})"

  permissions {
    actions = [
      "Microsoft.Network/virtualNetworks/subnets/join/action",
      "Microsoft.Network/virtualNetworks/subnets/serviceAssociationLinks/validate/action",
      "Microsoft.Network/virtualNetworks/subnets/serviceAssociationLinks/write",
      "Microsoft.Network/virtualNetworks/subnets/serviceAssociationLinks/delete"
    ]
  }
}

data "azuread_service_principal" "this" {
  display_name = "DevOpsInfrastructure" # This is a special built in service principal (see: https://learn.microsoft.com/en-us/azure/devops/managed-devops-pools/configure-networking?view=azure-devops&tabs=azure-portal#to-check-the-devopsinfrastructure-principal-access)
  depends_on = [ 
    azapi_resource_action.resource_provider_registration # Ensures that the Resource Provider is registered before querying the service principal, as it's not available until the registration is complete.
  ]
}

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
  address_space       = ["10.30.0.0/16"]
  location            = azurerm_resource_group.this.location
  name                = "vnet-${random_string.name.result}-${var.suffix}"
  resource_group_name = azurerm_resource_group.this.name
  role_assignments = {
    virtual_network_reader = {
      role_definition_id_or_name = "Reader"
      principal_id               = data.azuread_service_principal.this.object_id
    }
    subnet_join = {
      role_definition_id_or_name = azurerm_role_definition.this.role_definition_resource_id
      principal_id               = data.azuread_service_principal.this.object_id
    }
  }
  subnets = {
    subnet0 = {
      name             = "subnet-${random_string.name.result}-${var.suffix}-pool"
      address_prefixes = ["10.30.0.0/24"]
      delegation = [{
        name = "Microsoft.DevOpsInfrastructure.pools"
        service_delegation = {
          name = "Microsoft.DevOpsInfrastructure/pools"
        }
      }]
      nat_gateway = {
        id = azurerm_nat_gateway.this.id
      }
    },
    subnet1 = {
      name             = "subnet-${random_string.name.result}-${var.suffix}-pvte"
      address_prefixes = ["10.30.1.0/24"]
      nat_gateway = {
        id = azurerm_nat_gateway.this.id
      }
    }
  }
  enable_telemetry = var.enable_telemetry
}

# Creating a Private DNS Zone for the Private Endpoint.
resource "azurerm_private_dns_zone" "this" {
  name                = "privatelink.blob.core.windows.net"
  resource_group_name = azurerm_resource_group.this.name
}

# Associating the Virtual Network with the Private DNS Zone.
resource "azurerm_private_dns_zone_virtual_network_link" "this" {
  name                  = "${azurerm_private_dns_zone.this.name}-link"
  private_dns_zone_name = azurerm_private_dns_zone.this.name
  resource_group_name   = azurerm_resource_group.this.name
  virtual_network_id    = module.virtual_network.resource_id
}

# Creating a Dev Center and Project for the Managed DevOps Pool.
resource "azurerm_dev_center" "this" {
  location            = azurerm_resource_group.this.location
  name                = "dc-${random_string.name.result}-${var.suffix}"
  resource_group_name = azurerm_resource_group.this.name

  depends_on = [azapi_resource_action.resource_provider_registration]
}

resource "azurerm_dev_center_project" "this" {
  dev_center_id       = azurerm_dev_center.this.id
  location            = azurerm_resource_group.this.location
  name                = "dcp-${random_string.name.result}-${var.suffix}"
  resource_group_name = azurerm_resource_group.this.name
}

# Creating Managed DevOps Pool with Private Networking using the Azure Verified Module.
module "managed_devops_pool" {
  source                         = "Azure/avm-res-devopsinfrastructure-pool/azurerm"
  version                        = "0.1.1"
  resource_group_name            = azurerm_resource_group.this.name
  location                       = azurerm_resource_group.this.location
  name                           = "mdp-${random_string.name.result}-${var.suffix}"
  dev_center_project_resource_id = azurerm_dev_center_project.this.id
  subnet_id                      = module.virtual_network.subnets["subnet0"].resource_id
  organization_profile = {
    organizations = [{
      name     = var.azure_devops_organization_name
      projects = [azuredevops_project.this.name]
    }]
  }
  enable_telemetry = var.enable_telemetry
  tags             = local.tags
  depends_on = [
    azapi_resource_action.resource_provider_registration,
    module.virtual_network
  ]
}

# Outputs
output "managed_devops_pool_id" {
  value = module.managed_devops_pool.resource_id
}

output "managed_devops_pool_name" {
  value = module.managed_devops_pool.name
}

output "virtual_network_id" {
  value = module.virtual_network.resource_id
}

output "virtual_network_subnets" {
  value = module.virtual_network.subnets
}