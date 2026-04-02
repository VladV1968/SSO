# Keycloak SSO Module — input variables.
# Configures Azure AD as a SAML Identity Provider in a Keycloak realm,
# with attribute mappers and role mappings for all provisioned security groups.

# ── Keycloak connection ───────────────────────────────────────────────────────

variable "keycloak_url" {
  description = "Base URL of the Keycloak server (e.g. https://test1.cloud.hwd.mx/sso)."
  type        = string
}

variable "realm" {
  description = "Keycloak realm to configure (e.g. default)."
  type        = string
  default     = "default"
}

# ── Azure AD IdP ──────────────────────────────────────────────────────────────

variable "idp_alias" {
  description = "Keycloak alias for the Azure AD SAML IdP. Must match the broker endpoint path in the ACS URL."
  type        = string
  default     = "azure-ad"
}

variable "idp_display_name" {
  description = "Human-readable label for the Azure AD IdP in the Keycloak login UI."
  type        = string
  default     = "Azure AD"
}

variable "azure_tenant_id" {
  description = "Azure AD tenant GUID for the SIM tenant."
  type        = string
}

variable "azure_app_client_id" {
  description = "Client ID (application ID) of the NX Cloud enterprise app in Azure AD. Used to construct the federation metadata URL."
  type        = string
}

variable "azure_ad_signing_certificate" {
  description = <<-EOT
    Base64-encoded (no PEM headers) public certificate used by Azure AD to sign SAML assertions.
    Retrieve after terragrunt apply of ad-tenant:
      az rest --method GET \
        --url "https://graph.microsoft.com/v1.0/servicePrincipals/<sp-object-id>/tokenSigningCertificates" \
        --headers "Authorization=Bearer $(az account get-access-token --tenant <tenant-id> --resource-type ms-graph --query accessToken -o tsv)" \
        | jq -r '.value[] | select(.isActive) | .rawValue'
  EOT
  type        = string
  sensitive   = true
}

# ── SAML claim attribute names ────────────────────────────────────────────────
# These must match the SamlClaimType values in the Azure AD claims mapping policy.

variable "saml_attribute_email" {
  description = "SAML attribute name for email. Must match SamlClaimType in the Azure AD claims mapping policy."
  type        = string
  default     = "email"
}

variable "saml_attribute_first_name" {
  description = "SAML attribute name for given name."
  type        = string
  default     = "firstName"
}

variable "saml_attribute_last_name" {
  description = "SAML attribute name for surname."
  type        = string
  default     = "lastName"
}

variable "saml_attribute_groups" {
  description = "SAML attribute name carrying Azure AD group display names."
  type        = string
  default     = "http://schemas.microsoft.com/ws/2008/06/identity/claims/groups"
}

# ── Group → Role mapping ──────────────────────────────────────────────────────

variable "group_display_names" {
  description = <<-EOT
    Map of '<tenant>-<org>-<env>-<role>' → group display name.
    Sourced from the ad-tenant module output 'group_display_names'.
    Each entry produces a Keycloak realm role and a SAML attribute-to-role mapper.
  EOT
  type        = map(string)
}

variable "external_group_display_names" {
  description = <<-EOT
    Map of group key → display name for existing Azure AD groups added to SSO via sso_external_groups.
    Sourced from the ad-tenant module output 'external_group_display_names'.
    Each entry produces a Keycloak realm role and a SAML attribute-to-role mapper.
  EOT
  type    = map(string)
  default = {}
}
