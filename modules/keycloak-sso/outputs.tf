# Keycloak SSO Module — outputs.

output "idp_alias" {
  description = "Keycloak alias of the Azure AD SAML IdP. Must match the path segment in the ACS URL registered in Azure AD."
  value       = keycloak_saml_identity_provider.azure_ad.alias
}

output "role_names" {
  description = "Map of group key → Keycloak realm role name for all Azure AD security groups (managed and external)."
  value       = { for k, r in keycloak_role.group_role : k => r.name }
}
