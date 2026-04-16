# Keycloak Realm Module — outputs.
# Keys use {org_name}-{env}-{role} / {org_name}-{role} — no tenant prefix
# (tenant context is the realm name itself).

output "realm_id" {
  description = "Keycloak realm ID (= realm name)."
  value       = keycloak_realm.this.id
}

output "group_names" {
  description = "Map of '{org_name}-{env}-{role}' → Keycloak group name."
  value       = { for k, g in keycloak_group.org_env_role : k => g.name }
}

output "role_names" {
  description = "Map of '{org_name}-{env}-{role}' → Keycloak realm role name."
  value       = { for k, r in keycloak_role.group_role : k => r.name }
}

output "user_usernames" {
  description = "Map of '{org_name}-{role}' → Keycloak username."
  value       = { for k, u in keycloak_user.org_role : k => u.username }
}

output "user_initial_passwords" {
  description = "Map of '{org_name}-{role}' → initial password (sensitive). Retrieve with: terragrunt output -json user_initial_passwords"
  sensitive   = true
  value = var.users_enabled ? {
    for k, pw in random_password.user : k => pw.result
  } : {}
}

# ── NX Cloud SAML outputs ─────────────────────────────────────────────────────
# Feed these values into the NX Cloud SSO configuration:
#   SAML_ENTRY_POINT → nxcloud_saml_entry_point
#   SAML_CERT        → extract from nxcloud_saml_metadata_url (X509Certificate element)

output "nxcloud_saml_entry_point" {
  description = "Keycloak SAML entry point URL — set as SAML_ENTRY_POINT in NX Cloud."
  value       = var.nxcloud_enabled ? "${var.keycloak_url}/realms/${var.realm}/protocol/saml" : null
}

output "nxcloud_saml_metadata_url" {
  description = "Keycloak SAML descriptor URL — fetch to retrieve the signing certificate (SAML_CERT)."
  value       = var.nxcloud_enabled ? "${var.keycloak_url}/realms/${var.realm}/protocol/saml/descriptor" : null
}
