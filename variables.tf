variable "api_server_authorized_ip_ranges" {
  type        = list(string)
  description = "The IP ranges to whitelist for incoming traffic to the masters"
}

variable "cluster_name" {
  type        = string
  description = "The Domino cluster name for the K8s cluster and resource group"
}

variable "cluster_sku_tier" {
  type        = string
  default     = null
  description = "The Domino cluster SKU (defaults to Free)"
}

variable "containers" {
  type = map(object({
    container_access_type = string
  }))

  default = {
    backups = {
      container_access_type = "private"
    }
  }
}

variable "resource_group" {
  type        = string
  description = "Name of optional pre-existing resource group to install AKS in"
}

# refer https://azure.microsoft.com/pricing/details/monitor/ for log analytics pricing
variable "log_analytics_workspace_sku" {
  default = "PerGB2018"
}

variable "node_pools" {
  type = map(object({
    enable_node_public_ip = bool
    vm_size               = string
    zones                 = list(string)
    node_labels           = map(string)
    node_os               = string
    node_taints           = list(string)
    enable_auto_scaling   = bool
    min_count             = number
    max_count             = number
    max_pods              = number
    os_disk_size_gb       = number
  }))
  default = {
    compute = {
      enable_node_public_ip = false
      vm_size               = "Standard_D8s_v4"
      zones                 = ["1", "2", "3"]
      node_labels = {
        "dominodatalab.com/node-pool" = "default"
      }
      node_os             = "Linux"
      node_taints         = []
      enable_auto_scaling = true
      min_count           = 0
      max_count           = 10
      max_pods            = 30
      os_disk_size_gb     = 128
    }
    gpu = {
      enable_node_public_ip = false
      vm_size               = "Standard_NC6s_v3"
      zones                 = []
      node_labels = {
        "dominodatalab.com/node-pool" = "default-gpu"
        "nvidia.com/gpu"              = "true"
      }
      node_os = "Linux"
      node_taints = [
        "nvidia.com/gpu=true:NoExecute"
      ]
      enable_auto_scaling = true
      min_count           = 0
      max_count           = 1
      max_pods            = 30
      os_disk_size_gb     = 128
    }
    platform = {
      enable_node_public_ip = false
      vm_size               = "Standard_D8s_v4"
      zones                 = ["1", "2", "3"]
      node_labels = {
        "dominodatalab.com/node-pool" = "platform"
      }
      node_os             = "Linux"
      node_taints         = []
      enable_auto_scaling = true
      min_count           = 1
      max_count           = 3
      max_pods            = 60
      os_disk_size_gb     = 128
    }
  }
}

variable "node_pool_overrides" {
  type    = map(map(any))
  default = {}
}

variable "storage_account_tier" {
  type    = string
  default = "Standard"
}

variable "storage_account_replication_type" {
  type    = string
  default = "LRS"
}

variable "tags" {
  type        = map(string)
  default     = {}
  description = "Tags to apply to resources"
}

variable "kubernetes_version" {
  type        = string
  default     = null
  description = "Optional Kubernetes version to provision. Allows partial input (e.g. 1.18) which is then chosen from azurerm_kubernetes_service_versions."
}

variable "registry_tier" {
  type    = string
  default = "Standard"
}
