# Azure AD Tenant Module — input variables.

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

variable "tenant_orgs" {
  description = "Organizations to provision per tenant. Map of org name to config object with short code."
  type = map(object({
    code = string
  }))
  default = {
    northwind = { code = "nw" }
  }
}

variable "nxcloud_assigned_orgs" {
  description = "List of org names whose users get app role assignments to the NX Cloud enterprise app."
  type        = list(string)
  default     = []
}

variable "tags" {
  description = "Tags applied to all taggable Azure resources."
  type        = map(string)
  default     = {}
}
