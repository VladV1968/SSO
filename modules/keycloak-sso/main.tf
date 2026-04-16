# Keycloak Realm Module — production-ready per-tenant realm.
#
# The realm name IS the tenant identifier — no tenant prefix inside resources.
#
# Naming within the realm:
#   Group:    {prefix}-{org_code}-{env}-{role}   e.g. sg-nw-dev-admin
#   Role:     {org_name}-{env}-{role}             e.g. northwind-dev-admin
#   Username: {org_code}-{role}                   e.g. nw-admin
#   Email:    {org_code}-{role}@{realm}.{domain}  e.g. nw-admin@sim2.nxteam.dev

terraform {
  backend "local" {}
}

# ── Realm ─────────────────────────────────────────────────────────────────────
resource "keycloak_realm" "this" {
  realm   = var.realm
  enabled = true

  # ── Security ────────────────────────────────────────────────────────────────
  ssl_required = "all"

  # ── Registration ────────────────────────────────────────────────────────────
  # Managed deployment — no self-service registration or password reset.
  registration_allowed           = false
  verify_email                   = false
  login_with_email_allowed       = true
  duplicate_emails_allowed       = false
  reset_password_allowed         = false

  # ── Password policy ──────────────────────────────────────────────────────────
  password_policy = join(" and ", [
    "length(12)",
    "upperCase(1)",
    "lowerCase(1)",
    "digits(1)",
    "specialChars(1)",
    "notUsername",
    "passwordHistory(5)",
  ])

  # ── Token lifespans ──────────────────────────────────────────────────────────
  access_token_lifespan    = "5m"   # short-lived, forces frequent refresh
  sso_session_idle_timeout = "30m"  # session expires after inactivity
  sso_session_max_lifespan = "10h"  # hard session ceiling

  # ── Security defenses ────────────────────────────────────────────────────────
  security_defenses {
    headers {
      x_frame_options                     = "SAMEORIGIN"
      content_security_policy             = "frame-src 'self'; frame-ancestors 'self'; object-src 'none';"
      content_security_policy_report_only = ""
      x_content_type_options              = "nosniff"
      x_robots_tag                        = "none"
      x_xss_protection                    = "1; mode=block"
      strict_transport_security           = "max-age=31536000; includeSubDomains"
    }

    brute_force_detection {
      permanent_lockout                = false
      max_login_failures               = 10  # lock after 10 failures
      wait_increment_seconds           = 60
      minimum_quick_login_wait_seconds = 60
      max_failure_wait_seconds         = 900 # 15 min lockout
    }
  }
}

# ── Locals — flattened resource maps ─────────────────────────────────────────

locals {
  # key: "{org_name}-{env}-{role}"
  flat_groups = merge([
    for org_name, org in var.tenant_orgs : merge([
      for env in var.environments : {
        for role in var.roles :
        "${org_name}-${env}-${role}" => {
          display_name = "${var.group_prefix}-${org.code}-${env}-${role}"
          org_name     = org_name
          env          = env
          role         = role
          code         = org.code
        }
      }
    ]...)
  ]...)

  # key: "{org_name}-{role}"
  flat_users = merge([
    for org_name, org in var.tenant_orgs : {
      for role in var.roles :
      "${org_name}-${role}" => {
        username   = "${org.code}-${role}"
        email      = "${org.code}-${role}@${var.realm}.${var.user_email_base_domain}"
        first_name = title(role)
        last_name  = title(org_name)
        org_name   = org_name
        role       = role
        code       = org.code
      }
    }
  ]...)
}

# ── Groups ────────────────────────────────────────────────────────────────────
# One group per (org × env × role).
resource "keycloak_group" "org_env_role" {
  for_each = local.flat_groups

  realm_id = keycloak_realm.this.id
  name     = each.value.display_name
}

# ── Realm Roles ───────────────────────────────────────────────────────────────
# One role per group, keyed {org_name}-{env}-{role}.
resource "keycloak_role" "group_role" {
  for_each = local.flat_groups

  realm_id    = keycloak_realm.this.id
  name        = each.key
  description = "Role for group: ${each.value.display_name}"
}

