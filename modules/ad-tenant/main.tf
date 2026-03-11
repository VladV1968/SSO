# ==============================================================================
# AZURE AD TENANT MODULE - MAIN RESOURCES
# ==============================================================================
# This module provisions the complete Azure AD identity hierarchy for simulated
# multi-tenant, multi-environment CP deployments.
#
# RESOURCES CREATED (per simulated tenant):
# ┌─────────────────────────────────────────────────────────────────────────────┐
# │ azuread_application           – One app registration per tenant            │
# │ azuread_service_principal     – Backed SP for the app registration         │
# │ azuread_group                 – One per (tenant × company × env × role)    │
# │ azuread_user          (opt.)  – One per (tenant × company × role)          │
# │ azuread_group_member  (opt.)  – Maps each user to their env-specific groups│
# │ random_password               – Initial password per user                  │
# └─────────────────────────────────────────────────────────────────────────────┘
#
# IDENTITY HIERARCHY ENFORCED BY RESOURCE DEPENDENCIES:
#   azuread_application
#     → azuread_service_principal
#       → azuread_group   (scoped per env)
#         → azuread_user  (env-agnostic UPN)
#           → azuread_group_member (binds user ↔ group per env)
#
# ALL NAMES are deterministic and generated from locals.tf.
# No manual naming is required — add entries to tenant_seeds and plan/apply.
#
# PROVIDER REQUIREMENTS:
#   hashicorp/azuread >= 2.47.0
#   hashicorp/random  >= 3.5.0
# ==============================================================================

# ==============================================================================
# TERRAFORM BACKEND CONFIGURATION
# ==============================================================================
# The required_providers for azuread and random are declared in the live
# terragrunt.hcl via a generate block that produces provider.tf, which also
# includes azurerm (from root.hcl). This avoids the "duplicate required_providers"
# error caused by root.hcl generating its own provider.tf.
#
# The azuread provider block is likewise generated in the live terragrunt.hcl
# so it can receive var.tenant_id / var.client_id / var.client_secret.
# ==============================================================================
terraform {
  # Empty backend block — Terragrunt injects the azurerm backend configuration
  # from the remote_state block defined in root.hcl at plan/apply time.
  backend "azurerm" {}
}

# ==============================================================================
# APP REGISTRATIONS
# ==============================================================================
# One multi-environment application registration per simulated tenant.
# The registration is environment-agnostic — redirect URIs cover all envs.
#
# NAMING: app-sre-azr-wus-sim-<n>-cp
# LIFETIME: Persistent (not env-scoped)
# TOKEN CONFIGURATION:
#   • Group membership claims → security groups surface in access tokens
#   • Optional claims nx_env / nx_org → CP service route decisions
#   • App roles → GlobalAdmin, Support, ReadOnly
# ==============================================================================
resource "azuread_application" "cp" {
  for_each = local.flat_apps

  display_name = each.value.name

  # ── API access token version ────────────────────────────────────────────────
  # Must be explicitly set to 2 for Microsoft Entra External ID tenants.
  # The tenant only accepts v2; v1 and null are rejected with InvalidAccessTokenVersion (400).
  api {
    requested_access_token_version = 2
  }

  # ── Web platform (redirect URIs for all three environments) ─────────────────
  web {
    redirect_uris = each.value.redirect_uris
  }

  # ── Group membership claims ─────────────────────────────────────────────────
  # SecurityGroup surfaces Azure AD group object IDs in the groups claim.
  group_membership_claims = each.value.group_claims_enabled ? ["SecurityGroup"] : []

  # ── Optional claims injected into ID and access tokens ─────────────────────
  optional_claims {
    # nx_env: identifies the target environment for CP routing
    id_token {
      name = "nx_env"
    }
    access_token {
      name = "nx_env"
    }

    # nx_org: identifies the organization context within the CP
    id_token {
      name = "nx_org"
    }
    access_token {
      name = "nx_org"
    }
  }

  # ── App roles ───────────────────────────────────────────────────────────────
  # GlobalAdmin – full management access across all orgs and environments
  app_role {
    id                   = "00000000-0000-0000-0000-000000000001"
    allowed_member_types = ["User", "Application"]
    display_name         = "GlobalAdmin"
    description          = "Full administrative access to all CP features and organisations"
    value                = "GlobalAdmin"
    enabled              = true
  }

  # Support – read/write to support-scoped resources
  app_role {
    id                   = "00000000-0000-0000-0000-000000000002"
    allowed_member_types = ["User", "Application"]
    display_name         = "Support"
    description          = "Support access to assist end users across organisations"
    value                = "Support"
    enabled              = true
  }

  # ReadOnly – view-only access
  app_role {
    id                   = "00000000-0000-0000-0000-000000000003"
    allowed_member_types = ["User"]
    display_name         = "ReadOnly"
    description          = "Read-only access to CP resources without modification rights"
    value                = "ReadOnly"
    enabled              = true
  }

  tags = ["terraform", "cp", "multi-tenant"]
}

