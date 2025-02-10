locals {
  private_dns_zones = {
    "blob" = "privatelink.blob.core.windows.net"
  }
}

# Private DNS Zone for the Private Endpoints.
resource "azurerm_resource_group" "dns" {
  name     = "rg-dns-${random_string.name.result}-${var.suffix}"
  location = var.region
  tags = merge(local.tags, {
    "hidden-title" = "dns-resources-${var.suffix}"
  })
}

resource "azurerm_private_dns_zone" "this" {
  for_each            = local.private_dns_zones
  name                = each.value
  resource_group_name = azurerm_resource_group.dns.name
}

# Associating the Virtual Network with the Private DNS Zone.
resource "azurerm_private_dns_zone_virtual_network_link" "this" {
  name                  = "${module.virtual_network.name}-link"
  private_dns_zone_name = azurerm_private_dns_zone.this["blob"].name
  resource_group_name   = azurerm_resource_group.dns.name
  virtual_network_id    = module.virtual_network.resource_id
}

#region Outputs
output "private_dns_zones" {
  description = "Outputs all private dns zones created by the module to use in remote state, and for linking private endpoint connections to the shared private dns zones."
  value = {
    for zone in azurerm_private_dns_zone.this : zone.name => {
      resource_id         = zone.id
      name                = zone.name
      resource_group_name = zone.resource_group_name
    }
  }
}