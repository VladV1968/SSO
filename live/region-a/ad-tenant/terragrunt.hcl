# Azure AD Tenant — live configuration (region-a).
# Deploys the ad-tenant module into the active sim tenant.

locals {
  global_vars          = read_terragrunt_config(find_in_parent_folders("variables.hcl"))
  customer             = local.global_vars.locals.customer
  environment          = local.global_vars.locals.environment
  sim_tenant_ids       = local.global_vars.locals.sim_tenant_ids
  active_sim_tenant_id = local.global_vars.locals.active_sim_tenant_id
}

include {
  path = find_in_parent_folders("root.hcl")
}

# Adds azuread + random providers targeting the sim tenant.
# Uses a distinct filename (ad_provider.tf) to avoid being overwritten by root.hcl's
# generate "provider" block which also outputs provider.tf.
generate "ad_provider" {
  path      = "ad_provider.tf"
  if_exists = "overwrite"
  contents  = <<-EOF
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
  nxcloud_assigned_orgs = ["northwind"]

  nxcloud_saml_login_urls = {
    sim2 = "https://test1.cloud.hwd.mx/sso/realms/default"
  }

  nxcloud_saml_acs_urls = {
    sim2 = "https://test1.cloud.hdw.mx/sso/realms/default/broker/4f97ed66-25db-427d-b660-a7fae5f337c4/endpoint"
  }

  sim_tenant_upn_domains = {
    sim2 = "sreazrwussim2.onmicrosoft.com"
  }

  # Tenant seeds — which tenants to provision.
  tenant_seeds = {
    sim2 = { label = "sim2" }
  }

  # SAML Entity ID per tenant (was hardcoded in provisioner).
  nxcloud_saml_entity_ids = {
    sim2 = "https://test1.cloud.hdw.mx/sso/realms/default"
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
  # Given a customer "acme" on Azure West US with one tenant "sim2":
  #
  #   variables.hcl:
  #     customer        = "acme"
  #     provider        = "azr"
  #     environment     = "dev"
  #     subscription_id = "xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx"
  #     tenant_id       = "xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx"
  #
  #   terragrunt.hcl inputs:
  #     tenant_seeds           = { sim2 = { label = "sim2" } }
  #     tenant_orgs            = { widgetco = { code = "wc" } }
  #     sim_tenant_ids         = { sim2 = "xxxxxxxx-..." }
  #     sim_tenant_upn_domains = { sim2 = "acmeazrwussim2.onmicrosoft.com" }
  #     base_domain            = "acme.cloud.hwd.mx"
  #     environments           = ["dev", "stg", "prd"]
  #     usage_location         = "DE"
  #     nxcloud_app_display_name = "ACME Cloud"
  #     nxcloud_saml_entity_ids  = { sim2 = "https://acme.cloud.hwd.mx/sso/realms/default" }
  #     nxcloud_saml_login_urls  = { sim2 = "https://acme.cloud.hwd.mx/sso/realms/default" }
  #     nxcloud_saml_acs_urls    = { sim2 = "https://acme.cloud.hwd.mx/sso/realms/default/broker/azure-ad/endpoint" }
  #
  #   Resulting resources:
  #     UPN domain:      acmeazrwussim2.onmicrosoft.com       (CAF: acme-azr-wus + sim2)
  #     Org domain:      wc.sim2.tenants.acme.cloud.hwd.mx
  #     Security group:  sg-sim2-wc-dev-admin
  #     User UPN:        sim2-wc-admin@acmeazrwussim2.onmicrosoft.com
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
