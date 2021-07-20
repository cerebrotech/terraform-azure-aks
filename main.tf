locals {
  storage_account_name = substr("${replace(var.cluster_name, "/[_-]/", "")}dominostorage", 0, 24)
}

data "azurerm_subscription" "current" {
}

data "azurerm_resource_group" "aks" {
  name = var.resource_group
}

resource "azurerm_role_assignment" "aks_network" {
  scope                = data.azurerm_subscription.current.id
  role_definition_name = "Network Contributor"
  principal_id         = azurerm_kubernetes_cluster.aks.identity[0].principal_id
}
