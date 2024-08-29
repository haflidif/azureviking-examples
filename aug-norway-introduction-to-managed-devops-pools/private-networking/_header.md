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
- Personal Access Token (PAT) with full access to your Azure DevOps Organization.
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