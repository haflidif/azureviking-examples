<!-- BEGIN_TF_DOCS -->
<!-- Run `terraform-docs .\private-networking -c .\private-networking\terraform-docs.yml --output-file ..\README.md` to generate the README.md file.-->
# Introduction to Managed DevOps Pools - Azure User Group Norway - 29-08-2024
I presented at the Azure User Group Norway on August 29, 2024. During my talk, I covered the basics and challenges of using and creating Azure DevOps Build Agents. I also introduced Managed DevOps Pools, an exciting new product now in Public Preview, explaining its background and functionality. Additionally, I demonstrated how to create a Managed DevOps Pool with access to a Private Network and how to use it in a build pipeline.

This repository contains the code example I used during my demo and some examples on how you can use it in your own environment to start testing out Managed DevOps Pools.

## Recording of the Presentation
[![Watch the video](https://img.youtube.com/vi/9e6Q8PSGiXU/0.jpg)](https://www.youtube.com/watch?v=9e6Q8PSGiXU)

## How to use the code example in your own environment

### Prerequisites
- Azure DevOps Organization
- Azure Subscription
- Personal Access Token (PAT) with full access to your Azure DevOps Organization. [How to Create a PAT](https://learn.microsoft.com/en-us/azure/devops/organizations/accounts/use-personal-access-tokens-to-authenticate?wt.mc_id=SEC-MVP-5005265)
- Terraform installed on your local machine.
- Azure CLI installed on your local machine.
- Be familiar on how to setup a Terraform backend for storing the Terraform state file remoetly, or use the local backend, some examples are provided down below.
- Be familiar on how to

### Steps
1. Clone this repository to your local machine.
2. Navigate to the `private-networking` directory.
3. Create the `terraform.tfvars` file with your Azure DevOps Organization URL, Personal Access Token, and suffix to use for all resources created, example below.

#### terraform.tfvars
```hcl
azure_devops_personal_access_token = "<Your Azure DevOps Personal Access Token>"
azure_devops_organization_name     = "<Your Azure DevOps Organization Name>" # e.g contoso without https://dev.azure.com/ prefix
suffix                             = "pvtnet" # Or som suffix that you want to use for all resources created.
```
4. If you want to use remote backend for your state file that already exists, (I personally prefer to use a `config` file with the information needed), you can create `config.tfbackend` file with the following content and store under the `private-networking` directory, or you can also fill in the information within the `backend "azurerm" {}` block inside the `terraform` block in the `main.tf` file, or just use the local backend by changing the `backend "azurerm" {}` block to `backend "local" {}` in the `main.tf` file, whatever floats your boat :t-rex:

#### config.tfbackend
```hcl
subscription_id       = "<Your Azure Subscription ID>"
resource_group_name   = "<Resource Group where the storage account is>"
storage_account_name  = "<Name of the storage account>"
container_name        = "<Name of the conatiner>"
key                   = "terraform.tfstate"
```
`Safe this file as config.tfbackend`

5. Run `terraform init` to initialize the Terraform configuration.
### If using remote backend with config file
```powershell
terraform init -backend-config=".\config.tfbackend"
```
### If using remote or local backend with information in the `main.tf` file
```powershell
terraform init
```

6. Run `terraform plan --out .\terraform.tfplan` to see what resources will be created.
7. Run `terraform apply .\terraform.tfplan` to create the resources.

## To Clean Up
1. Run `terraform plan --destroy --out .\terraform.tfplan` to see what resources will be deleted.
2. Run `terraform apply .\terraform.tfplan` to delete the resources.

## Known Issue when cleaning up.
If you get the following error when trying to run destroy, it's solved by running a second destroy atm.
```powershell
│ Error:  Delete service endpoint error Cannot delete manually created service connection while federated credentials for app
| 12345678-1234-1234-1234-123456789101 exist in Entra tenant 12345678-1234-1234-1234-123456789101. Please make sure federated
| credentials have been removed prior to deleting the service connection.
```

<!-- markdownlint-disable MD033 -->
## Requirements

The following requirements are needed by this module:

- <a name="requirement_terraform"></a> [terraform](#requirement\_terraform) (>= 1.9)

- <a name="requirement_azapi"></a> [azapi](#requirement\_azapi) (~> 1.14)

- <a name="requirement_azuread"></a> [azuread](#requirement\_azuread) (~> 2.53)

- <a name="requirement_azuredevops"></a> [azuredevops](#requirement\_azuredevops) (~> 1.1)

- <a name="requirement_azurerm"></a> [azurerm](#requirement\_azurerm) (~> 3.113)

- <a name="requirement_random"></a> [random](#requirement\_random) (~> 3.5)

## Resources

The following resources are used by this module:

- [azapi_resource.tfstate](https://registry.terraform.io/providers/azure/azapi/latest/docs/resources/resource) (resource)
- [azapi_resource.tfstate_container](https://registry.terraform.io/providers/azure/azapi/latest/docs/resources/resource) (resource)
- [azapi_resource_action.resource_provider_registration](https://registry.terraform.io/providers/azure/azapi/latest/docs/resources/resource_action) (resource)
- [azuredevops_build_definition.this](https://registry.terraform.io/providers/microsoft/azuredevops/latest/docs/resources/build_definition) (resource)
- [azuredevops_git_repository.this](https://registry.terraform.io/providers/microsoft/azuredevops/latest/docs/resources/git_repository) (resource)
- [azuredevops_git_repository_file.terraform_demo_file](https://registry.terraform.io/providers/microsoft/azuredevops/latest/docs/resources/git_repository_file) (resource)
- [azuredevops_git_repository_file.this](https://registry.terraform.io/providers/microsoft/azuredevops/latest/docs/resources/git_repository_file) (resource)
- [azuredevops_pipeline_authorization.federated_service_connection](https://registry.terraform.io/providers/microsoft/azuredevops/latest/docs/resources/pipeline_authorization) (resource)
- [azuredevops_pipeline_authorization.this](https://registry.terraform.io/providers/microsoft/azuredevops/latest/docs/resources/pipeline_authorization) (resource)
- [azuredevops_project.this](https://registry.terraform.io/providers/microsoft/azuredevops/latest/docs/resources/project) (resource)
- [azuredevops_serviceendpoint_azurerm.this](https://registry.terraform.io/providers/microsoft/azuredevops/latest/docs/resources/serviceendpoint_azurerm) (resource)
- [azuredevops_variable_group.this](https://registry.terraform.io/providers/microsoft/azuredevops/latest/docs/resources/variable_group) (resource)
- [azurerm_dev_center.this](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/dev_center) (resource)
- [azurerm_dev_center_project.this](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/dev_center_project) (resource)
- [azurerm_federated_identity_credential.this](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/federated_identity_credential) (resource)
- [azurerm_log_analytics_workspace.this](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/log_analytics_workspace) (resource)
- [azurerm_nat_gateway.this](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/nat_gateway) (resource)
- [azurerm_nat_gateway_public_ip_association.this](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/nat_gateway_public_ip_association) (resource)
- [azurerm_private_dns_zone.this](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/private_dns_zone) (resource)
- [azurerm_private_dns_zone_virtual_network_link.this](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/private_dns_zone_virtual_network_link) (resource)
- [azurerm_private_endpoint.this](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/private_endpoint) (resource)
- [azurerm_public_ip.this](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/public_ip) (resource)
- [azurerm_resource_group.identity](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/resource_group) (resource)
- [azurerm_resource_group.tfstate](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/resource_group) (resource)
- [azurerm_resource_group.this](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/resource_group) (resource)
- [azurerm_role_assignment.blob_owner](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/role_assignment) (resource)
- [azurerm_role_assignment.this](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/role_assignment) (resource)
- [azurerm_role_definition.this](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/role_definition) (resource)
- [azurerm_user_assigned_identity.this](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/user_assigned_identity) (resource)
- [random_string.name](https://registry.terraform.io/providers/hashicorp/random/latest/docs/resources/string) (resource)
- [azuread_service_principal.this](https://registry.terraform.io/providers/hashicorp/azuread/latest/docs/data-sources/service_principal) (data source)
- [azuredevops_agent_queue.this](https://registry.terraform.io/providers/microsoft/azuredevops/latest/docs/data-sources/agent_queue) (data source)
- [azurerm_client_config.this](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/data-sources/client_config) (data source)
- [azurerm_subscription.this](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/data-sources/subscription) (data source)

<!-- markdownlint-disable MD013 -->
## Required Inputs

The following input variables are required:

### <a name="input_azure_devops_organization_name"></a> [azure\_devops\_organization\_name](#input\_azure\_devops\_organization\_name)

Description: Azure DevOps Organisation Name

Type: `string`

### <a name="input_azure_devops_personal_access_token"></a> [azure\_devops\_personal\_access\_token](#input\_azure\_devops\_personal\_access\_token)

Description: The personal access token used for authentication to Azure DevOps.

Type: `string`

## Optional Inputs

The following input variables are optional (have default values):

### <a name="input_enable_telemetry"></a> [enable\_telemetry](#input\_enable\_telemetry)

Description: This variable controls whether or not telemetry is enabled for the module.  
For more information see <https://aka.ms/avm/telemetryinfo>.  
If it is set to false, then no telemetry will be collected.

Type: `bool`

Default: `false`

### <a name="input_region"></a> [region](#input\_region)

Description:   The Azure region to deploy all resources in this demo.  

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

Type: `string`

Default: `"uksouth"`

### <a name="input_suffix"></a> [suffix](#input\_suffix)

Description: The suffix to use for all resources in this demo.

Type: `string`

Default: `"pvtnet"`

## Outputs

The following outputs are exported:

### <a name="output_managed_devops_pool_id"></a> [managed\_devops\_pool\_id](#output\_managed\_devops\_pool\_id)

Description: Outputs

### <a name="output_managed_devops_pool_name"></a> [managed\_devops\_pool\_name](#output\_managed\_devops\_pool\_name)

Description: n/a

### <a name="output_virtual_network_id"></a> [virtual\_network\_id](#output\_virtual\_network\_id)

Description: n/a

### <a name="output_virtual_network_subnets"></a> [virtual\_network\_subnets](#output\_virtual\_network\_subnets)

Description: n/a

## Modules

The following Modules are called:

### <a name="module_managed_devops_pool"></a> [managed\_devops\_pool](#module\_managed\_devops\_pool)

Source: Azure/avm-res-devopsinfrastructure-pool/azurerm

Version: 0.1.1

### <a name="module_virtual_network"></a> [virtual\_network](#module\_virtual\_network)

Source: Azure/avm-res-network-virtualnetwork/azurerm

Version: 0.4.0


# Disclaimer
The code examples in this repository are provided “as-is” and are intended for educational purposes only. They are not suitable for production use and come with no warranty of any kind. Use them at your own risk. I am not responsible for any issues, damages, or costs that may arise from using these code examples.
<!-- END_TF_DOCS -->