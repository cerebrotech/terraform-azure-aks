provider "azurerm" {
  version = ">=2.7.0"
  features {}
}

terraform {
  backend "azurerm" {
    resource_group_name  = "dominoterraform"
    storage_account_name = "dominoterraformstorage"
    container_name       = "tfstate"
    key                  = "dev.terraform.tfstate"
  }
}

locals {
  cluster_name   = var.cluster_name != null ? var.cluster_name : terraform.workspace
  resource_group = var.resource_group_name != null ? data.azurerm_resource_group.k8s[0] : azurerm_resource_group.k8s[0]

  # Terraform doesn't accept backslash escapes inside the replace function here for some reason,
  # nor does it allow for single quotes. This does, somehow, work, but messes up syntax highlighting.
  storage_account_name = var.storage_account_name != null ? var.storage_account_name : substr("${replace(local.cluster_name, "/[_-]/", "")}dominostorage", 0, 24)
}
#" this comment is to fix syntax highlighting


data "azurerm_resource_group" "k8s" {
  count = var.resource_group_name != null ? 1 : 0
  name  = var.resource_group_name
}

resource "azurerm_resource_group" "k8s" {
  count    = var.resource_group_name == null ? 1 : 0
  name     = local.cluster_name
  location = var.location
}

resource "random_id" "log_analytics_workspace_name_suffix" {
  byte_length = 8
}

resource "azurerm_log_analytics_workspace" "logs" {
  # The WorkSpace name has to be unique across the whole of azure, not just the current subscription/tenant.
  name                = "${var.log_analytics_workspace_name}-${random_id.log_analytics_workspace_name_suffix.dec}"
  location            = var.log_analytics_workspace_location
  resource_group_name = local.resource_group.name
  sku                 = var.log_analytics_workspace_sku
}

resource "azurerm_log_analytics_solution" "logs" {
  solution_name         = "ContainerInsights"
  location              = azurerm_log_analytics_workspace.logs.location
  resource_group_name   = local.resource_group.name
  workspace_resource_id = azurerm_log_analytics_workspace.logs.id
  workspace_name        = azurerm_log_analytics_workspace.logs.name

  plan {
    publisher = "Microsoft"
    product   = "OMSGallery/ContainerInsights"
  }
}

resource "azurerm_kubernetes_cluster" "aks" {
  lifecycle {
    ignore_changes = [
      default_node_pool[0].node_count
    ]
  }

  name                       = local.cluster_name
  enable_pod_security_policy = false
  location                   = local.resource_group.location
  resource_group_name        = local.resource_group.name
  dns_prefix                 = local.cluster_name
  private_cluster_enabled    = false

  api_server_authorized_ip_ranges = var.api_server_authorized_ip_ranges

  default_node_pool {
    enable_node_public_ip = var.node_pools.platform.enable_node_public_ip
    name                  = "platform"
    node_count            = var.node_pools.platform.max_count
    node_labels           = merge({ "dominodatalab.com/node-pool" : "platform" }, var.node_pools.platform.node_labels)
    vm_size               = var.node_pools.platform.vm_size
    availability_zones    = var.node_pools.platform.zones
    max_pods              = 250
    os_disk_size_gb       = 128
    node_taints           = var.node_pools.platform.node_taints
    enable_auto_scaling   = var.node_pools.platform.enable_auto_scaling
    min_count             = var.node_pools.platform.min_count
    max_count             = var.node_pools.platform.max_count
    tags                  = {}
  }

#  Commented out until we fix loadbalancer public ip provisioning issue, see sp.tf
#  identity {
#    type = "SystemAssigned"
#  }

  service_principal {
    client_id     = azuread_service_principal.sp.application_id
    client_secret = azuread_service_principal_password.sp.value
  }

  addon_profile {
    oms_agent {
      enabled                    = true
      log_analytics_workspace_id = azurerm_log_analytics_workspace.logs.id
    }
  }

  network_profile {
    load_balancer_sku  = "Standard"
    network_plugin     = "azure"
    network_policy     = "calico"
    dns_service_ip     = "100.97.0.10"
    docker_bridge_cidr = "172.17.0.1/16"
    service_cidr       = "100.97.0.0/16"
  }

  tags = merge({ Environment = "Development" }, var.aks_tags)

}

resource "azurerm_kubernetes_cluster_node_pool" "aks" {
  lifecycle {
    ignore_changes = [
      node_count
    ]
  }

  for_each = {
    # Create all node pools except for 'platform' because it is the AKS default
    for key, value in var.node_pools :
    key => value
    if key != "platform"
  }

  enable_node_public_ip = each.value.enable_node_public_ip
  kubernetes_cluster_id = azurerm_kubernetes_cluster.aks.id
  name                  = each.key
  node_count            = each.value.max_count
  vm_size               = each.value.vm_size
  availability_zones    = each.value.zones
  max_pods              = 250
  os_disk_size_gb       = 128
  os_type               = each.value.node_os
  node_labels           = merge({ "dominodatalab.com/node-pool" : each.key }, each.value.node_labels)
  node_taints           = each.value.node_taints
  enable_auto_scaling   = each.value.enable_auto_scaling
  min_count             = each.value.min_count
  max_count             = each.value.max_count
  tags                  = {}
}

resource "azurerm_storage_account" "domino" {
  name                     = local.storage_account_name
  resource_group_name      = local.resource_group.name
  location                 = local.resource_group.location
  account_kind             = "StorageV2"
  account_tier             = var.storage_account_tier
  account_replication_type = var.storage_account_replication_type
  access_tier              = "Hot"
}

resource "azurerm_storage_container" "domino_containers" {
  for_each = {
    for key, value in var.containers :
    key => value
  }

  name                  = substr("${local.cluster_name}-${each.key}", 0, 63)
  storage_account_name  = azurerm_storage_account.domino.name
  container_access_type = each.value.container_access_type

  lifecycle {
    ignore_changes = [
      name
    ]
  }
}
