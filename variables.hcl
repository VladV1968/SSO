# Global Terragrunt variables — naming conventions and Azure subscription config.
# Format: {customer}-{provider}-{region}-{environment}-{service}-{resource}
# Inherited by all modules through root.hcl.

locals {
  customer        = "sre"
  provider        = "azr"
  environment     = "dev"
  subscription_id = "0d3a8060-e8d5-4500-aaff-eb67d9f11de9"
  tenant_id       = "8ef7e80b-b6ba-4504-ae0d-29aee51519a3"

  # ── SIM tenants ─────────────────────────────────────────────────────────────
  # Each sim tenant is a separate Azure AD tenant created manually in the Portal.
  sim_tenant_ids = {
    sim1 = "1ebd14fa-33f0-474d-b9b8-bc87d0a0effe"  # sreazrwussim1.onmicrosoft.com
  }

  # Active sim tenant for this deployment. Switch to target a different tenant.
  active_sim_tenant_key = "sim1"
  active_sim_tenant_id  = local.sim_tenant_ids[local.active_sim_tenant_key]

  # ── Keycloak ─────────────────────────────────────────────────────────────────
  keycloak_url = "https://test1.cloud.hwd.mx/sso"
  keycloak_realm = "default"
}