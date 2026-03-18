# Global Terragrunt variables — naming conventions and Azure subscription config.
# Format: {customer}-{provider}-{region}-{environment}-{service}-{resource}
# Inherited by all modules through root.hcl.

locals {
  customer        = "sre"
  provider        = "azr"
  environment     = "dev"
  subscription_id = "0d3a8060-e8d5-4500-aaff-eb67d9f11de9"
  tenant_id       = "8ef7e80b-b6ba-4504-ae0d-29aee51519a3"
}
