# ==============================================================================
# AZURE AD TENANT MODULE - LOCALS AND IDENTITY HIERARCHY
# ==============================================================================
# This file defines the complete tenant-first identity hierarchy for simulated
# Azure AD tenants used in multi-tenant, multi-environment isolation scenarios.
#
# HIERARCHY DEPENDENCY CHAIN:
# ┌─────────────────────────────────────────────────────────────────────────────┐
# │  Azure AD Tenant                                                            │
# │    → App Registration                                                       │
# │      → Organizations                                                        │
# │        → Domain                                                             │
# │          → Environment  (dev, tst, qa, qa2, prd)                          │
# │            → CP Service                                                     │
# │              → Security Groups                                              │
# │                → Users                                                      │
# └─────────────────────────────────────────────────────────────────────────────┘
#
# NAMING CONVENTIONS:
# ┌────────────────────────────────────────────────────────────────────────────┐
# │ Resource            │ Pattern                                              │
# ├────────────────────────────────────────────────────────────────────────────┤
# │ Tenant display name │ sim<n>                                               │
# │ App registration    │ appreg-sim<n>-cp                                     │
# │ Organization        │ org-sim<n>-<code>-<env>                              │
# │ Domain              │ <code>.sim<n>.tenants.cloud.hwd.mx                   │
# │ CP service          │ cp-<env>                                             │
# │ Security group      │ sg-sim<n>-<code>-<env>-<role>                        │
# │ User UPN            │ sim<n>-<code>-<role>@<upn_domain>                    │
# └────────────────────────────────────────────────────────────────────────────┘
#
# DESIGN RULES:
# - All names use lowercase letters, numbers, and hyphens only
# - Dimension order: tenant → org → env → role (most-stable to least-stable)
# - Type prefix always first (appreg-, sg-, org-, dom-, cp-) for resource-type scans
# - tenant label = sim<n> (single token, no internal hyphen) to avoid split-on-hyphen
# - org code = 2-char abbreviation for brevity at scale (e.g. nw=northwind, cs=contoso)
# - Domain hierarchy: <code>.<tenant>.tenants. enables per-tenant wildcard cert and DNS delegation
# - Users created once per (tenant, org, role); env scope enforced via group membership
# - UPN domain comes from var.sim_tenant_upn_domains, defaulting to onmicrosoft.com
# - Custom domains require DNS verification before use as UPN suffix
# - appreg- prefix used (not app-) to avoid CAF collision with Microsoft.Web/sites (app-)
# ==============================================================================