# ── Group → Role Assignments ──────────────────────────────────────────────────
# Members of a group automatically receive its realm role.
resource "keycloak_group_roles" "org_env_role" {
  for_each = local.flat_groups

  realm_id   = keycloak_realm.this.id
  group_id   = keycloak_group.org_env_role[each.key].id
  role_ids   = [keycloak_role.group_role[each.key].id]
  exhaustive = false
}

# ── Random Passwords ──────────────────────────────────────────────────────────
resource "random_password" "user" {
  for_each = var.users_enabled ? local.flat_users : {}

  length           = var.user_password_length
  special          = true
  override_special = "!@#%^&*()-_=+[]"
  min_lower        = 3
  min_upper        = 3
  min_numeric      = 3
  min_special      = 2
}

# ── Users ─────────────────────────────────────────────────────────────────────
# One user per (org × role), env-agnostic — membership spans all environments.
resource "keycloak_user" "org_role" {
  for_each = var.users_enabled ? local.flat_users : {}

  realm_id   = keycloak_realm.this.id
  username   = each.value.username
  enabled    = true
  email      = each.value.email
  first_name = each.value.first_name
  last_name  = each.value.last_name

  initial_password {
    value     = random_password.user[each.key].result
    temporary = true
  }

  lifecycle {
    ignore_changes = [initial_password]
  }
}

# ── Group Memberships ─────────────────────────────────────────────────────────
# Assigns each role-scoped user to their role's group in every environment.
resource "keycloak_group_memberships" "org_env_role" {
  for_each = var.users_enabled ? local.flat_groups : {}

  realm_id = keycloak_realm.this.id
  group_id = keycloak_group.org_env_role[each.key].id
  members  = [keycloak_user.org_role["${each.value.org_name}-${each.value.role}"].username]

  depends_on = [keycloak_user.org_role]
}

# ── NX Cloud SAML Client ──────────────────────────────────────────────────────
# Registers NX Cloud as a SAML service provider in this realm.
# Set nxcloud_enabled = true and nxcloud_url = "<NX Cloud base URL>" to activate.
resource "keycloak_saml_client" "nxcloud" {
  count = var.nxcloud_enabled ? 1 : 0

  realm_id  = keycloak_realm.this.id
  client_id = "nx-private-cloud"
  name      = "NX Cloud"
  enabled   = true

  # SAML signing — both the response document and each assertion are signed.
  sign_documents          = true
  sign_assertions         = true
  include_authn_statement = true
  force_post_binding      = true

  # NX Cloud expects NameID as email address.
  name_id_format = "email"

  valid_redirect_uris = ["${var.nxcloud_url}/auth-callback"]
}

# email — required by NX Cloud to identify the user.
resource "keycloak_saml_user_property_protocol_mapper" "nxcloud_email" {
  count = var.nxcloud_enabled ? 1 : 0

  realm_id  = keycloak_realm.this.id
  client_id = keycloak_saml_client.nxcloud[0].id
  name      = "email"

  user_property              = "email"
  saml_attribute_name        = "email"
  saml_attribute_name_format = "Basic"
}

# first_name
resource "keycloak_saml_user_property_protocol_mapper" "nxcloud_first_name" {
  count = var.nxcloud_enabled ? 1 : 0

  realm_id  = keycloak_realm.this.id
  client_id = keycloak_saml_client.nxcloud[0].id
  name      = "first_name"

  user_property              = "firstName"
  saml_attribute_name        = "first_name"
  saml_attribute_name_format = "Basic"
}

# last_name
resource "keycloak_saml_user_property_protocol_mapper" "nxcloud_last_name" {
  count = var.nxcloud_enabled ? 1 : 0

  realm_id  = keycloak_realm.this.id
  client_id = keycloak_saml_client.nxcloud[0].id
  name      = "last_name"

  user_property              = "lastName"
  saml_attribute_name        = "last_name"
  saml_attribute_name_format = "Basic"
}

# roles — sends the user's realm roles as a SAML attribute named "roles".
# NX Cloud receives the role list (e.g. northwind-dev-admin) via this mapper.
resource "keycloak_saml_user_attribute_protocol_mapper" "nxcloud_roles" {
  count = var.nxcloud_enabled ? 1 : 0

  realm_id  = keycloak_realm.this.id
  client_id = keycloak_saml_client.nxcloud[0].id
  name      = "roles"

  user_attribute             = "roles"
  saml_attribute_name        = "roles"
  saml_attribute_name_format = "Basic"
}