# ==============================================================================
# SERVICE PRINCIPALS
# ==============================================================================
# Enterprise application (service principal) backed by each app registration.
# Required for OAuth2 flows, group assignments, and role assignments.
# ==============================================================================
resource "azuread_service_principal" "cp" {
  for_each = local.flat_apps

  client_id = azuread_application.cp[each.key].client_id

  app_role_assignment_required = false

  tags = ["terraform", "cp", "multi-tenant"]
}

# ==============================================================================
# SECURITY GROUPS
# ==============================================================================
# One security group per (tenant × company × environment × role) combination.
# Groups are environment-specific, appear in access tokens via group claims,
# and enforce RBAC per org per environment within the CP service.
#
# NAMING: sg-sre-azr-wus-<env>-cp-org-sim-<n>-<company>-<role>
# EXAMPLE: sg-sre-azr-wus-dev-cp-org-sim-1-northwind-admin
#
# KEY FORMAT: <tenant_key>-<company>-<env>-<role>
#             e.g. "sim1-northwind-dev-admin"
# ==============================================================================
resource "azuread_group" "org_env_role" {
  for_each = local.flat_groups

  display_name     = each.value.display_name
  security_enabled = true
  mail_enabled     = false

  description = join(" | ", [
    "Tenant: ${each.value.tenant_key}",
    "Org: ${each.value.company}",
    "Env: ${each.value.env}",
    "Role: ${each.value.role}",
    "Managed by Terraform",
  ])
}

# ==============================================================================
# RANDOM PASSWORDS FOR INITIAL USER CREDENTIALS
# ==============================================================================
# Generated once per user; force_password_change = true ensures rotation on
# first login. Passwords are sensitive and never stored in Terraform state
# in plaintext beyond the initial apply.
# ==============================================================================
resource "random_password" "user" {
  for_each = var.users_enabled ? local.flat_users : {}

  length           = var.user_password_length
  special          = true
  override_special = "!@#%^&*()-_=+[]"
  min_lower        = 3
  min_upper        = 3
  min_numeric      = 3
  min_special      = 2
}

# ==============================================================================
# USERS
# ==============================================================================
# One Azure AD user per (tenant × company × role). The UPN uses the org domain
# which is environment-agnostic, ensuring a single identity surfaces across
# all environments via group membership.
#
# UPN PATTERN: <role>-org-sim-<n>-<company>@<upn_domain>
# EXAMPLE:     admin-org-sim-1-northwind@sreazrwussim1tenant.onmicrosoft.com
#
# KEY FORMAT:  <tenant_key>-<company>-<role>
#              e.g. "sim1-northwind-admin"
# ==============================================================================
resource "azuread_user" "org_role" {
  for_each = var.users_enabled ? local.flat_users : {}

  user_principal_name   = each.value.upn
  display_name          = "${title(each.value.role)} – ${title(each.value.company)} (${each.value.tenant_key})"
  mail_nickname         = "${each.value.tenant_key}-${each.value.code}-${each.value.role}"
  password              = random_password.user[each.key].result
  force_password_change = true

  # The user account is enabled by default; disable at the org level when needed.
  account_enabled = true

  lifecycle {
    # password and force_password_change are write-only in the azuread provider
    # and cannot be read back after creation. Ignoring them prevents Terraform
    # from planning a destroy+create on imported users where password is unknown.
    ignore_changes = [password, force_password_change]
  }
}