locals {
  # ==============================================================================
  # BASE NAMING COMPONENTS
  # ==============================================================================
  # These components form the base of all resource names in this module and
  # align with the enterprise naming convention defined in variables.hcl.
  # Format: {customer}-{provider}-{region}
  # ==============================================================================
  customer    = "sre"
  provider_id = "azr"
  region      = "wus"
  base        = "sre-azr-wus"

  # ==============================================================================
  # ENUMERATED DIMENSIONS
  # ==============================================================================
  # Supported environments, companies, and roles that define the cross-product
  # of identity resources provisioned per simulated tenant.
  # ==============================================================================
  environments = ["dev", "tst", "qa", "qa2", "prd"]
  roles        = ["admin", "user", "viewer"]

  # ==============================================================================
  # TENANT SEED DATA
  # ==============================================================================
  # Canonical source of truth for all simulated tenants. Add new tenants here
  # and the entire downstream hierarchy is generated automatically.
  #
  # FIELDS:
  # - label  : single token used in resource names (e.g. "sim1", no internal hyphen)
  #            note: key is the Terraform identifier (e.g. "sim1"); keep them identical
  # - orgs   : per-tenant map of company_name => { code = "<2-char abbreviation>" }
  #            code is used in group display names, UPNs, and domain labels for brevity
  #            different tenants may have different org sets
  #
  # TO ADD A NEW TENANT:
  # - Append a new sim<n> entry with label and orgs map
  # - All app registrations, orgs, groups, and users are generated automatically.
  # ==============================================================================
  tenant_seeds = {
    sim1 = {
      label = "sim1"
      orgs  = {
        northwind = { code = "nw" }
        contoso   = { code = "cs" }
        fabrikam  = { code = "fk" }
      }
    }
    sim2 = {
      label = "sim2"
      orgs  = {
        northwind = { code = "nw" }
        contoso   = { code = "cs" }
        fabrikam  = { code = "fk" }
      }
    }
  }

  # ==============================================================================
  # ACTIVE TENANT SEEDS
  # ==============================================================================
  # Filters tenant_seeds to only the tenants that have been created in the
  # Portal and whose verified UPN domain has been provided via
  # var.sim_tenant_upn_domains.
  #
  # This is the gating mechanism: a tenant must have an entry in
  # sim_tenant_upn_domains before any of its Azure AD resources are provisioned.
  # When sim-2 is created, add its onmicrosoft.com domain to the live
  # terragrunt.hcl sim_tenant_upn_domains map and re-run terragrunt apply.
  # ==============================================================================
  active_tenant_seeds = {
    for k, v in local.tenant_seeds : k => v
    if contains(keys(var.sim_tenant_upn_domains), k)
  }

  # ==============================================================================
  # SIMULATED TENANTS - FULL IDENTITY HIERARCHY
  # ==============================================================================
  # Generates the complete identity hierarchy for every ACTIVE tenant (i.e.
  # tenants present in active_tenant_seeds). The structure mirrors the
  # dependency chain:
  #
  #   simulated_tenants.<tenant_key>.tenant_name
  #   simulated_tenants.<tenant_key>.app.{name, redirect_uris, app_roles, ...}
  #   simulated_tenants.<tenant_key>.orgs.<company>.domain
  #   simulated_tenants.<tenant_key>.orgs.<company>.envs.<env>.identifier
  #   simulated_tenants.<tenant_key>.orgs.<company>.envs.<env>.cp_service
  #   simulated_tenants.<tenant_key>.orgs.<company>.envs.<env>.groups.<role>
  #   simulated_tenants.<tenant_key>.orgs.<company>.envs.<env>.users.<role>
  # ==============================================================================
  simulated_tenants = {
    for tenant_key, seed in local.active_tenant_seeds : tenant_key => {

      # ────────────────────────────────────────────────────────────────────────
      # TENANT DISPLAY NAME
      # Pattern: sim<n>
      # Example: sim1
      # Rationale: inside an AD tenant the label is the primary anchor; provider
      #            prefix (sre-azr-wus) is redundant and wastes search space.
      # ────────────────────────────────────────────────────────────────────────
      tenant_name = seed.label

      # ────────────────────────────────────────────────────────────────────────
      # APP REGISTRATION
      # One app registration per tenant, environment-agnostic.
      # Redirect URIs cover all three environments.
      # ────────────────────────────────────────────────────────────────────────
      app = {
        # Pattern: appreg-sim<n>-cp
        # Example: appreg-sim1-cp
        # Note: "app-" is the CAF abbreviation for Microsoft.Web/sites, not app registrations.
        #       Use "appreg-" to eliminate ambiguity in cross-resource searches.
        name = "appreg-${seed.label}-cp"

        # One redirect URI per environment
        # Pattern: https://cp-<env>.<tenant>.cloud.hwd.mx/auth/callback
        # Example: https://cp-dev.sim1.cloud.hwd.mx/auth/callback
        redirect_uris = [
          for env in local.environments :
          "https://cp-${env}.${seed.label}.cloud.hwd.mx/auth/callback"
        ]

        # App roles exposed to the CP service
        app_roles = ["GlobalAdmin", "Support", "ReadOnly"]

        # Optional claims included in ID/access tokens
        optional_claims = ["nx_env", "nx_org"]

        # Group membership claims enabled so security groups appear in tokens
        group_claims_enabled = true
      }

      # ────────────────────────────────────────────────────────────────────────
      # ORGANIZATIONS
      # Cross-product of companies × environments with deterministic naming.
      # Each company has one stable domain (no env in domain) and per-env
      # security groups and users.
      # ────────────────────────────────────────────────────────────────────────
      orgs = {
        for company, org_cfg in seed.orgs : company => {

          # ──────────────────────────────────────────────────────────────────
          # ORG CODE
          # 2-char abbreviation used in all resource names for this org.
          # Keeps group names and UPNs bounded at scale (20+ orgs per tenant).
          # ──────────────────────────────────────────────────────────────────
          code = org_cfg.code

          # ──────────────────────────────────────────────────────────────────
          # DOMAIN
          # Pattern: <code>.<tenant>.tenants.cloud.hwd.mx
          # Example: nw.sim1.tenants.cloud.hwd.mx
          #
          # Hierarchy rationale: <code> is leftmost (most specific DNS leaf);
          # <tenant> enables *.sim1.tenants.cloud.hwd.mx wildcard cert covering
          # all orgs, and allows per-tenant DNS zone delegation.
          # Domain excludes environment (stable across dev/tst/qa/qa2/prd).
          # ──────────────────────────────────────────────────────────────────
          domain = "${org_cfg.code}.${seed.label}.tenants.cloud.hwd.mx"

          # ──────────────────────────────────────────────────────────────────
          # ENVIRONMENTS
          # Each environment is fully isolated with its own CP service,
          # security groups, and group memberships.
          # ──────────────────────────────────────────────────────────────────
          envs = {
            for env in local.environments : env => {

              # Org identifier for this environment
              # Pattern: org-sim<n>-<code>-<env>
              # Example: org-sim1-nw-dev
              identifier = "org-${seed.label}-${org_cfg.code}-${env}"

              # CP service name for this environment
              # Pattern: cp-<env>
              # Example: cp-dev
              cp_service = "cp-${env}"

              # ────────────────────────────────────────────────────────────
              # SECURITY GROUPS
              # One group per role, scoped to this (tenant, company, env).
              # Groups appear in access tokens via group claims.
              # Pattern: sg-sim<n>-<code>-<env>-<role>
              # Example: sg-sim1-nw-dev-admin
              # Search: sg-sim1       → all groups for tenant 1
              #         sg-sim1-nw    → all Northwind groups in sim1
              #         *-dev-*       → all dev-env groups
              #         *-admin       → all admin-role groups
              # ────────────────────────────────────────────────────────────
              groups = {
                for role in local.roles :
                role => "sg-${seed.label}-${org_cfg.code}-${env}-${role}"
              }

              # ────────────────────────────────────────────────────────────
              # USERS
              # UPN is environment-agnostic (shared across dev/tst/qa/qa2/prd).
              # Domain suffix comes from var.sim_tenant_upn_domains[tenant_key]
              # so the org context is encoded in the username portion rather
              # than as a custom domain — this avoids the DNS verification
              # requirement that custom domains impose on fresh Entra tenants.
              #
              # Pattern: sim<n>-<code>-<role>@<upn_domain>
              # Example: sim1-nw-admin@sreazrwussim1tenant.onmicrosoft.com
              # Search: sim1-nw → all Northwind users in sim1
              # ────────────────────────────────────────────────────────────
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

  # ==============================================================================
  # FLATTENED RESOURCE MAPS
  # ==============================================================================
  # Terraform for_each requires a flat map. The following locals flatten the
  # nested simulated_tenants hierarchy into maps keyed by composite identifiers.
  # These are consumed directly by Terraform resource blocks in main.tf.
  # ==============================================================================

  # ── App registrations: one per tenant ────────────────────────────────────────
  # Key: "<tenant_key>"   e.g. "sim1"
  flat_apps = {
    for tenant_key, tenant in local.simulated_tenants :
    tenant_key => merge(tenant.app, { tenant_name = tenant.tenant_name })
  }

  # ── Security groups: one per (tenant, company, env, role) ────────────────────
  # Key: "<tenant_key>-<company>-<env>-<role>"  e.g. "sim1-northwind-dev-admin"
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

  # ── Users: one per (tenant, company, role) — env-agnostic UPN ────────────────
  # Key: "<tenant_key>-<company>-<role>"   e.g. "sim1-northwind-admin"
  # Users share a single UPN across environments; group membership enforces env scope.
  flat_users = merge([
    for tenant_key, tenant in local.simulated_tenants : merge([
      for company, org in tenant.orgs : {
        # Extract user definitions from the first env (all envs share identical UPNs)
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

  # ── Group memberships: one per (tenant, company, env, role) ──────────────────
  # Maps each user to the security group they belong to per environment.
  # Key: "<tenant_key>-<company>-<env>-<role>"  e.g. "sim1-northwind-dev-admin"
  flat_memberships = merge([
    for tenant_key, tenant in local.simulated_tenants : merge([
      for company, org in tenant.orgs : merge([
        for env, env_cfg in org.envs : {
          for role in local.roles :
          "${tenant_key}-${company}-${env}-${role}" => {
            tenant_key  = tenant_key
            company     = company
            env         = env
            role        = role
            # Reference keys into flat_groups and flat_users
            group_key = "${tenant_key}-${company}-${env}-${role}"
            user_key  = "${tenant_key}-${company}-${role}"
          }
        }
      ]...)
    ]...)
  ]...)

  # ── NX Cloud enterprise apps: one per active tenant ──────────────────────────
  # Key: "<tenant_key>"   e.g. "sim1"
  flat_nxcloud_apps = {
    for tenant_key, tenant in local.simulated_tenants :
    tenant_key => {
      tenant_key = tenant_key
      # Tenant GUID — required by terraform_data.nxcloud_saml_entity_id to
      # acquire a cross-tenant Graph API token for the local-exec provisioner.
      tenant_id  = lookup(var.sim_tenant_ids, tenant_key, "")
      # NX Cloud SAML homepage / login URL — set as the SP's loginUrl (Homepage
      # URL in the Azure portal SAML SSO configuration page).
      login_url  = lookup(var.nxcloud_saml_login_urls, tenant_key, "")
      # Keycloak broker ACS endpoint — set after Keycloak IdP is configured.
      acs_url    = lookup(var.nxcloud_saml_acs_urls,   tenant_key, "")
    }
  }

  # ── NX Cloud Contoso user assignments: one per (tenant, role) ────────────────
  # Assigns all three Contoso users (admin, user, viewer) to the nx cloud
  # enterprise application per active tenant.
  # Key: "<tenant_key>-contoso-<role>"   e.g. "sim1-contoso-admin"
  flat_nxcloud_contoso_assignments = merge([
    for tenant_key, _ in local.simulated_tenants : {
      for role in local.roles :
      "${tenant_key}-contoso-${role}" => {
        tenant_key = tenant_key
        user_key   = "${tenant_key}-contoso-${role}"
      }
    }
  ]...)
}
