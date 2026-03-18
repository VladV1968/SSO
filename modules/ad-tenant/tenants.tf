# Azure AD Tenant Module — locals and identity hierarchy.
#
# Hierarchy:
#   Tenant → Organizations → Environments → Security Groups / Users
#
# Naming:
#   Tenant:   sim<n>
#   Group:    sg-sim<n>-<code>-<env>-<role>
#   User UPN: sim<n>-<code>-<role>@<upn_domain>
#   Domain:   <code>.<tenant>.tenants.cloud.hwd.mx

locals {
  customer    = "sre"
  provider_id = "azr"
  region      = "wus"
  base        = "sre-azr-wus"

  environments = ["dev", "tst", "qa", "qa2", "prd"]
  roles        = ["admin", "user", "viewer"]

  # Tenant seeds — add new tenants here; all downstream resources auto-generate.
  # Orgs are injected via var.tenant_orgs (shared across all tenants).
  tenant_seeds = {
    sim1 = {
      label = "sim1"
      orgs  = var.tenant_orgs
    }
  }

  # Only tenants with a UPN domain in var.sim_tenant_upn_domains are provisioned.
  active_tenant_seeds = {
    for k, v in local.tenant_seeds : k => v
    if contains(keys(var.sim_tenant_upn_domains), k)
  }

  # Full identity hierarchy per active tenant.
  simulated_tenants = {
    for tenant_key, seed in local.active_tenant_seeds : tenant_key => {
      tenant_name = seed.label

      orgs = {
        for company, org_cfg in seed.orgs : company => {
          code   = org_cfg.code
          domain = "${org_cfg.code}.${seed.label}.tenants.cloud.hwd.mx"

          envs = {
            for env in local.environments : env => {
              identifier = "org-${seed.label}-${org_cfg.code}-${env}"
              cp_service = "cp-${env}"

              groups = {
                for role in local.roles :
                role => "sg-${seed.label}-${org_cfg.code}-${env}-${role}"
              }

              users = {
                for role in local.roles :
                role => "${seed.label}-${org_cfg.code}-${role}@${lookup(var.sim_tenant_upn_domains, tenant_key, "${tenant_key}.onmicrosoft.com")}"
              }
            }
          }
        }
      }
    }
  }

  # ── Flattened resource maps for Terraform for_each ─────────────────────────

  # Key: "<tenant_key>-<company>-<env>-<role>"
  flat_groups = merge([
    for tenant_key, tenant in local.simulated_tenants : merge([
      for company, org in tenant.orgs : merge([
        for env, env_cfg in org.envs : {
          for role, group_name in env_cfg.groups :
          "${tenant_key}-${company}-${env}-${role}" => {
            display_name = group_name
            tenant_key   = tenant_key
            company      = company
            env          = env
            role         = role
          }
        }
      ]...)
    ]...)
  ]...)

  # Key: "<tenant_key>-<company>-<role>"
  flat_users = merge([
    for tenant_key, tenant in local.simulated_tenants : merge([
      for company, org in tenant.orgs : {
        for role, upn in org.envs["dev"].users :
        "${tenant_key}-${company}-${role}" => {
          upn        = upn
          domain     = org.domain
          tenant_key = tenant_key
          company    = company
          code       = org.code
          role       = role
        }
      }
    ]...)
  ]...)

  # Key: "<tenant_key>-<company>-<env>-<role>"
  flat_memberships = merge([
    for tenant_key, tenant in local.simulated_tenants : merge([
      for company, org in tenant.orgs : merge([
        for env, env_cfg in org.envs : {
          for role in local.roles :
          "${tenant_key}-${company}-${env}-${role}" => {
            tenant_key = tenant_key
            company    = company
            env        = env
            role       = role
            group_key  = "${tenant_key}-${company}-${env}-${role}"
            user_key   = "${tenant_key}-${company}-${role}"
          }
        }
      ]...)
    ]...)
  ]...)

  # NX Cloud enterprise apps — one per active tenant.
  flat_nxcloud_apps = {
    for tenant_key, tenant in local.simulated_tenants :
    tenant_key => {
      tenant_key = tenant_key
      tenant_id  = lookup(var.sim_tenant_ids, tenant_key, "")
      login_url  = lookup(var.nxcloud_saml_login_urls, tenant_key, "")
      acs_url    = lookup(var.nxcloud_saml_acs_urls, tenant_key, "")
    }
  }

  # NX Cloud user assignments — assigns users from var.nxcloud_assigned_orgs to the enterprise app.
  # Key: "<tenant_key>-<org>-<role>"
  flat_nxcloud_user_assignments = merge([
    for tenant_key, _ in local.simulated_tenants : {
      for pair in setproduct(var.nxcloud_assigned_orgs, local.roles) :
      "${tenant_key}-${pair[0]}-${pair[1]}" => {
        tenant_key = tenant_key
        user_key   = "${tenant_key}-${pair[0]}-${pair[1]}"
      }
      if contains(keys(var.tenant_orgs), pair[0])
    }
  ]...)
}