# ==============================================================================
# GROUP MEMBERSHIPS
# ==============================================================================
# Binds each user to the security group for their role in every environment.
# A user has one UPN but is a member of three groups (dev, tst, prd) for
# their role within each org — one membership per (tenant, company, env, role).
#
# KEY FORMAT: <tenant_key>-<company>-<env>-<role>
#             e.g. "sim1-northwind-dev-admin"
# ==============================================================================
resource "azuread_group_member" "user_env_role" {
  for_each = var.users_enabled ? local.flat_memberships : {}

  group_object_id  = azuread_group.org_env_role[each.value.group_key].object_id
  member_object_id = azuread_user.org_role[each.value.user_key].object_id

  depends_on = [
    azuread_group.org_env_role,
    azuread_user.org_role,
  ]
}

# ==============================================================================
# NX CLOUD ENTERPRISE APPLICATION
# ==============================================================================
# Standalone enterprise application for NX Cloud with SAML SSO.
# One registration per simulated tenant, separate from the CP app registration.
#
# SSO MODE: SAML
#   • Identifier (Entity ID) : https://test1.cloud.hwd.mx/sso/realms/default
#   • Reply URL (ACS)        : https://test1.cloud.hwd.mx/sso/realms/default/
#                               broker/<broker-id>/endpoint
#
# SETTINGS:
#   • account_enabled              = true   – Users can sign in
#   • app_role_assignment_required = true   – Only assigned users can access
#   • preferred_single_sign_on_mode = saml  – SAML 2.0 protocol
#   • feature_tags.enterprise      = true   – Visible to users in MyApps
#
# SAML ATTRIBUTES & CLAIMS:
#   Claim name                         Source attribute
#   ─────────────────────────────────────────────────────────────────
#   email                              user.mail
#   firstName                          user.givenname
#   lastName                           user.surname
#   NameId (nameidentifier)            user.userprincipalname
#   Unique User Identifier (subject)   user.userprincipalname
# ==============================================================================
resource "azuread_application" "nxcloud" {
  for_each = local.flat_nxcloud_apps

  display_name = "nx cloud"

  # NOTE: SAML Entity ID cannot be set via identifier_uris because the SP domain
  # is not verified in the Entra tenant. It is set out-of-band by
  # terraform_data.nxcloud_saml_entity_id via a local-exec Graph API PATCH.
  # Once the domain is DNS-verified in the tenant, uncomment:
  # identifier_uris = [each.value.login_url]

  # SAML Reply URL (Assertion Consumer Service URL) — sourced from
  # var.nxcloud_saml_acs_urls, keyed by tenant key. Leave empty string until
  # the Keycloak Identity Provider is configured and broker endpoint UUID is known.
  web {
    redirect_uris = each.value.acs_url != "" ? [each.value.acs_url] : []
  }

  tags = ["terraform", "nxcloud", "saml"]

  lifecycle {
    # identifier_uris cannot be set by the azuread provider because the domain
    # (test1.cloud.hwd.mx) is not verified in the External ID tenant — the
    # provider's validation rejects it even though Graph API accepts it.
    # The SAML Entity ID is set out-of-band by terraform_data.nxcloud_saml_entity_id
    # via a local-exec Graph API PATCH. Ignore drift here to prevent reversion.
    ignore_changes = [identifier_uris]
  }
}

resource "azuread_service_principal" "nxcloud" {
  for_each = local.flat_nxcloud_apps

  client_id = azuread_application.nxcloud[each.key].client_id

  # Enabled for users to sign-in: Yes
  account_enabled = true

  # Assignment required: Yes — only explicitly assigned users can access
  app_role_assignment_required = true

  # SSO mode: SAML 2.0
  preferred_single_sign_on_mode = "saml"

  # Homepage URL shown in the Azure portal SAML SSO configuration checklist.
  # Maps to the SP's loginUrl / homepage property; sourced from
  # var.nxcloud_saml_login_urls via flat_nxcloud_apps.
  login_url = each.value.login_url != "" ? each.value.login_url : null

  # Visible to users: Yes — surfaces in MyApps portal
  feature_tags {
    enterprise = true
    hide       = false
  }
}

