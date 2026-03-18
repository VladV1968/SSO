# Azure AD Tenant Module — input variables.
# All configuration is centralized here. Every parameter has a default value
# matching the current SRE sim deployment, ensuring backward compatibility.

# ── Identity Hierarchy ───────────────────────────────────────────────────────

variable "environments" {
  description = "List of environment names to provision per org."
  type        = list(string)
  default     = ["dev", "tst", "qa", "qa2", "prd"]
}

variable "roles" {
  description = "List of role names to provision per environment."
  type        = list(string)
  default     = ["admin", "user", "viewer"]
}

variable "tenant_seeds" {
  description = "Map of tenant key → tenant config. Each tenant gets all orgs from tenant_orgs."
  type = map(object({
    label = string
  }))
  default = {
    sim1 = { label = "sim1" }
  }
}

variable "tenant_orgs" {
  description = "Organizations to provision per tenant. Map of org name to config object with short code."
  type = map(object({
    code = string
  }))
  default = {
    northwind = { code = "nw" }
  }
}

# ── Naming & Domain ──────────────────────────────────────────────────────────

variable "base_domain" {
  description = "Base domain suffix for org tenant domains (<code>.<tenant>.tenants.<base_domain>)."
  type        = string
  default     = "cloud.hwd.mx"
}

variable "group_prefix" {
  description = "Prefix for security group display names (e.g. 'sg' → sg-sim1-nw-dev-admin)."
  type        = string
  default     = "sg"
}

# ── Users ────────────────────────────────────────────────────────────────────

variable "users_enabled" {
  description = "Whether to create azuread_user resources. Set false if users are managed externally."
  type        = bool
  default     = true
}

variable "user_password_length" {
  description = "Length of randomly generated initial passwords (minimum 16)."
  type        = number
  default     = 20

  validation {
    condition     = var.user_password_length >= 16
    error_message = "user_password_length must be at least 16 to satisfy Azure AD password complexity requirements."
  }
}

variable "usage_location" {
  description = "ISO 3166-1 alpha-2 country code for user usage location (required for license assignment)."
  type        = string
  default     = "US"

  validation {
    condition     = can(regex("^[A-Z]{2}$", var.usage_location))
    error_message = "usage_location must be a two-letter uppercase ISO country code."
  }
}

# ── Tenant Configuration ─────────────────────────────────────────────────────

variable "sim_tenant_upn_domains" {
  description = "Map of tenant key → verified UPN domain suffix (e.g. sim1 = \"sreazrwussim1.onmicrosoft.com\")."
  type        = map(string)
  default     = {}

  validation {
    condition     = alltrue([for v in values(var.sim_tenant_upn_domains) : can(regex("^[a-zA-Z0-9.-]+\\.[a-zA-Z]{2,}$", v))])
    error_message = "Each value must be a valid domain name."
  }
}

variable "sim_tenant_ids" {
  description = "Map of tenant key → Azure AD tenant GUID. Used by local-exec provisioners for cross-tenant Graph API calls."
  type        = map(string)
  default     = {}
}

# ── NX Cloud SAML SSO ────────────────────────────────────────────────────────

variable "nxcloud_app_display_name" {
  description = "Display name for the NX Cloud enterprise application in Entra ID."
  type        = string
  default     = "nx cloud"
}

variable "nxcloud_saml_login_urls" {
  description = "Map of tenant key → NX Cloud SAML login / homepage URL (Keycloak realm root)."
  type        = map(string)
  default     = {}
}

variable "nxcloud_saml_acs_urls" {
  description = "Map of tenant key → NX Cloud SAML ACS URL (Keycloak broker endpoint)."
  type        = map(string)
  default     = {}
}

variable "nxcloud_saml_entity_ids" {
  description = "Map of tenant key → SAML Entity ID URI. If not set for a tenant, entity ID provisioning is skipped."
  type        = map(string)
  default     = {}
}

variable "nxcloud_assigned_orgs" {
  description = "List of org names whose users get app role assignments to the NX Cloud enterprise app."
  type        = list(string)
  default     = []
}

# ── Metadata ─────────────────────────────────────────────────────────────────

variable "tags" {
  description = "Tags applied to all taggable Azure resources."
  type        = map(string)
  default     = {}
}
