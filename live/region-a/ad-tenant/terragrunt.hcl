# ==============================================================================
# AZURE AD TENANT MODULE - LIVE CONFIGURATION (REGION A)
# ==============================================================================
# This Terragrunt configuration deploys the ad-tenant module, which provisions
# the complete Azure AD identity hierarchy for simulated multi-tenant,
# multi-environment CP deployments within the West US region.
#
# PURPOSE:
# - Provision app registrations (one per simulated tenant)
# - Create security groups per (tenant × org × env × role)
# - Create users with env-agnostic UPNs and assign them to env-scoped groups
# - Enforce the strict tenant-first identity hierarchy deterministically
#
# IDENTITY HIERARCHY DEPLOYED:
# ┌─────────────────────────────────────────────────────────────────────────────┐
# │  Azure AD Tenant (manually created; this module configures resources in it)│
# │    → App Registration   (app-sre-azr-wus-sim-<n>-cp)                       │
# │      → Service Principal                                                    │
# │        → Organizations  (northwind, contoso, fabrikam)                     │
# │          → Domain       (org-sim-<n>-<company>.tenants.cloud.hdw.mx)       │
# │            → Environments (dev, tst, prd)                                  │
# │              → CP Service (sre-azr-wus-<env>-cp)                           │
# │                → Security Groups (sg-sre-azr-wus-<env>-cp-org-...)         │
# │                  → Users (<role>-org-sim-<n>-<company>@<upn_domain>)       │
# └─────────────────────────────────────────────────────────────────────────────┘
#
# RESOURCE COUNTS (per tenant seed):
# - 1  × app registration
# - 1  × service principal
# - 27 × security groups  (3 companies × 3 environments × 3 roles)
# - 9  × users            (3 companies × 3 roles, env-agnostic)
# - 27 × group memberships (1 user × 3 envs × 3 roles per company)
#
# DEPENDENCIES: None — this module creates Azure AD resources that are
# independent of Azure resource group or networking infrastructure.
#
# AUTHENTICATION: Requires a service principal with:
# - Application.ReadWrite.All
# - Directory.ReadWrite.All
# - Group.ReadWrite.All
# - User.ReadWrite.All
#
# OPERATIONAL NOTES:
# - tenant_id and client_id are read from region.hcl / variables.hcl
# - client_secret must NOT be committed; inject via ARM_CLIENT_SECRET env var
#   or a Key Vault reference in the CI/CD pipeline
# - To add a new simulated tenant, add an entry to tenant_seeds in locals.tf
#   and re-run: terragrunt plan && terragrunt apply
# ==============================================================================

# ==============================================================================
# LOCAL VARIABLES
# ==============================================================================
locals {
  # ── Global and regional config inheritance ───────────────────────────────────
  global_vars = read_terragrunt_config(find_in_parent_folders("variables.hcl"))
  region_vars = read_terragrunt_config(find_in_parent_folders("region.hcl"))

  # ── Shared naming components ─────────────────────────────────────────────────
  # Format: {customer}-{provider}-{region}
  # Example: sre-azr-wus (matches the ad-tenant module's local.base)
  customer    = local.global_vars.locals.customer
  provider_id = local.global_vars.locals.provider
  environment = local.global_vars.locals.environment

  # ── Simulated tenant IDs ────────────────────────────────────────────────────
  # Each sim tenant is a separate Azure AD tenant created manually in the Portal.
  # The azuread provider must target the sim tenant explicitly — it is a different
  # tenant from networkoptix.com which hosts the azurerm backend state storage.
  #
  # To add a new sim tenant:
  #   1. Create it in the Portal (Entra ID → Manage tenants → Create)
  #   2. Add its tenant ID here
  #   3. Add a matching entry to tenant_seeds in modules/ad-tenant/tenants.tf
  sim_tenant_ids = {
    # sim1 = "cec91f60-5cf7-469c-8b65-88f05a0dbca8"  # retired — CIAM tenant, SAML portal wizard not supported in CIAM
    sim2 = "d6c50190-9f88-459a-bd01-a7cd7be3ec1d"  # sre-wus-sim-2-tenant (sreazrwussim2.onmicrosoft.com) — Workforce, full SAML portal support
  }

  # Active target tenant for this terragrunt deployment.
  # Switch this value to deploy the identity hierarchy into a different sim tenant.
  active_sim_tenant_id = "d6c50190-9f88-459a-bd01-a7cd7be3ec1d"
}

# ==============================================================================
# TERRAGRUNT CONFIGURATION INHERITANCE
# ==============================================================================
# Inherit global remote state backend, provider generation, and shared
# Terragrunt settings from the root.hcl at the workspace root.
# ==============================================================================
include {
  path = find_in_parent_folders("root.hcl")
}

