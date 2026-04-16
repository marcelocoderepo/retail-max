terraform {
  required_version = ">= 1.5.0"
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 4.0"
    }
    azuread = {
      source  = "hashicorp/azuread"
      version = "~> 3.0"
    }
    databricks = {
      source  = "databricks/databricks"
      version = "~> 1.50"
    }
  }
}

provider "azurerm" {
  features {}
  subscription_id = var.subscription_id
}

locals {
  env  = "prd"
  tags = {
    project     = "retailmax"
    environment = local.env
    managed_by  = "terraform"
    cost_center = "data-engineering"
  }
}

module "resource_group" {
  source   = "../../modules/resource-group"
  name     = "rg-retailmax-${local.env}"
  location = var.location
  tags     = local.tags
}

module "networking" {
  source              = "../../modules/networking"
  resource_group_name = module.resource_group.name
  location            = var.location
  env                 = local.env
  vnet_address_space  = "10.1.0.0/16"
  tags                = local.tags
}

module "keyvault" {
  source              = "../../modules/keyvault"
  resource_group_name = module.resource_group.name
  location            = var.location
  env                 = local.env
  subnet_id           = module.networking.private_endpoints_subnet_id
  tags                = local.tags
}

module "storage" {
  source              = "../../modules/storage"
  resource_group_name = module.resource_group.name
  location            = var.location
  env                 = local.env
  subnet_id           = module.networking.private_endpoints_subnet_id
  tags                = local.tags
}

module "databricks" {
  source              = "../../modules/databricks"
  resource_group_name = module.resource_group.name
  location            = var.location
  env                 = local.env
  vnet_id             = module.networking.vnet_id
  public_subnet_name  = module.networking.dbx_public_subnet_name
  private_subnet_name = module.networking.dbx_private_subnet_name
  public_subnet_nsg_association_id  = module.networking.dbx_public_nsg_association_id
  private_subnet_nsg_association_id = module.networking.dbx_private_nsg_association_id
  tags                = local.tags
}

module "data_factory" {
  source              = "../../modules/data-factory"
  resource_group_name = module.resource_group.name
  location            = var.location
  env                 = local.env
  tags                = local.tags
}

module "identity" {
  source                     = "../../modules/identity"
  env                        = local.env
  resource_group_id          = module.resource_group.id
  keyvault_id                = module.keyvault.id
  storage_account_id         = module.storage.id
  databricks_id              = module.databricks.workspace_id
  data_factory_principal_id  = module.data_factory.identity_principal_id
}

module "monitoring" {
  source              = "../../modules/monitoring"
  resource_group_name = module.resource_group.name
  resource_group_id   = module.resource_group.id
  location            = var.location
  env                 = local.env
  data_factory_id     = module.data_factory.id
  databricks_id       = module.databricks.workspace_id
  monthly_budget      = var.monthly_budget
  alert_emails        = ["massdatagcp@gmail.com"]
  tags                = local.tags
}

module "dns_zones" {
  source              = "../../modules/dns-zones"
  resource_group_name = module.resource_group.name
  vnet_id             = module.networking.vnet_id
  env                 = local.env
  tags                = local.tags
}

module "policy" {
  source            = "../../modules/policy"
  subscription_id   = var.subscription_id
  env               = local.env
  required_tags     = ["project", "environment", "managed_by", "cost_center"]
  allowed_locations = [var.location]
  enforce_policies  = false # Audit-only (Databricks managed resources lack tags)
}
