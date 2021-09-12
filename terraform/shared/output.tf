output "private_dns_id" {
    value = azurerm_private_dns_zone.dns.id
}

output "acr_id" {
    value = azurerm_container_registry.acr.id
}


output "vnet_id" {
    value = azurerm_virtual_network.vnet.id
}

output "vnet_name" {
    value = azurerm_virtual_network.vnet.name
}

output "rg_name" {
    value = azurerm_resource_group.shared.name
}