# Keycloak Realm Module — input variables.
# Realm name = tenant identifier. No tenant prefix inside any resource name.

# ── Realm ─────────────────────────────────────────────────────────────────────

variable "realm" {
  description = "Realm name — doubles as the tenant identifier (e.g. sim2, acme)."
  type        = string
}

# ── Identity hierarchy ────────────────────────────────────────────────────────

variable "tenant_orgs" {
  description = "Organizations within this realm. Map of org_name → { code }."
  type = map(object({
    code = string
  }))
  default = {
    northwind = { code = "nw" }
  }
}

variable "environments" {
  description = "Environment names to provision groups for."
  type        = list(string)
  default     = ["dev", "tst", "qa", "qa2", "prd"]
}

variable "roles" {
  description = "Role names to provision per environment."
  type        = list(string)
  default     = ["admin", "user", "viewer"]
}

# ── Naming ────────────────────────────────────────────────────────────────────

variable "group_prefix" {
  description = "Prefix for group display names (e.g. 'sg' → sg-nw-dev-admin)."
  type        = string
  default     = "sg"
}

# ── Users ─────────────────────────────────────────────────────────────────────

variable "users_enabled" {
  description = "Whether to create internal Keycloak users and group memberships."
  type        = bool
  default     = true
}

variable "user_password_length" {
  description = "Length of generated initial passwords (minimum 16)."
  type        = number
  default     = 20

  validation {
    condition     = var.user_password_length >= 16
    error_message = "user_password_length must be at least 16."
  }
}

variable "user_email_base_domain" {
  description = "Base email domain. Full email = {org_code}-{role}@{realm}.{base_domain}."
  type        = string
  default     = "nxteam.dev"
}

# ── NX Cloud SAML ─────────────────────────────────────────────────────────────

variable "keycloak_url" {
  description = "Keycloak base URL (e.g. https://idp-keycloak.cloud.nxteam.dev/auth). Used to compute SAML metadata outputs."
  type        = string
  default     = ""
}

variable "nxcloud_enabled" {
  description = "Whether to create the NX Cloud SAML client."
  type        = bool
  default     = false
}

variable "nxcloud_url" {
  description = "NX Cloud base URL (e.g. https://nx.cloud.nxteam.dev). Used for SAML callback URI."
  type        = string
  default     = ""
}
