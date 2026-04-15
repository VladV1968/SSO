terraform {
  backend "azurerm" {
    resource_group_name  = "rg-sre-azr-eus-dev-str-tf"
    storage_account_name = "sreazreusdevtfstr"
    container_name       = "sreazreusdevstrtfcontainer"
    key                  = "core-infra-iac.terraform.tfstate"
    subscription_id      = "0d3a8060-e8d5-4500-aaff-eb67d9f11de9"
    tenant_id            = "8ef7e80b-b6ba-4504-ae0d-29aee51519a3"
  }
}