# ==============================================================================
# NX CLOUD — SAML CLAIMS MAPPING POLICY
# ==============================================================================
# Maps SAML token attributes to user directory attributes.
# IncludeBasicClaimSet = true retains standard claims alongside custom ones.
#
# Custom claim names:
#   email     → user.mail
#   firstName → user.givenname
#   lastName  → user.surname
#   NameID    → user.userprincipalname  (nameidentifier + subject)
# ==============================================================================
resource "azuread_claims_mapping_policy" "nxcloud_saml" {
  for_each = local.flat_nxcloud_apps

  display_name = "nxcloud-saml-claims-${each.key}"

  definition = [jsonencode({
    ClaimsMappingPolicy = {
      Version              = 1
      IncludeBasicClaimSet = "true"
      ClaimsSchema = [
        # email → user.mail
        {
          SamlClaimType = "email"
          Source        = "user"
          ID            = "mail"
        },
        # firstName → user.givenname
        {
          SamlClaimType = "firstName"
          Source        = "user"
          ID            = "givenname"
        },
        # lastName → user.surname
        {
          SamlClaimType = "lastName"
          Source        = "user"
          ID            = "surname"
        },
        # NameId (Unique User Identifier) → user.userprincipalname
        {
          SamlClaimType = "http://schemas.xmlsoap.org/ws/2005/05/identity/claims/nameidentifier"
          Source        = "user"
          ID            = "userprincipalname"
        },
        # Security group memberships → group object IDs
        # NOTE: when a claims mapping policy is assigned to the SP, Azure ignores
        # groupMembershipClaims on the app manifest — groups MUST appear here.
        # Values emitted are Azure AD security group object IDs.
        {
          SamlClaimType = "http://schemas.microsoft.com/ws/2008/06/identity/claims/groups"
          Source        = "user"
          ID            = "groups"
        }
      ]
    }
  })]
}

resource "azuread_service_principal_claims_mapping_policy_assignment" "nxcloud_saml" {
  for_each = local.flat_nxcloud_apps

  claims_mapping_policy_id = azuread_claims_mapping_policy.nxcloud_saml[each.key].id
  service_principal_id     = azuread_service_principal.nxcloud[each.key].object_id

  depends_on = [azuread_service_principal.nxcloud]
}

