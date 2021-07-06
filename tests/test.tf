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
  type        = list(string)
}

variable "subscription_id" {
  type        = string
}

variable "tags" {
  type        = map(string)
}

module "aks" {
  source = "./.."

  api_server_authorized_ip_ranges = var.api_server_authorized_ip_ranges
  subscription_id                 = var.subscription_id
  tags                            = var.tags
}
