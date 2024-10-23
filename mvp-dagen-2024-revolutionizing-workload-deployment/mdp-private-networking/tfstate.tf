# Creating a Resource Group for the Terraform State storageaccount.
resource "azurerm_resource_group" "tfstate" {
  location = var.region
  name     = "rg-tfstate-${random_string.name.result}-${var.suffix}"
  tags = {
    "hidden-title" = "tfstate-demo-pipeline-test-resources-${var.suffix}"
  }
}

# Creating a Storage Account for the Terraform State file.
resource "azapi_resource" "tfstate" {
  type      = "Microsoft.Storage/storageAccounts@2023-05-01"
  name      = "state${random_string.name.result}${replace(var.suffix, "-", "")}"
  parent_id = azurerm_resource_group.tfstate.id
  location  = var.region
  body = {
    kind = "StorageV2"
    sku = {
      name = "Standard_LRS"
    }
    properties = {
      allowBlobPublicAccess = false
      publicNetworkAccess   = "Disabled"
      networkAcls = {
        defaultAction = "Deny"
        bypass        = "AzureServices"
      }
    }
  }
}

# Creating a Container to store the Terraform State File.
resource "azapi_resource" "tfstate_container" {
  type      = "Microsoft.Storage/storageAccounts/blobServices/containers@2023-05-01"
  name      = "tfstate"
  parent_id = "${azapi_resource.tfstate.id}/blobServices/default"
  body = {
    properties = {
      publicAccess = "None"
    }
  }
}

# Creating a Private Endpoint for the Storage Account.
resource "azurerm_private_endpoint" "this" {
  location            = azurerm_resource_group.tfstate.location
  name                = "pe-tfstate-${random_string.name.result}-${var.suffix}"
  resource_group_name = azurerm_resource_group.tfstate.name
  subnet_id           = module.virtual_network.subnets["subnet1"].resource_id
  private_service_connection {
    name                           = "psc-tfstate-${random_string.name.result}-${var.suffix}"
    private_connection_resource_id = azapi_resource.tfstate.id
    subresource_names              = ["blob"]
    is_manual_connection           = false
  }
  private_dns_zone_group {
    name                 = "pdzg-tfstate-${random_string.name.result}-${var.suffix}"
    private_dns_zone_ids = [data.terraform_remote_state.dev-box.outputs.private_dns_zones["privatelink.blob.core.windows.net"].resource_id]
  }
}

# Assigning the Storage Blob Data Owner to the User Assigned Identity.
resource "azurerm_role_assignment" "blob_owner" {
  scope                = azapi_resource.tfstate.id
  role_definition_name = "Storage Blob Data Owner"
  principal_id         = azurerm_user_assigned_identity.this.principal_id
}