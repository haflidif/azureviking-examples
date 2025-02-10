<!-- Run `terraform-docs .\private-networking -c .\private-networking\terraform-docs.yml --output-file ..\README.md` to generate the README.md file.-->
# Revolutionizing Workload Deployment in Azure DevOps & GitHub Actions within Private Network - MVP Dagen 2024 - 23-10-2024
I had the pleasure of speaking at the MVP Dagen 2024 event on the 23rd of October 2024. During my talk, I covered the challenges we are facing when deploying infrastructure and applications within the CORP Landing Zone Archetype, I went over few alternatives on how we can solve these challenges, by using Self-Hosted Agents, running on VMs, VMSS, Container Instances, and Container App Jobs. I also introduced two new players in the DevOps Eco-System, Managed DevOps Pools and Private Networking for GitHub Hosted Runners, explaining their background and functionality. Additionally, I demonstrated how Private Networking for GitHub Hosted Runners can be used to secure your GitHub Actions Workflows and how to create a Managed DevOps Pool with access to a Private Network and how to use it in a build pipeline.

This folder contains the code example I used during my demo and some examples on how you can use it in your own environment to start testing out Private Network With GitHub Hosted Runners.

## How to use the code example in your own environment

### Prerequisites

> ### Run the `dev-box` example first to create the necessary resources to use DevBox as a jumpbox to access the Example Storage Account that is created for the remote state configuration that is used , just bear in mind that when you've deployed the dev-box example, you need to create your own DevBox Instance through the [Developer Portal](https://devportal.microsoft.com/)
><br>
<br>

- GitHub Organization with GitHub Teams Plan or Organization that is part of the GitHub Enterprise Cloud.
- Azure Subscription
- Contributor access to the Azure Subscription.
- Permission to Organization to create/delete: Repository, Workflow, Actions, Runner Groups and Runners.
  ```powershell
  gh auth refresh -h github.com -s "admin:org, repo, delete_repo, user:email, read:user"
  ```
- GitHub CLI installed on your machine.
- Terraform installed on your local machine.
- Azure CLI installed on your local machine.
- Be familiar on how to setup a Terraform backend for storing the Terraform state file remoetly, or use the local backend, some examples are provided down below.

### Steps
1. Clone this repository to your local machine.
2. Navigate to the `github-private-networking` directory.
3. Create the `terraform.tfvars` file with your Azure DevOps Organization URL, Personal Access Token, and suffix to use for all resources created, example below.

#### terraform.tfvars
```hcl
azure_devops_personal_access_token = "<Your Azure DevOps Personal Access Token>"
azure_devops_organization_name     = "<Your Azure DevOps Organization Name>" # e.g contoso without https://dev.azure.com/ prefix
suffix                             = "pvtnet" # Or som suffix that you want to use for all resources created.
```
4. If you want to use remote backend for your state file that already exists, (I personally prefer to use a `config` file with the information needed), you can create `config.tfbackend` file with the following content and store under the `github-private-networking` directory, or you can also fill in the information within the `backend "azurerm" {}` block inside the `terraform` block in the `main.tf` file, or just use the local backend by changing the `backend "azurerm" {}` block to `backend "local" {}` in the `main.tf` file, whatever floats your boat :t-rex:

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
