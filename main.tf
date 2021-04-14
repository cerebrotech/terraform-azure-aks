terraform {
  required_providers {
    azurerm = {
      version = "~> 2.46"
    }
  }

  backend "azurerm" {
    resource_group_name  = "dominoterraform"
    storage_account_name = "dominoterraformstorage"
    container_name       = "tfstate"
    key                  = "dev.terraform.tfstate"
  }
}

provider "azurerm" {
  partner_id = "31912fbf-f6dd-5176-bffb-0a01e8ac71f2"
  features {}
}

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

resource "azurerm_role_assignment" "sp" {
  scope                = var.resource_group_name != null ? data.azurerm_resource_group.k8s[0].id : azurerm_resource_group.k8s[0].id
  role_definition_name = "Contributor"
  principal_id         = azurerm_kubernetes_cluster.aks.identity[0].principal_id
}
