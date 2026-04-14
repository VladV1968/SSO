# Terragrunt root configuration — remote state, provider generation, global vars.

locals {
  location        = "shared"
  global_vars     = read_terragrunt_config("${get_parent_terragrunt_dir()}/variables.hcl")
  subscription_id = local.global_vars.locals.subscription_id
  tenant_id       = local.global_vars.locals.tenant_id
  customer        = local.global_vars.locals.customer
  provider        = local.global_vars.locals.provider
  environment     = local.global_vars.locals.environment
}

remote_state {
  backend = "azurerm"
  config = {
    resource_group_name  = "rg-sre-azr-eus-dev-str-tf"
    storage_account_name = "sreazreusdevtfstr"
    container_name       = "sreazreusdevstrtfcontainer"
    key                  = "${path_relative_to_include()}/terraform.tfstate"
  }
}

generate "provider" {
  path      = "provider.tf"
  if_exists = "overwrite"
  contents  = <<EOF
terraform {
  required_version = ">= 1.0"
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 4.35.0"
    }
    keycloak = {
      source  = "mrparkers/keycloak"
      version = "~> 4.4"
    }
  }
}

provider "azurerm" {
  features {
    resource_group {
      prevent_deletion_if_contains_resources = false
    }
  }
  subscription_id = "$${local.subscription_id}"
  tenant_id       = "$${local.tenant_id}"
}
EOF
}

generate "locals" {
  path      = "locals.tf"
  if_exists = "overwrite"
  contents  = <<EOF
locals {
  subscription_id = "${local.global_vars.locals.subscription_id}"
  tenant_id       = "${local.global_vars.locals.tenant_id}"
}
EOF
}
