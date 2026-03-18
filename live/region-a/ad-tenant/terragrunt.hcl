# Azure AD Tenant — live configuration (region-a).
# Deploys the ad-tenant module into the active sim tenant.

locals {
  global_vars = read_terragrunt_config(find_in_parent_folders("variables.hcl"))
  customer    = local.global_vars.locals.customer
  provider_id = local.global_vars.locals.provider
  environment = local.global_vars.locals.environment

  # Each sim tenant is a separate Azure AD tenant created manually in the Portal.
  sim_tenant_ids = {
    sim1 = "1ebd14fa-33f0-474d-b9b8-bc87d0a0effe"  # sreazrwussim1.onmicrosoft.com
  }

  # Switch this value to deploy into a different sim tenant.
  active_sim_tenant_id = "1ebd14fa-33f0-474d-b9b8-bc87d0a0effe"
}

include {
  path = find_in_parent_folders("root.hcl")
}

# Override root.hcl provider.tf to add azuread + random providers.
generate "ad_provider" {
  path      = "provider.tf"
  if_exists = "overwrite"
  contents  = <<-EOF
terraform {
  required_version = ">= 1.0"
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 4.35.0"
    }
    azuread = {
      source  = "hashicorp/azuread"
      version = "~> 2.47"
    }
    random = {
      source  = "hashicorp/random"
      version = "~> 3.5"
    }
  }
}

provider "azurerm" {
  features {
    resource_group {
      prevent_deletion_if_contains_resources = false
    }
  }
  subscription_id = local.subscription_id
  tenant_id       = local.tenant_id
}

provider "azuread" {
  tenant_id = "${local.active_sim_tenant_id}"
}
EOF
}

terraform {
  source = "../../../modules/ad-tenant"
}

inputs = {
  users_enabled        = true
  user_password_length = 20
  sim_tenant_ids       = local.sim_tenant_ids

  # Organizations to provision. Add/remove orgs here.
  # Each org creates: 5 env × 3 role security groups, 3 users, 15 memberships.
  #
  # To deploy all 3 orgs:
  #   tenant_orgs = {
  #     northwind = { code = "nw" }
  #     contoso   = { code = "cs" }
  #     fabrikam  = { code = "fk" }
  #   }
  tenant_orgs = {
    northwind = { code = "nw" }
  }

  # Orgs whose users get assigned to the NX Cloud enterprise app.
  # Example with contoso: nxcloud_assigned_orgs = ["contoso"]
  nxcloud_assigned_orgs = []

  nxcloud_saml_login_urls = {
    sim1 = "https://test1.cloud.hwd.mx/sso/realms/default"
  }

  nxcloud_saml_acs_urls = {}

  sim_tenant_upn_domains = {
    sim1 = "sreazrwussim1.onmicrosoft.com"
  }

  tags = {
    ManagedBy   = "terragrunt"
    Module      = "ad-tenant"
    Environment = local.environment
    Customer    = local.customer
    Region      = "wus"
    CostCenter  = "sre-platform"
  }
}
