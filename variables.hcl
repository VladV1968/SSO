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
    sim2 = "027de348-f78d-44e5-93a7-f0472d5cb35a"  # sreazrwussim2.onmicrosoft.com
  }

  # Active sim tenant for this deployment. Switch to target a different tenant.
  active_sim_tenant_key = "sim2"
  active_sim_tenant_id  = local.sim_tenant_ids[local.active_sim_tenant_key]

  # ── Keycloak ─────────────────────────────────────────────────────────────────
  keycloak_url = "https://auth.alicloud-stage-sre.nx-demo.com/auth"
  keycloak_realm = "default"
}