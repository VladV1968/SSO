# Keycloak SSO Module — Azure AD SAML IdP, attribute mappers, and role mappings.
#
# Configures Keycloak to broker authentication from Azure AD via SAML 2.0.
# One SAML IdP is created per module invocation (one per SIM tenant).
#
# Flow:
#   User → NX Cloud → Keycloak → Azure AD (SAML AuthnRequest)
#          ← SAML assertion (email, firstName, lastName, groups) ←
#   Mappers fire → Keycloak user profile populated, roles assigned
#          → Keycloak token issued to NX Cloud

terraform {
  backend "azurerm" {}
}

# ── Azure AD SAML Identity Provider ──────────────────────────────────────────
# Keycloak will redirect unauthenticated users to Azure AD's SAML SSO endpoint.
# Azure AD sends the signed SAML assertion back to the ACS URL:
#   {keycloak_url}/realms/{realm}/broker/{idp_alias}/endpoint
resource "keycloak_saml_identity_provider" "azure_ad" {
  realm        = var.realm
  alias        = var.idp_alias
  display_name = var.idp_display_name
  enabled      = true

  # Azure AD SAML endpoints for the SIM tenant.
  entity_id              = "${var.keycloak_url}/realms/${var.realm}"
  single_sign_on_service_url = "https://login.microsoftonline.com/${var.azure_tenant_id}/saml2"
  single_logout_service_url  = "https://login.microsoftonline.com/${var.azure_tenant_id}/saml2"

  # Azure AD signs assertions with the self-signed cert created by ad-tenant module.
  signing_certificate  = var.azure_ad_signing_certificate
  validate_signature   = true
  want_assertions_signed = true

  # NameID format must match Azure AD's NameID claim (UPN via userprincipalname).
  name_id_policy_format          = "Unspecified"
  principal_type                 = "SUBJECT"

  # Use POST binding for both SSO and SLO (Azure AD default).
  post_binding_response          = true
  post_binding_authn_request     = true
  post_binding_logout            = true

  # Sync user profile on every login so attribute changes in Azure AD propagate.
  sync_mode = "FORCE"

  # Link existing Keycloak users by email if they were created before SSO.
  first_broker_login_flow_alias = "first broker login"
}

locals {
  # Merge managed and external groups — both are key → display_name maps.
  all_groups = merge(var.group_display_names, var.external_group_display_names)

  # Profile attribute mappers: SAML claim → Keycloak user attribute.
  profile_mappers = {
    email      = { attribute = var.saml_attribute_email,      user_attr = "email" }
    first-name = { attribute = var.saml_attribute_first_name, user_attr = "firstName" }
    last-name  = { attribute = var.saml_attribute_last_name,  user_attr = "lastName" }
  }
}

# ── Attribute Mappers — user profile ─────────────────────────────────────────
# Imports email, firstName, and lastName from SAML attributes into the
# Keycloak user profile. These feed into downstream tokens for NX Cloud.
resource "keycloak_attribute_importer_identity_provider_mapper" "profile" {
  for_each = local.profile_mappers

  realm                   = var.realm
  name                    = "azure-ad-${each.key}"
  identity_provider_alias = keycloak_saml_identity_provider.azure_ad.alias
  attribute_name          = each.value.attribute
  user_attribute          = each.value.user_attr
}

# ── Realm Roles — one per security group ─────────────────────────────────────
# Each Azure AD security group gets a corresponding Keycloak realm role.
# Covers both managed groups (from ad-tenant) and externally-managed groups.
resource "keycloak_role" "group_role" {
  for_each = local.all_groups

  realm_id    = var.realm
  name        = each.key
  description = "Mapped from Azure AD group: ${each.value}"
}

# ── SAML Attribute to Role Mappers ───────────────────────────────────────────
# When the Azure AD SAML assertion contains a group's display name in the
# groups claim, assign the corresponding Keycloak realm role to the user.
resource "keycloak_attribute_to_role_identity_provider_mapper" "group_to_role" {
  for_each = local.all_groups

  realm                   = var.realm
  name                    = "azure-ad-group-${each.key}"
  identity_provider_alias = keycloak_saml_identity_provider.azure_ad.alias
  attribute_name          = var.saml_attribute_groups
  attribute_value         = each.value
  role                    = keycloak_role.group_role[each.key].name

  depends_on = [keycloak_role.group_role]
}
