terraform {
  backend "azurerm" {
    resource_group_name  = "rg-retailmax-tfstate"
    storage_account_name = "stretailmaxtfstate"
    container_name       = "tfstate"
    key                  = "dev.terraform.tfstate"
  }
}
