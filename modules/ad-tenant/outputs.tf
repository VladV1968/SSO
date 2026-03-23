 # Azure AD Tenant Module — outputs.

output "simulated_tenants" {
  description = "Complete simulated_tenants hierarchy from locals."
  value       = local.simulated_tenants
}

output "group_object_ids" {
  description = "Map of '<tenant>-<company>-<env>-<role>' → group object ID."
  value = {
    for key, grp in azuread_group.org_env_role : key => grp.object_id
  }
}

output "group_display_names" {
  description = "Map of '<tenant>-<company>-<env>-<role>' → group display name."
  value = {
    for key, grp in azuread_group.org_env_role : key => grp.display_name
  }
}

output "user_object_ids" {
  description = "Map of '<tenant>-<company>-<role>' → user object ID."
  value = var.users_enabled ? {
    for key, u in azuread_user.org_role : key => u.object_id
  } : {}
}

output "user_upns" {
  description = "Map of '<tenant>-<company>-<role>' → user principal name."
  value = var.users_enabled ? {
    for key, u in azuread_user.org_role : key => u.user_principal_name
  } : {}
}

output "user_initial_passwords" {
  description = "Map of '<tenant>-<company>-<role>' → initial password. Retrieve with: terraform output -json user_initial_passwords"
  sensitive   = true
  value = var.users_enabled ? {
    for key, pw in random_password.user : key => pw.result
  } : {}
}

output "flat_groups" {
  description = "Flattened group map from the hierarchy."
  value       = local.flat_groups
}

output "flat_users" {
  description = "Flattened user map from the hierarchy."
  value       = local.flat_users
}
