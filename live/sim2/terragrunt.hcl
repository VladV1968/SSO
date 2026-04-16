# Tenant: sim2 — Keycloak realm and identity hierarchy.
#
# Realm name = tenant identifier. All resource names within this realm
#
# Resulting resources:
#   Realm:  sim2
#   Groups: sg-nw-{dev,tst,qa,qa2,prd}-{admin,user,viewer}   (15)
#   Roles:  northwind-{dev,tst,qa,qa2,prd}-{admin,user,viewer} (15)
#   Users:  nw-{admin,user,viewer}@sim2.nxteam.dev             (3)
#
# Apply:
#   export KEYCLOAK_USER=admin
#   export KEYCLOAK_PASSWORD=<password>
#   terragrunt apply

locals {
  global_vars  = read_terragrunt_config(find_in_parent_folders("variables.hcl"))
  keycloak_url = local.global_vars.locals.keycloak_url
}

include {
  path = find_in_parent_folders("root.hcl")
}

generate "keycloak_provider" {
  path      = "keycloak_provider.tf"
  if_exists = "overwrite"
  contents  = <<-EOF
    provider "keycloak" {
      client_id = "admin-cli"
      url       = "${local.keycloak_url}"
      username  = "${get_env("KEYCLOAK_USER", "admin")}"
      password  = "${get_env("KEYCLOAK_PASSWORD", "")}"
    }
  EOF
}

terraform {
  source = "../../modules/keycloak-sso"
}

inputs = {
  realm = "sim2"

  tenant_orgs = {
    northwind = { code = "nw" }
  }

  environments = ["dev", "tst", "qa", "qa2", "prd"]
  roles        = ["admin", "user", "viewer"]

  users_enabled          = true
  user_password_length   = 20
  user_email_base_domain = "nxteam.dev"
  group_prefix           = "sg"

  # ── NX Cloud SAML ────────────────────────────────────────────────────────────
  keycloak_url    = local.keycloak_url
  nxcloud_enabled = true
  nxcloud_url     = "https://connect.alicloud-stage-sre.nx-demo.com" # TODO: verify exact URL from values-alicloud-sre.yaml
}
