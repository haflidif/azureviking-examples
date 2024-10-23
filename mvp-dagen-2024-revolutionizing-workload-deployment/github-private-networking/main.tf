locals {
  tags = {
    scenario = "private-networking-mvp-dagen"
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

provider "github" {
  owner = var.github_organization_name
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
  tags = merge(local.tags, {
    "hidden-title" = "private-networking-demo-identity-${var.suffix}"
  })
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

locals {
  default_audience_name = "api://AzureADTokenExchange"
  github_issuer_url     = "https://token.actions.githubusercontent.com"
}

# Creating a Federated Identity Credential, which will be used to authenticate the GitHub Private Networking Configuration.
resource "azurerm_federated_identity_credential" "this" {
  name                = "${var.github_organization_name}-${github_repository.this.name}"
  resource_group_name = azurerm_resource_group.identity.name
  audience            = [local.default_audience_name]
  issuer              = local.github_issuer_url
  parent_id           = azurerm_user_assigned_identity.this.id
  subject             = "repo:${var.github_organization_name}/${github_repository.this.name}:ref:refs/heads/main" # repo:azureviking/private-networking-demo-8qfi4i-github:ref:refs/heads/main

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
  tags = merge(local.tags, {
    "hidden-title" = "private-network-demo-${var.suffix}"
  })
}

# Information about the required resource providers.
locals {
  resource_providers_to_register = {
    github_network = {
      resource_provider = "GitHub.Network"
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

resource "azapi_resource" "nsg" {
  type      = "Microsoft.Network/networkSecurityGroups@2024-01-01"
  name      = "nsg-${random_string.name.result}-${var.suffix}"
  parent_id = azurerm_resource_group.this.id
  location  = azurerm_resource_group.this.location
  body = {
    properties = {
      securityRules = [
        {
          name : "AllowVnetOutBoundOverwrite"
          properties : {
            protocol : "TCP"
            sourcePortRange : "*"
            destinationPortRange : "443"
            sourceAddressPrefix : "*"
            destinationAddressPrefix : "VirtualNetwork"
            access : "Allow"
            priority : 200
            direction : "Outbound"
            destinationAddressPrefixes : []
          }
        },
        {
          name : "AllowOutBoundActions"
          properties : {
            protocol : "*"
            sourcePortRange : "*"
            destinationPortRange : "*"
            sourceAddressPrefix : "*"
            access : "Allow"
            priority : 210
            direction : "Outbound"
            destinationAddressPrefixes : [
              "4.175.114.51/32",
              "20.102.35.120/32",
              "4.175.114.43/32",
              "20.72.125.48/32",
              "20.19.5.100/32",
              "20.7.92.46/32",
              "20.232.252.48/32",
              "52.186.44.51/32",
              "20.22.98.201/32",
              "20.246.184.240/32",
              "20.96.133.71/32",
              "20.253.2.203/32",
              "20.102.39.220/32",
              "20.81.127.181/32",
              "52.148.30.208/32",
              "20.14.42.190/32",
              "20.85.159.192/32",
              "52.224.205.173/32",
              "20.118.176.156/32",
              "20.236.207.188/32",
              "20.242.161.191/32",
              "20.166.216.139/32",
              "20.253.126.26/32",
              "52.152.245.137/32",
              "40.118.236.116/32",
              "20.185.75.138/32",
              "20.96.226.211/32",
              "52.167.78.33/32",
              "20.105.13.142/32",
              "20.253.95.3/32",
              "20.221.96.90/32",
              "51.138.235.85/32",
              "52.186.47.208/32",
              "20.7.220.66/32",
              "20.75.4.210/32",
              "20.120.75.171/32",
              "20.98.183.48/32",
              "20.84.200.15/32",
              "20.14.235.135/32",
              "20.10.226.54/32",
              "20.22.166.15/32",
              "20.65.21.88/32",
              "20.102.36.236/32",
              "20.124.56.57/32",
              "20.94.100.174/32",
              "20.102.166.33/32",
              "20.31.193.160/32",
              "20.232.77.7/32",
              "20.102.38.122/32",
              "20.102.39.57/32",
              "20.85.108.33/32",
              "40.88.240.168/32",
              "20.69.187.19/32",
              "20.246.192.124/32",
              "20.4.161.108/32",
              "20.22.22.84/32",
              "20.1.250.47/32",
              "20.237.33.78/32",
              "20.242.179.206/32",
              "40.88.239.133/32",
              "20.121.247.125/32",
              "20.106.107.180/32",
              "20.22.118.40/32",
              "20.15.240.48/32",
              "20.84.218.150/32"
            ]
          }
        },
        {
          name : "AllowOutBoundGitHub"
          properties : {
            protocol : "*"
            sourcePortRange : "*"
            destinationPortRange : "*"
            sourceAddressPrefix : "*"
            access : "Allow"
            priority : 220
            direction : "Outbound"
            destinationAddressPrefixes : [
              "140.82.112.0/20",
              "143.55.64.0/20",
              "185.199.108.0/22",
              "192.30.252.0/22",
              "20.175.192.146/32",
              "20.175.192.147/32",
              "20.175.192.149/32",
              "20.175.192.150/32",
              "20.199.39.227/32",
              "20.199.39.228/32",
              "20.199.39.231/32",
              "20.199.39.232/32",
              "20.200.245.241/32",
              "20.200.245.245/32",
              "20.200.245.246/32",
              "20.200.245.247/32",
              "20.200.245.248/32",
              "20.201.28.144/32",
              "20.201.28.148/32",
              "20.201.28.149/32",
              "20.201.28.151/32",
              "20.201.28.152/32",
              "20.205.243.160/32",
              "20.205.243.164/32",
              "20.205.243.165/32",
              "20.205.243.166/32",
              "20.205.243.168/32",
              "20.207.73.82/32",
              "20.207.73.83/32",
              "20.207.73.85/32",
              "20.207.73.86/32",
              "20.207.73.88/32",
              "20.233.83.145/32",
              "20.233.83.146/32",
              "20.233.83.147/32",
              "20.233.83.149/32",
              "20.233.83.150/32",
              "20.248.137.48/32",
              "20.248.137.49/32",
              "20.248.137.50/32",
              "20.248.137.52/32",
              "20.248.137.55/32",
              "20.26.156.215/32",
              "20.26.156.216/32",
              "20.27.177.113/32",
              "20.27.177.114/32",
              "20.27.177.116/32",
              "20.27.177.117/32",
              "20.27.177.118/32",
              "20.29.134.17/32",
              "20.29.134.18/32",
              "20.29.134.19/32",
              "20.29.134.23/32",
              "20.29.134.24/32",
              "20.87.245.0/32",
              "20.87.245.1/32",
              "20.87.245.4/32",
              "20.87.245.6/32",
              "20.87.245.7/32",
              "4.208.26.196/32",
              "4.208.26.197/32",
              "4.208.26.198/32",
              "4.208.26.199/32",
              "4.208.26.200/32"
            ]
          }
        },
        {
          name : "AllowStorageOutbound"
          properties : {
            protocol : "*"
            sourcePortRange : "*"
            destinationPortRange : "*"
            sourceAddressPrefix : "*"
            destinationAddressPrefix : "Storage"
            access : "Allow"
            priority : 230
            direction : "Outbound"
            destinationAddressPrefixes : []
          }
        }
      ]
    }
  }
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
      name             = "subnet-${random_string.name.result}-${var.suffix}-runners"
      address_prefixes = [var.network_address_prefixes["runners"]]
      delegation = [{
        name = "GitHub.Network.NetworkSettings"
        service_delegation = {
          name = "GitHub.Network/networkSettings"
        }
      }]
      nat_gateway = {
        id = azurerm_nat_gateway.this.id
      }
      network_security_group = {
        id = azapi_resource.nsg.id
      }
    },
    subnet1 = {
      name             = "subnet-${random_string.name.result}-${var.suffix}-pvte"
      address_prefixes = [var.network_address_prefixes["pvte"]]
      nat_gateway = {
        id = azurerm_nat_gateway.this.id
      }
    }
  }
  peerings = {
    "peerToDevBox" = {
      name                                  = "peer-vnet-${random_string.name.result}-${var.suffix}-to-${data.terraform_remote_state.dev-box.outputs.virtual_network_name}"
      remote_virtual_network_resource_id    = data.terraform_remote_state.dev-box.outputs.virtual_network_id
      allow_forwarded_traffic               = true
      allow_gateway_transit                 = true
      allow_virtual_network_access          = true
      do_not_verify_remote_gateways         = false
      enable_only_ipv6_peering              = false
      use_remote_gateways                   = false
      create_reverse_peering                = true
      reverse_name                          = "peer-${data.terraform_remote_state.dev-box.outputs.virtual_network_name}-to-vnet-${random_string.name.result}-${var.suffix}"
      reverse_allow_forwarded_traffic       = false
      reverse_allow_gateway_transit         = false
      reverse_allow_virtual_network_access  = true
      reverse_do_not_verify_remote_gateways = false
      reverse_enable_only_ipv6_peering      = false
      reverse_use_remote_gateways           = false
    }
  }
  enable_telemetry = var.enable_telemetry
}

# Associating the Virtual Network with the Private DNS Zone.
resource "azurerm_private_dns_zone_virtual_network_link" "this" {
  name                  = "${module.virtual_network.name}-link"
  private_dns_zone_name = data.terraform_remote_state.dev-box.outputs.private_dns_zones["privatelink.blob.core.windows.net"].name
  resource_group_name   = data.terraform_remote_state.dev-box.outputs.private_dns_zones["privatelink.blob.core.windows.net"].resource_group_name
  virtual_network_id    = module.virtual_network.resource_id
}

# GitHub Priavte Networking Configuration
resource "azapi_resource" "gh_network_settings" {
  type                      = "GitHub.Network/networkSettings@2024-04-02"
  parent_id                 = azurerm_resource_group.this.id
  name                      = "gh-network-settings-${random_string.name.result}-${var.suffix}"
  schema_validation_enabled = false # We need to disable schema validation as AzAPi doesn't yet support the schema for this resource type.
  location                  = module.virtual_network.resource.location
  response_export_values    = ["*"]
  body = {
    properties = {
      businessId = data.github_organization.this.id
      subnetId   = module.virtual_network.subnets["subnet0"].resource_id
    }
  }

  lifecycle {
    ignore_changes = [
      body.properties.businessId,
      tags
    ]
  }
}

resource "time_sleep" "wait_for_gh_network_settings" {
  depends_on      = [azapi_resource.gh_network_settings]
  create_duration = "15s"
}

output "virtual_network_id" {
  value = module.virtual_network.resource_id
}

output "virtual_network_subnets" {
  value = module.virtual_network.subnets
}

output "github_id" {
  description = "This GitHub ID is used to associate the GitHub Private Networking settings with the Private Networking Configuration on GitHub."
  value       = azapi_resource.gh_network_settings.output.tags["GitHubId"]
  depends_on  = [time_sleep.wait_for_gh_network_settings]
}