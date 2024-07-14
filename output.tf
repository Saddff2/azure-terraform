data "azurerm_public_ip" "master_pips" {
  count               = var.masters_count
  name                = azurerm_public_ip.k8s-master-pip[count.index].name
  resource_group_name = azurerm_resource_group.az-k8s-cluster.name
}

data "azurerm_public_ip" "worker_pips" {
  count               = var.workers_count
  name                = azurerm_public_ip.k8s-worker-pip[count.index].name
  resource_group_name = azurerm_resource_group.az-k8s-cluster.name
}

output "master_public_ip_addresses" {
  value = [for pip in data.azurerm_public_ip.master_pips : pip.ip_address]
}

output "worker_public_ip_addresses" {
  value = [for pip in data.azurerm_public_ip.worker_pips : pip.ip_address]
}
