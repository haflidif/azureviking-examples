data "terraform_remote_state" "dev-box" {
  backend = "azurerm"
  config = {
    subscription_id      = var.remote_state_config["subscription_id"]
    resource_group_name  = var.remote_state_config["resource_group_name"]
    storage_account_name = var.remote_state_config["storage_account_name"]
    container_name       = var.remote_state_config["container_name"]
    key                  = var.remote_state_config["key"]
  }
}