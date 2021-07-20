terraform {
  required_providers {
    azurerm = {
      version = "~> 2.46"
    }

    random = {
      version = "~> 2.1"
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

variable "api_server_authorized_ip_ranges" {
  type = list(string)
}

variable "tags" {
  type = map(string)
}

resource "azurerm_resource_group" "ci" {
  name     = terraform.workspace
  location = "westus2"
  tags     = var.tags
}

module "aks" {
  source = "./.."

  cluster_name                    = terraform.workspace
  resource_group                  = azurerm_resource_group.ci.name
  api_server_authorized_ip_ranges = var.api_server_authorized_ip_ranges
  tags                            = var.tags
}
