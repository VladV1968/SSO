# Azure AD Tenant — live configuration (region-a).
# Deploys the ad-tenant module into the active sim tenant.

locals {
  global_vars = read_terragrunt_config(find_in_parent_folders("variables.hcl"))
  customer    = local.global_vars.locals.customer
  environment = local.global_vars.locals.environment

  # Each sim tenant is a separate Azure AD tenant created manually in the Portal.
  sim_tenant_ids = {
    sim1 = "1ebd14fa-33f0-474d-b9b8-bc87d0a0effe"  # sreazrwussim1.onmicrosoft.com
  }

  # Switch this value to deploy into a different sim tenant.
  active_sim_tenant_id = local.sim_tenant_ids["sim1"]
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
  subscription_id = "${local.global_vars.locals.subscription_id}"
  tenant_id       = "${local.global_vars.locals.tenant_id}"
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
  # To deploy other orgs e.g. contoso and fabrikam, add them to the tenant_orgs map:
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

  nxcloud_saml_acs_urls = {
    sim1 = "https://test1.cloud.hwd.mx/sso/realms/default/broker/azure-ad/endpoint"
  }

  sim_tenant_upn_domains = {
    sim1 = "sreazrwussim1.onmicrosoft.com"
  }

  # Tenant seeds — which tenants to provision.
  tenant_seeds = {
    sim1 = { label = "sim1" }
  }

  # SAML Entity ID per tenant (was hardcoded in provisioner).
  nxcloud_saml_entity_ids = {
    sim1 = "https://test1.cloud.hwd.mx/sso/realms/default"
  }

  # Override defaults for customer deployments (uncomment as needed):
  # environments             = ["dev", "tst", "qa", "qa2", "prd"]
  # roles                    = ["admin", "user", "viewer"]
  # base_domain              = "cloud.hwd.mx"
  # group_prefix             = "sg"
  # usage_location           = "US"
  # nxcloud_app_display_name = "nx cloud"
  #
  # ── Customer deployment example ──────────────────────────────────────────
  # CAF naming: {customer}-{provider}-{region}-{environment}-{service}-{resource}
  #
  # Given a customer "acme" on Azure West US with one tenant "sim1":
  #
  #   variables.hcl:
  #     customer        = "acme"
  #     provider        = "azr"
  #     environment     = "dev"
  #     subscription_id = "xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx"
  #     tenant_id       = "xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx"
  #
  #   terragrunt.hcl inputs:
  #     tenant_seeds           = { sim1 = { label = "sim1" } }
  #     tenant_orgs            = { widgetco = { code = "wc" } }
  #     sim_tenant_ids         = { sim1 = "xxxxxxxx-..." }
  #     sim_tenant_upn_domains = { sim1 = "acmeazrwussim1.onmicrosoft.com" }
  #     base_domain            = "acme.cloud.hwd.mx"
  #     environments           = ["dev", "stg", "prd"]
  #     usage_location         = "DE"
  #     nxcloud_app_display_name = "ACME Cloud"
  #     nxcloud_saml_entity_ids  = { sim1 = "https://acme.cloud.hwd.mx/sso/realms/default" }
  #     nxcloud_saml_login_urls  = { sim1 = "https://acme.cloud.hwd.mx/sso/realms/default" }
  #     nxcloud_saml_acs_urls    = { sim1 = "https://acme.cloud.hwd.mx/sso/realms/default/broker/azure-ad/endpoint" }
  #
  #   Resulting resources:
  #     UPN domain:      acmeazrwussim1.onmicrosoft.com       (CAF: acme-azr-wus + sim1)
  #     Org domain:      wc.sim1.tenants.acme.cloud.hwd.mx
  #     Security group:  sg-sim1-wc-dev-admin
  #     User UPN:        sim1-wc-admin@acmeazrwussim1.onmicrosoft.com
  #     Tags:            Customer = "acme", Region = "wus", Environment = "dev"

  tags = {
    ManagedBy   = "terragrunt"
    Module      = "ad-tenant"
    Environment = local.environment
    Customer    = local.customer
    Region      = "wus"
    CostCenter  = "sre-platform"
  }
}
