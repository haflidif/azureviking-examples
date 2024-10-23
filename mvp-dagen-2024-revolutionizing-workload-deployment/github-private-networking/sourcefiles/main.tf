# Creating Random id to append to the resource group name
resource "random_id" "rg" {
  byte_length = 4
}

resource "azurerm_resource_group" "this" {
  name     = "rg-${var.resource_group_name}-${lower(random_id.rg.hex)}"
  location = var.location
  tags     = var.tags
}