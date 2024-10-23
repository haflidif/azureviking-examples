locals {
  default_branch          = "refs/heads/main"
  pipeline_file           = "pipeline.yml"
  repository_name         = "example-repo"
  service_connection_name = "mdp-demo-${var.suffix}"

  terraform_demo_files = {
    backend   = "backend.tf",
    main      = "main.tf",
    providers = "providers.tf",
    tfvars    = "terraform.tfvars",
    variables = "variables.tf"
  }
}

# Create a new Azure DevOps Project.
resource "azuredevops_project" "this" {
  name = "mdp-demo-${random_string.name.result}-${var.suffix}"
}

# Creating a new Azure DevOps Git Repository.
resource "azuredevops_git_repository" "this" {
  project_id     = azuredevops_project.this.id
  name           = local.repository_name
  default_branch = local.default_branch
  initialization {
    init_type = "Clean"
  }
}

# Creating a new repository file for each file in the terraform_demo_files map, using the content from the sourcefiles directory.
resource "azuredevops_git_repository_file" "terraform_demo_file" {
  for_each            = local.terraform_demo_files
  repository_id       = azuredevops_git_repository.this.id
  file                = each.value
  content             = file("${path.module}/sourcefiles/${each.value}")
  branch              = local.default_branch
  commit_message      = "[skip ci]"
  overwrite_on_create = true
}

# Creating a Federated Workload Identity Service Connection.
resource "azuredevops_serviceendpoint_azurerm" "this" {
  project_id                             = azuredevops_project.this.id
  service_endpoint_name                  = local.service_connection_name
  description                            = "Managed by Terraform"
  service_endpoint_authentication_scheme = "WorkloadIdentityFederation"
  credentials {
    serviceprincipalid = azurerm_user_assigned_identity.this.client_id
  }
  azurerm_spn_tenantid      = data.azurerm_client_config.this.tenant_id
  azurerm_subscription_id   = data.azurerm_client_config.this.subscription_id
  azurerm_subscription_name = data.azurerm_subscription.this.display_name
}

resource "azuredevops_git_repository_file" "this" {
  repository_id = azuredevops_git_repository.this.id
  file          = local.pipeline_file
  content = templatefile("${path.module}/sourcefiles/${local.pipeline_file}", {
    agent_pool_name     = module.managed_devops_pool.name
    variable_group_name = azuredevops_variable_group.this.name
    service_connection  = azuredevops_serviceendpoint_azurerm.this.service_endpoint_name
  })
  branch              = local.default_branch
  commit_message      = "[skip ci]"
  overwrite_on_create = true
}

resource "azuredevops_variable_group" "this" {
  project_id   = azuredevops_project.this.id
  name         = "tfbackend"
  allow_access = true

  variable {
    name  = "storage_account_name"
    value = azapi_resource.tfstate.name
  }

  variable {
    name  = "container_name"
    value = azapi_resource.tfstate_container.name
  }

  variable {
    name  = "resource_group_name"
    value = azurerm_resource_group.tfstate.name
  }

  variable {
    name  = "key_name"
    value = "terraform.tfstate"
  }

  variable {
    name  = "tfversion"
    value = "latest"
  }

}

# Creating a new Build Definition to use the pipeline.yml file in the repository to deploy the terraform test infrastructure.
resource "azuredevops_build_definition" "this" {
  project_id = azuredevops_project.this.id
  name       = "Example Build Definition"

  ci_trigger {
    use_yaml = true
  }

  repository {
    repo_type   = "TfsGit"
    repo_id     = azuredevops_git_repository.this.id
    branch_name = azuredevops_git_repository.this.default_branch
    yml_path    = local.pipeline_file
  }
}

# Getting the Queue ID for the Managed DevOps Pool, to authorize it to run the Build Definition.
data "azuredevops_agent_queue" "this" {
  project_id = azuredevops_project.this.id
  name       = module.managed_devops_pool.name
  depends_on = [module.managed_devops_pool]
}

# Authorizing the Managed DevOps Pool to run the Build Definition.
resource "azuredevops_pipeline_authorization" "this" {
  project_id  = azuredevops_project.this.id
  resource_id = data.azuredevops_agent_queue.this.id
  type        = "queue"
  pipeline_id = azuredevops_build_definition.this.id
}

# Authorizing the Federated Workload Identity Service Connection to run the Build Definition.
resource "azuredevops_pipeline_authorization" "federated_service_connection" {
  project_id  = azuredevops_project.this.id
  resource_id = azuredevops_serviceendpoint_azurerm.this.id
  type        = "endpoint"
  pipeline_id = azuredevops_build_definition.this.id
}