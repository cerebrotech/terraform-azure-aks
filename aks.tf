locals {
  node_pools = {
    for node_pool, attrs in var.node_pools :
    node_pool => merge(attrs, lookup(var.node_pool_overrides, node_pool, {}))
  }
}

data "azurerm_kubernetes_service_versions" "selected" {
  location        = data.azurerm_resource_group.aks.location
  version_prefix  = var.kubernetes_version
  include_preview = false
}

resource "azurerm_kubernetes_cluster" "aks" {
  lifecycle {
    ignore_changes = [
      tags,
      default_node_pool[0].node_count,
      default_node_pool[0].max_count,
      default_node_pool[0].tags,
      # VM Size changes cause recreation of the entire cluster
      default_node_pool[0].vm_size
    ]
  }

  name                    = var.cluster_name
  location                = data.azurerm_resource_group.aks.location
  resource_group_name     = data.azurerm_resource_group.aks.name
  dns_prefix              = var.cluster_name
  private_cluster_enabled = false
  sku_tier                = var.cluster_sku_tier
  kubernetes_version      = data.azurerm_kubernetes_service_versions.selected.latest_version

  api_server_authorized_ip_ranges = var.api_server_authorized_ip_ranges

  default_node_pool {
    enable_node_public_ip = local.node_pools.platform.enable_node_public_ip
    name                  = "platform"
    node_count            = local.node_pools.platform.min_count
    node_labels           = local.node_pools.platform.node_labels
    vm_size               = local.node_pools.platform.vm_size
    availability_zones    = local.node_pools.platform.zones
    os_disk_size_gb       = local.node_pools.platform.os_disk_size_gb
    node_taints           = local.node_pools.platform.node_taints
    enable_auto_scaling   = local.node_pools.platform.enable_auto_scaling
    min_count             = local.node_pools.platform.min_count
    max_count             = local.node_pools.platform.max_count
    max_pods              = local.node_pools.platform.max_pods
    tags                  = var.tags
  }

  identity {
    type = "SystemAssigned"
  }

  addon_profile {
    kube_dashboard {
      enabled = false
    }

    oms_agent {
      enabled                    = true
      log_analytics_workspace_id = azurerm_log_analytics_workspace.logs.id
    }
  }

  network_profile {
    load_balancer_sku = "Standard"
    network_plugin    = "azure"
    network_policy    = "calico"
  }

  tags = var.tags
}

resource "azurerm_kubernetes_cluster_node_pool" "aks" {
  lifecycle {
    ignore_changes = [node_count, max_count, tags]
  }

  for_each = {
    # Create all node pools except for 'platform' because it is the AKS default
    for key, value in local.node_pools :
    key => value
    if key != "platform"
  }

  enable_node_public_ip = each.value.enable_node_public_ip
  kubernetes_cluster_id = azurerm_kubernetes_cluster.aks.id
  name                  = each.key
  node_count            = each.value.min_count
  vm_size               = each.value.vm_size
  availability_zones    = each.value.zones
  os_disk_size_gb       = each.value.os_disk_size_gb
  os_type               = each.value.node_os
  node_labels           = each.value.node_labels
  node_taints           = each.value.node_taints
  enable_auto_scaling   = each.value.enable_auto_scaling
  min_count             = each.value.min_count
  max_count             = each.value.max_count
  max_pods              = each.value.max_pods
  tags                  = var.tags
}
