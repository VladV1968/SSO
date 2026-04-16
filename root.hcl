# Terragrunt root configuration — remote state, provider generation, global vars.

locals {
  location    = "shared"
  global_vars = read_terragrunt_config("${get_parent_terragrunt_dir()}/variables.hcl")
  customer    = local.global_vars.locals.customer
  provider    = local.global_vars.locals.provider
  environment = local.global_vars.locals.environment
}

remote_state {
  backend = "local"
  config = {
    path = "${get_parent_terragrunt_dir()}/${path_relative_to_include()}/terraform.tfstate"
  }
}

generate "provider" {
  path      = "provider.tf"
  if_exists = "overwrite"
  contents  = <<EOF
terraform {
  required_version = ">= 1.0"
  required_providers {
    keycloak = {
      source  = "mrparkers/keycloak"
      version = "~> 4.4"
    }
    random = {
      source  = "hashicorp/random"
      version = "~> 3.0"
    }
  }
}
EOF
}
