locals {
  cluster_name   = var.cluster_name != null ? var.cluster_name : terraform.workspace
  resource_group = var.resource_group_name != null ? data.azurerm_resource_group.k8s[0] : azurerm_resource_group.k8s[0]

  safe_storage_cluster_name = replace(local.cluster_name, "/[_-]/", "")
  storage_account_name      = var.storage_account_name != null ? var.storage_account_name : substr("${local.safe_storage_cluster_name}dominostorage", 0, 24)

  tags = merge({ "Cluster" : local.cluster_name }, var.tags)
}

data "azurerm_resource_group" "k8s" {
  count = var.resource_group_name != null ? 1 : 0
  name  = var.resource_group_name
}

resource "azurerm_resource_group" "k8s" {
  count    = var.resource_group_name == null ? 1 : 0
  name     = local.cluster_name
  location = var.location
  tags     = local.tags
}

data "azurerm_subscription" "current" {
  subscription_id = var.subscription_id
}

resource "azurerm_role_assignment" "sp" {
  scope                = data.azurerm_subscription.current.id
  role_definition_name = "Network Contributor"
  principal_id         = azurerm_kubernetes_cluster.aks.identity[0].principal_id
}
