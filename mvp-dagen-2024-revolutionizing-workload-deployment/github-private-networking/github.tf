data "github_organization" "this" {
  name = var.github_organization_name
}

output "database_id" {
  description = "When querying GitHub Organization, the ID of the organization is the same as the database ID."
  value       = data.github_organization.this.id
}

#region GitHub Repository

locals {
  default_branch  = "refs/heads/main"
  repository_name = "terraform-${random_string.name.result}-${var.suffix}-example-repo"
}

resource "github_repository" "this" {
  name                 = "private-networking-demo-${random_string.name.result}-${var.suffix}"
  description          = "This repository is used to demonstrate the use GitHub Runners with Private Networking to deploy Terraform Infrastructure."
  auto_init            = true
  vulnerability_alerts = true
  visibility           = "private"
}

#region GitHub Actions variables
locals {
  github_action_variables = {
    ARM_CLIENT_ID                                = "${azurerm_user_assigned_identity.this.client_id}",
    ARM_SUBSCRIPTION_ID                          = "${data.azurerm_client_config.this.subscription_id}",
    ARM_TENANT_ID                                = "${data.azurerm_client_config.this.tenant_id}",
    BACKEND_AZURE_RESOURCE_GROUP_NAME            = "${azurerm_resource_group.tfstate.name}",
    BACKEND_AZURE_STORAGE_ACCOUNT_NAME           = "${azapi_resource.tfstate.name}",
    BACKEND_AZURE_STORAGE_ACCOUNT_CONTAINER_NAME = "${azapi_resource.tfstate_container.name}"
  }
}

# Creating GitHub Actions variables for the repository.
resource "github_actions_variable" "this" {
  for_each      = local.github_action_variables
  repository    = github_repository.this.name
  variable_name = each.key
  value         = each.value
}

#region GitHub Action Runner Group
resource "github_actions_runner_group" "this" {
  name                    = "private-networking-runners-${random_string.name.result}-${var.suffix}"
  selected_repository_ids = [github_repository.this.repo_id]
  visibility              = "selected"
}

#region GitHub Repository Files

locals {
  workflow_private_network_name = "terraform_private_network.yml"
  workflow_standard_name        = "terraform_standard.yml"
  terraform_demo_files = {
    backend   = "backend.tf",
    main      = "main.tf",
    providers = "providers.tf",
    tfvars    = "terraform.tfvars",
    variables = "variables.tf"
  }
}

# Creating a new repository file for each file in the terraform_demo_files map, using the content from the sourcefiles directory.
resource "github_repository_file" "this" {
  for_each            = local.terraform_demo_files
  repository          = github_repository.this.name
  file                = each.value
  content             = file("${path.module}/sourcefiles/${each.value}")
  branch              = local.default_branch
  commit_message      = "[skip ci]"
  overwrite_on_create = true
}

resource "github_repository_file" "workflow_private_network" {
  repository = github_repository.this.name
  file       = ".github/workflows/${local.workflow_private_network_name}"
  content = templatefile("${path.module}/sourcefiles/${local.workflow_private_network_name}", {
    github_runner_group = github_actions_runner_group.this.name
  })
  branch              = local.default_branch
  commit_message      = "[skip ci]"
  overwrite_on_create = true
}

resource "github_repository_file" "workflow_standard" {
  repository          = github_repository.this.name
  file                = ".github/workflows/${local.workflow_standard_name}"
  content             = file("${path.module}/sourcefiles/${local.workflow_standard_name}")
  branch              = local.default_branch
  commit_message      = "[skip ci]"
  overwrite_on_create = true
}

# resource "azuredevops_git_repository_file" "this" {
#   repository_id = azuredevops_git_repository.this.id
#   file          = local.pipeline_file
#   content = templatefile("${path.module}/sourcefiles/${local.pipeline_file}", {
#     agent_pool_name     = module.managed_devops_pool.name
#     variable_group_name = azuredevops_variable_group.this.name
#     service_connection  = azuredevops_serviceendpoint_azurerm.this.service_endpoint_name
#   })
#   branch              = local.default_branch
#   commit_message      = "[skip ci]"
#   overwrite_on_create = true
# }