# ==============================================================================
# AZURE AD TENANT MODULE VARIABLES
# ==============================================================================
# Input variables for the ad-tenant module. These variables control provider
# authentication and optional overrides for the identity hierarchy.
#
# VARIABLE CATEGORIES:
# ┌─────────────────────────────────────────────────────────────────────────────┐
# │ PROVIDER / AUTHENTICATION:                                                  │
# │ • tenant_id         – Azure AD tenant GUID for the azuread provider        │
# │ • client_id         – Service principal / app ID for Terraform auth        │
# │ • client_secret     – SP secret (use Key Vault reference in CI/CD)         │
# │                                                                             │
# │ MODULE BEHAVIOUR:                                                           │
# │ • users_enabled     – Toggle user creation (false for read-only tenants)   │
# │ • user_password_len – Length of generated initial user passwords           │
# │                                                                             │
# │ TAGGING AND GOVERNANCE:                                                     │
# │ • tags              – Common tags applied to all taggable resources        │
# └─────────────────────────────────────────────────────────────────────────────┘
# ==============================================================================

# ==============================================================================
# PROVIDER / AUTHENTICATION VARIABLES
# ==============================================================================
# The azuread provider authenticates using the same ARM_* environment variables
# as the azurerm provider:
#   ARM_TENANT_ID      – Azure AD tenant GUID
#   ARM_CLIENT_ID      – Service principal client ID
#   ARM_CLIENT_SECRET  – Service principal client secret
#
# No explicit credential variables are declared in this module. Set the above
# environment variables in your shell or CI/CD pipeline before running
# terragrunt plan / apply.
# ==============================================================================

# ==============================================================================
# MODULE BEHAVIOUR VARIABLES
# ==============================================================================

variable "users_enabled" {
  description = <<-EOT
    Controls whether azuread_user resources are created for each (tenant, org,
    role) combination in the simulated_tenants hierarchy.

    Set to false for tenants where user objects are managed externally (e.g.
    synchronized from on-premises Active Directory or managed by another module).

    DEFAULT: true (users are created)
  EOT
  type    = bool
  default = true
}

variable "user_password_length" {
  description = <<-EOT
    Length of the randomly generated initial password assigned to each user.
    Passwords are marked as sensitive and force_password_change is set to true
    so users must rotate on first login.

    MINIMUM: 16 characters (Azure AD password complexity requirement)
    DEFAULT: 20
  EOT
  type    = number
  default = 20

  validation {
    condition     = var.user_password_length >= 16
    error_message = "user_password_length must be at least 16 to satisfy Azure AD password complexity requirements."
  }
}

# ==============================================================================
# USER IDENTITY VARIABLES
# ==============================================================================

variable "sim_tenant_upn_domains" {
  description = <<-EOT
    Map from tenant key (e.g. "sim1") to the verified UPN domain suffix to use
    for user principal names within that simulated tenant.

    When a new Azure AD / Entra External ID tenant is created, the only
    verified domain is <tenant-name>.onmicrosoft.com.  Custom domains require
    DNS TXT verification before they can be used as UPN suffixes, so by default
    this variable should point to the tenant's onmicrosoft.com domain.

    UPN PATTERN  : <role>-org-sim-<n>-<company>@<upn_domain>
    EXAMPLE      : admin-org-sim-1-northwind@sreazrwussim1tenant.onmicrosoft.com

    KEYS must match the keys in tenant_seeds inside the module (e.g. sim1, sim2).
  EOT
  type    = map(string)
  default = {}

  validation {
    condition     = alltrue([for v in values(var.sim_tenant_upn_domains) : can(regex("^[a-zA-Z0-9.-]+\\.[a-zA-Z]{2,}$", v))])
    error_message = "Each value in sim_tenant_upn_domains must be a valid domain name (e.g. \"sreazrwussim1tenant.onmicrosoft.com\")."
  }
}

# ==============================================================================
# PROVISIONER AUTHENTICATION VARIABLES
# ==============================================================================

variable "sim_tenant_ids" {
  description = <<-EOT
    Map from tenant key (e.g. "sim1") to the Azure AD tenant GUID for that
    simulated tenant. Used by local-exec provisioners that must acquire a
    cross-tenant Graph API token to perform operations the azuread provider
    cannot do (e.g. setting identifier_uris to an unverified domain for SAML).

    Keys must match the keys in tenant_seeds inside the module (e.g. sim1, sim2).
    If a key is absent the corresponding provisioner step is skipped.

    EXAMPLE: { sim1 = "cec91f60-5cf7-469c-8b65-88f05a0dbca8" }
  EOT
  type    = map(string)
  default = {}
}

variable "nxcloud_saml_login_urls" {
  description = <<-EOT
    Map from tenant key (e.g. "sim2") to the NX Cloud SAML homepage / login URL
    for that simulated tenant. This value is written to the enterprise application
    service principal as the "Homepage URL" (loginUrl) visible in the Azure portal
    SAML SSO configuration page.

    Typically this is the Keycloak realm root URL that Keycloak uses as the
    SAML Entity ID / Service Provider initiator URL.

    Keys must match the keys in tenant_seeds inside the module (e.g. sim1, sim2).
    If a key is absent the login_url field is left empty (SP homepage not set).

    EXAMPLE: { sim2 = "https://test2.cloud.hwd.mx/sso/realms/default" }
  EOT
  type    = map(string)
  default = {}
}

variable "nxcloud_saml_acs_urls" {
  description = <<-EOT
    Map from tenant key (e.g. "sim2") to the NX Cloud SAML Assertion Consumer
    Service (ACS) URL for that simulated tenant. This is the Keycloak broker
    endpoint that receives the SAML response from Azure AD.

    Leave the value as an empty string until the Keycloak Identity Provider is
    configured and the broker endpoint UUID is known. An empty string means
    no redirect_uri is set on the application (safe — the ACS URL can be added
    later without disrupting other config).

    Pattern: https://test<n>.cloud.hwd.mx/sso/realms/default/broker/<uuid>/endpoint
    Keys must match the keys in tenant_seeds inside the module (e.g. sim1, sim2).

    EXAMPLE: { sim2 = "https://test2.cloud.hwd.mx/sso/realms/default/broker/abc123/endpoint" }
  EOT
  type    = map(string)
  default = {}
}

# ==============================================================================
# TAGGING AND GOVERNANCE VARIABLES
# ==============================================================================

variable "tags" {
  description = <<-EOT
    Map of tags applied to all taggable Azure resources created by this module.
    These tags support cost allocation, governance, and compliance requirements.

    RECOMMENDED TAGS:
      tags = {
        ManagedBy   = "Terraform"
        Module      = "ad-tenant"
        Environment = "shared"
        CostCenter  = "sre-platform"
        Owner       = "sre-team@example.com"
      }
  EOT
  type    = map(string)
  default = {}
}
