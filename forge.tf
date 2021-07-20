resource "azurerm_container_registry" "forge" {
  name                = replace("${var.resource_group}forge", "/[^a-zA-Z0-9]/", "")
  resource_group_name = data.azurerm_resource_group.aks.name
  location            = data.azurerm_resource_group.aks.location
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
