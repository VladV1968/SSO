# Global Terragrunt variables — naming conventions and Keycloak configuration.
# Format: {customer}-{provider}-{region}-{environment}-{service}-{resource}
# Inherited by all modules through root.hcl.

locals {
  customer    = "sre"
  provider    = "kc"
  environment = "dev"

  # ── Keycloak ─────────────────────────────────────────────────────────────────
  # Realm name is per-tenant — set in each live/{tenant}/terragrunt.hcl.
  keycloak_url = "https://idp-keycloak.cloud.nxteam.dev/auth"
}
