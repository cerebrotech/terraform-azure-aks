resource "azurerm_container_registry" "forge" {
  name                = replace("${local.resource_group.name}forge", "/[^a-zA-Z0-9]/", "")
  resource_group_name = local.resource_group.name
  location            = local.resource_group.location
  sku                 = var.registry_tier
  admin_enabled       = false

  // Premium only
  public_network_access_enabled = var.registry_tier == "Premium" ? false : true

  retention_policy {
    enabled = var.registry_tier == "Premium" ? true : false
    days    = 7
  }
}

resource "azurerm_role_assignment" "aks-forge-acr" {
  scope                = azurerm_container_registry.forge.id
  role_definition_name = "AcrPush"
  principal_id         = azurerm_kubernetes_cluster.aks.kubelet_identity[0].object_id
}