# ==============================================================================
# NX CLOUD — SAML ENTITY ID (IDENTIFIER URI)
# ==============================================================================
# The azuread provider rejects identifier_uris for unverified domains, but
# Microsoft Graph API accepts them. This resource uses a local-exec provisioner
# to PATCH the application after creation, setting the SAML Entity ID that
# Keycloak/NX Cloud sends in SAML AuthN requests.
#
# azuread_application.nxcloud has lifecycle.ignore_changes on identifier_uris
# so subsequent plans do not revert this out-of-band setting.
#
# REQUIRES: var.sim_tenant_ids to be populated so a cross-tenant token can be
# acquired via: az account get-access-token --tenant <sim-tenant-id>
# ==============================================================================
resource "terraform_data" "nxcloud_saml_entity_id" {
  for_each = local.flat_nxcloud_apps

  # Triggers re-run when the application object ID changes (e.g. after recreate)
  input = replace(azuread_application.nxcloud[each.key].id, "/applications/", "")

  provisioner "local-exec" {
    interpreter = ["pwsh", "-Command"]
    # Terraform ${...} interpolations are resolved before the command runs.
    # Bare $var PowerShell variables are left as-is by Terraform's template engine.
    # Use $(...) subexpressions in PS strings where a colon immediately follows
    # a variable (e.g. "Bearer $($tok)") to avoid PS scope-qualifier ambiguity.
    command     = <<-EOT
      $tenantId = "${each.value.tenant_id}"
      if (-not $tenantId) {
        Write-Warning "sim_tenant_ids['${each.key}'] not configured - skipping SAML Entity ID provisioning"
        exit 0
      }
      $tok = (az account get-access-token --tenant $tenantId --resource-type ms-graph --query accessToken -o tsv 2>&1)
      if ($LASTEXITCODE -ne 0) { Write-Error "Failed to acquire Graph API token for tenant $tenantId"; exit 1 }
      $body = '{"identifierUris":["https://test1.cloud.hwd.mx/sso/realms/default"]}'
      try {
        Invoke-RestMethod -Method PATCH `
          -Uri "https://graph.microsoft.com/v1.0/applications/${self.input}" `
          -Headers @{Authorization="Bearer $($tok)"; "Content-Type"="application/json"} `
          -Body $body | Out-Null
        Write-Host "SAML Entity ID set for ${each.key}"
      } catch {
        Write-Error "Failed to set SAML Entity ID: $($Error[0])"
        exit 1
      }
    EOT
  }

  depends_on = [azuread_application.nxcloud]
}

# ==============================================================================
# NX CLOUD — SAML TOKEN SIGNING CERTIFICATE
# ==============================================================================
# Azure Portal shows "Single sign-on is not configured" until a SAML token
# signing certificate exists on the enterprise application SP. The azuread
# Terraform provider does not support creating SAML signing certificates, so
# this resource calls the Graph API addTokenSigningCertificate action instead.
#
# IDEMPOTENT: the provisioner checks for an existing Sign keyCredential before
# calling the API, so re-applying after the cert exists is a no-op.
#
# The cert is self-signed, valid for 3 years, and identical to what the Azure
# Portal creates automatically when SAML SSO is configured interactively.
# ==============================================================================
resource "terraform_data" "nxcloud_saml_signing_cert" {
  for_each = local.flat_nxcloud_apps

  # Triggers re-run when the SP object_id changes (e.g. after destroy/recreate)
  input = azuread_service_principal.nxcloud[each.key].object_id

  provisioner "local-exec" {
    # Use environment variables to pass runtime values into the PS script.
    # This avoids Terraform template-engine / PowerShell variable-name conflicts.
    environment = {
      TENANT_ID = each.value.tenant_id
      SP_ID     = self.input
    }
    interpreter = ["pwsh", "-Command"]
    command     = <<-EOT
      if (-not $env:TENANT_ID) {
        Write-Warning "sim_tenant_ids['${each.key}'] not set - skipping SAML signing cert"
        exit 0
      }
      $tok = (az account get-access-token --tenant $env:TENANT_ID --resource-type ms-graph --query accessToken -o tsv 2>&1)
      if ($LASTEXITCODE -ne 0) { Write-Error "Token error: $tok"; exit 1 }
      $headers = @{Authorization="Bearer $($tok)"; "Content-Type"="application/json"}
      # Idempotency check: skip if a Sign cert already exists
      $sp = Invoke-RestMethod -Uri "https://graph.microsoft.com/v1.0/servicePrincipals/$env:SP_ID`?`$select=keyCredentials" -Headers $headers
      if ($sp.keyCredentials | Where-Object { $_.usage -eq 'Sign' }) {
        Write-Host "SAML signing cert already present on $env:SP_ID - no-op"
        exit 0
      }
      # Create self-signed SAML token signing certificate (3-year validity)
      $endDate = (Get-Date).AddYears(3).AddDays(-2).ToUniversalTime().ToString("yyyy-MM-ddTHH:mm:ssZ")
      $body = "{`"displayName`":`"CN=Microsoft Azure Federated SSO Certificate`",`"endDateTime`":`"$endDate`"}"
      try {
        $cert = Invoke-RestMethod -Method POST `
          -Uri "https://graph.microsoft.com/v1.0/servicePrincipals/$env:SP_ID/addTokenSigningCertificate" `
          -Headers $headers -Body $body
        Write-Host "SAML signing cert created for ${each.key}: thumbprint=$($cert.thumbprint)"
      } catch {
        Write-Error "addTokenSigningCertificate failed: $($Error[0])"
        exit 1
      }
    EOT
  }

  depends_on = [azuread_service_principal.nxcloud]
}

# ==============================================================================
# NX CLOUD — CONTOSO (SIM-1) USER ASSIGNMENTS
# ==============================================================================
# Assigns all three Contoso users (admin, user, viewer) from each active
# sim tenant to the nx cloud enterprise application.
# Uses the default app role (all-zeros UUID) since nx cloud has no custom roles.
#
# KEY FORMAT: "<tenant_key>-contoso-<role>"   e.g. "sim1-contoso-admin"
# ==============================================================================
resource "azuread_app_role_assignment" "nxcloud_contoso" {
  for_each = var.users_enabled ? local.flat_nxcloud_contoso_assignments : {}

  # Default app role (no specific role required for access)
  app_role_id = "00000000-0000-0000-0000-000000000000"

  principal_object_id = azuread_user.org_role[each.value.user_key].object_id
  resource_object_id  = azuread_service_principal.nxcloud[each.value.tenant_key].object_id

  depends_on = [
    azuread_service_principal.nxcloud,
    azuread_user.org_role,
  ]
}
