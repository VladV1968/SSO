# ==============================================================================
# AZURE AD TENANT MODULE - OUTPUTS
# ==============================================================================
# Exposes key identifiers from the identity hierarchy for consumption by
# downstream modules (AKS RBAC, Key Vault access policies, DNS, etc.).
# ==============================================================================

# ==============================================================================
# IDENTITY HIERARCHY (STRUCTURED)
# ==============================================================================

output "simulated_tenants" {
  description = <<-EOT
    Complete simulated_tenants hierarchy as defined in locals.tf.
    Contains tenant names, app registration details, org domains,
    per-env CP service names, group names, and user UPNs.

    Use this output to inspect the full generated hierarchy without
    requiring access to the module internals.
  EOT
  value = local.simulated_tenants
}

# ==============================================================================
# APP REGISTRATIONS
# ==============================================================================

output "app_client_ids" {
  description = <<-EOT
    Map of tenant key → app registration client ID.
    Keys match tenant_seeds keys (e.g. "sim1", "sim2").

    USE: Configure CP service OIDC/OAuth2 with the correct client_id
    per tenant. Inject into CP Helm values or Kubernetes secrets.
  EOT
  value = {
    for key, app in azuread_application.cp :
    key => app.client_id
  }
}

output "app_object_ids" {
  description = "Map of tenant key → app registration object ID."
  value = {
    for key, app in azuread_application.cp :
    key => app.object_id
  }
}

output "service_principal_object_ids" {
  description = <<-EOT
    Map of tenant key → service principal object ID.
    USE: Assign Azure RBAC roles to the service principal for
    resource access (e.g. Key Vault read, Storage access).
  EOT
  value = {
    for key, sp in azuread_service_principal.cp :
    key => sp.object_id
  }
}

# ==============================================================================
# SECURITY GROUPS
# ==============================================================================

output "group_object_ids" {
  description = <<-EOT
    Map of composite key → security group object ID.
    Key format: "<tenant_key>-<company>-<env>-<role>"
    Example: "sim1-northwind-dev-admin"

    USE: Bind groups to AKS cluster roles, Key Vault access policies,
    or Azure RBAC role assignments for CP resource isolation.
  EOT
  value = {
    for key, grp in azuread_group.org_env_role :
    key => grp.object_id
  }
}

output "group_display_names" {
  description = <<-EOT
    Map of composite key → security group display name.
    Key format: "<tenant_key>-<company>-<env>-<role>"

    USE: Reference group display names in documentation, audit reports,
    or conditional access policy descriptions.
  EOT
  value = {
    for key, grp in azuread_group.org_env_role :
    key => grp.display_name
  }
}

# ==============================================================================
# USERS
# ==============================================================================

output "user_object_ids" {
  description = <<-EOT
    Map of composite key → user object ID.
    Key format: "<tenant_key>-<company>-<role>"
    Example: "sim1-northwind-admin"

    Only populated when users_enabled = true.
  EOT
  value = var.users_enabled ? {
    for key, u in azuread_user.org_role :
    key => u.object_id
  } : {}
}

output "user_upns" {
  description = <<-EOT
    Map of composite key → user principal name (UPN).
    Key format: "<tenant_key>-<company>-<role>"

    USE: Populate test fixtures, onboarding documentation, or
    seed scripts that validate CP service authentication flows
    across dev / tst / prd environments.
  EOT
  value = var.users_enabled ? {
    for key, u in azuread_user.org_role :
    key => u.user_principal_name
  } : {}
}

output "user_initial_passwords" {
  description = <<-EOT
    Map of composite key → randomly generated initial password.
    Marked sensitive; retrieve with: terraform output -json user_initial_passwords

    SECURITY NOTE:
    Distribute initial passwords via a secure channel (Key Vault, encrypted
    email) and communicate that force_password_change = true requires rotation
    on first login. Rotate the random_password resource after onboarding.
  EOT
  sensitive = true
  value = var.users_enabled ? {
    for key, pw in random_password.user :
    key => pw.result
  } : {}
}

# ==============================================================================
# FLAT RESOURCE MAPS (for debugging and cross-module reference)
# ==============================================================================

output "flat_groups" {
  description = "Flattened map of all security groups generated from the hierarchy."
  value       = local.flat_groups
}

output "flat_users" {
  description = "Flattened map of all user definitions generated from the hierarchy."
  value       = local.flat_users
}