# ==============================================================================
# PROVIDER OVERRIDE
# ==============================================================================
# root.hcl generates a provider.tf that only includes the azurerm provider.
# This generate block runs after the root include and overwrites provider.tf
# with a version that also declares azuread and random required_providers,
# plus the azuread provider block configured from module input variables.
#
# Terraform only allows ONE required_providers block per module, so all
# providers must be declared together in a single terraform{} block.
# ==============================================================================
generate "ad_provider" {
  path      = "provider.tf"
  if_exists = "overwrite"
  contents  = <<-EOF
# ==============================================================================
# GENERATED BY: live/region-a/ad-tenant/terragrunt.hcl (ad_provider)
# DO NOT EDIT — this file is overwritten on every terragrunt run.
# Extends root.hcl provider.tf to add azuread and random providers required
# by the ad-tenant module in addition to the standard azurerm provider.
# ==============================================================================

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

# Standard azurerm provider — mirrors root.hcl configuration
provider "azurerm" {
  features {
    resource_group {
      prevent_deletion_if_contains_resources = false
    }
  }
  subscription_id = local.subscription_id
  tenant_id       = local.tenant_id
}

# azuread provider — explicitly targets the sim tenant, NOT networkoptix.com.
# tenant_id is set to the active_sim_tenant_id local defined in terragrunt.hcl.
# ARM_TENANT_ID must remain set to the networkoptix.com tenant so the azurerm
# backend can authenticate against the state storage account.
provider "azuread" {
  tenant_id = "${local.active_sim_tenant_id}"
}
EOF
}

# ==============================================================================
# TERRAFORM MODULE SOURCE
# ==============================================================================
# Points to the reusable ad-tenant module that contains all Azure AD
# resource definitions, locals hierarchy, and output definitions.
# ==============================================================================
terraform {
  source = "../../../modules/ad-tenant"
}

# ==============================================================================
# INPUT VARIABLES
# ==============================================================================
# Pass configuration values into the ad-tenant Terraform module.
# All identity resource names are derived deterministically inside the module
# from the simulated_tenants hierarchy — no manual naming is required here.
# ==============================================================================
inputs = {
  # ── Module behaviour ─────────────────────────────────────────────────────────
  # Set to false if users are managed externally (e.g. AD Sync from on-prem).
  users_enabled = true

  # Minimum 16 characters to satisfy Azure AD password complexity requirements.
  user_password_length = 20

  # ── Simulated tenant GUIDs ──────────────────────────────────────────────────
  # Required for local-exec provisioners that need a cross-tenant Graph API token
  # (e.g. terraform_data.nxcloud_saml_entity_id in the ad-tenant module).
  sim_tenant_ids = local.sim_tenant_ids

  # ── NX Cloud SAML homepage URLs ───────────────────────────────────────────────
  # Maps each sim tenant key to the NX Cloud SAML login URL (Homepage URL shown
  # in the Azure portal Enterprise App → Single sign-on configuration checklist).
  # This is the Keycloak realm root URL and doubles as the SAML Entity ID.
  nxcloud_saml_login_urls = {
    # sim1 = "https://test1.cloud.hwd.mx/sso/realms/default"  # retired CIAM tenant
    sim2 = "https://test2.cloud.hwd.mx/sso/realms/default"
  }

  # ── NX Cloud SAML ACS URLs ────────────────────────────────────────────────────
  # Keycloak broker endpoint (Assertion Consumer Service URL) per sim tenant.
  # Update after configuring the Keycloak Identity Provider and noting the
  # broker UUID from the Keycloak admin console.
  # Pattern: https://test<n>.cloud.hwd.mx/sso/realms/default/broker/<uuid>/endpoint
  nxcloud_saml_acs_urls = {
    # sim2 = "https://test2.cloud.hwd.mx/sso/realms/default/broker/<keycloak-broker-uuid>/endpoint"
  }

  # ── UPN domain suffixes ───────────────────────────────────────────────────────
  # Maps each sim tenant key to its verified UPN domain. A fresh Entra Workforce
  # tenant has only the onmicrosoft.com domain verified; custom domains need
  # DNS TXT verification. Use onmicrosoft.com until custom domains are verified.
  #
  # UPN pattern: sim<n>-<code>-<role>@<upn_domain>
  # Example:     sim2-nw-admin@sreazrwussim2.onmicrosoft.com
  sim_tenant_upn_domains = {
    # sim1 = "sreazrwussim1tenant.onmicrosoft.com"  # retired CIAM tenant
    sim2 = "sreazrwussim2.onmicrosoft.com"
  }

  # ── Governance tags ──────────────────────────────────────────────────────────
  tags = {
    ManagedBy   = "terragrunt"
    Module      = "ad-tenant"
    Environment = local.environment
    Customer    = local.customer
    Region      = "wus"
    CostCenter  = "sre-platform"
  }
}
