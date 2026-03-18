# Azure AD Tenant Module — main resources.
# Creates groups, users, group memberships, NX Cloud enterprise app with SAML SSO.

terraform {
  backend "azurerm" {}
}

# ── Security Groups ──────────────────────────────────────────────────────────
# One per (tenant × company × environment × role).
# Key: "<tenant_key>-<company>-<env>-<role>"
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

# ── Random Passwords ─────────────────────────────────────────────────────────
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

# ── Users ────────────────────────────────────────────────────────────────────
# One per (tenant × company × role). UPN is env-agnostic.
# Key: "<tenant_key>-<company>-<role>"
resource "azuread_user" "org_role" {
  for_each = var.users_enabled ? local.flat_users : {}

  user_principal_name   = each.value.upn
  mail                  = each.value.upn
  display_name          = "${title(each.value.role)} – ${title(each.value.company)} (${each.value.tenant_key})"
  mail_nickname         = "${each.value.tenant_key}-${each.value.code}-${each.value.role}"
  password              = random_password.user[each.key].result
  force_password_change = true
  account_enabled       = true
  usage_location        = "US"

  lifecycle {
    ignore_changes = [password, force_password_change]
  }
}

# ── Group Memberships ────────────────────────────────────────────────────────
# Binds each user to their role's security group in every environment.
# Key: "<tenant_key>-<company>-<env>-<role>"
resource "azuread_group_member" "user_env_role" {
  for_each = var.users_enabled ? local.flat_memberships : {}

  group_object_id  = azuread_group.org_env_role[each.value.group_key].object_id
  member_object_id = azuread_user.org_role[each.value.user_key].object_id

  depends_on = [
    azuread_group.org_env_role,
    azuread_user.org_role,
  ]
}

# ── NX Cloud Application (SAML) ─────────────────────────────────────────────
# One enterprise app per simulated tenant for NX Cloud SSO.
resource "azuread_application" "nxcloud" {
  for_each = local.flat_nxcloud_apps

  display_name = "nx cloud"

  api {
    requested_access_token_version = 2
  }

  # SAML Entity ID set out-of-band via terraform_data.nxcloud_saml_entity_id
  # because the domain is not verified in Entra. Ignored to prevent reversion.
  web {
    redirect_uris = each.value.acs_url != "" ? [each.value.acs_url] : []
  }

  tags = ["terraform", "nxcloud", "saml"]

  lifecycle {
    ignore_changes = [identifier_uris]
  }
}

# ── NX Cloud Service Principal ───────────────────────────────────────────────
resource "azuread_service_principal" "nxcloud" {
  for_each = local.flat_nxcloud_apps

  client_id                     = azuread_application.nxcloud[each.key].client_id
  account_enabled               = true
  app_role_assignment_required  = true
  preferred_single_sign_on_mode = "saml"
  login_url                     = each.value.login_url != "" ? each.value.login_url : null

  feature_tags {
    enterprise = true
    hide       = false
  }
}

# ── NX Cloud SAML Claims Mapping Policy ──────────────────────────────────────
# Maps: email, firstName, lastName, NameID (UPN), groups.
resource "azuread_claims_mapping_policy" "nxcloud_saml" {
  for_each = local.flat_nxcloud_apps

  display_name = "nxcloud-saml-claims-${each.key}"

  definition = [jsonencode({
    ClaimsMappingPolicy = {
      Version              = 1
      IncludeBasicClaimSet = "true"
      ClaimsSchema = [
        { SamlClaimType = "email", Source = "user", ID = "mail" },
        { SamlClaimType = "firstName", Source = "user", ID = "givenname" },
        { SamlClaimType = "lastName", Source = "user", ID = "surname" },
        {
          SamlClaimType = "http://schemas.xmlsoap.org/ws/2005/05/identity/claims/nameidentifier"
          Source        = "user"
          ID            = "userprincipalname"
        },
        {
          SamlClaimType = "http://schemas.microsoft.com/ws/2008/06/identity/claims/groups"
          Source        = "user"
          ID            = "groups"
        }
      ]
    }
  })]
}

# ── Claims Policy → SP Assignment ────────────────────────────────────────────
resource "azuread_service_principal_claims_mapping_policy_assignment" "nxcloud_saml" {
  for_each = local.flat_nxcloud_apps

  claims_mapping_policy_id = azuread_claims_mapping_policy.nxcloud_saml[each.key].id
  service_principal_id     = azuread_service_principal.nxcloud[each.key].object_id

  depends_on = [azuread_service_principal.nxcloud]
}

# ── NX Cloud SAML Entity ID (out-of-band Graph API PATCH) ────────────────────
# azuread provider rejects identifier_uris for unverified domains; Graph API
# accepts them. Sets SAML Entity ID after app creation.
resource "terraform_data" "nxcloud_saml_entity_id" {
  for_each = local.flat_nxcloud_apps

  input = replace(azuread_application.nxcloud[each.key].id, "/applications/", "")

  provisioner "local-exec" {
    interpreter = ["pwsh", "-Command"]
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

# ── NX Cloud SAML Token Signing Certificate ──────────────────────────────────
# Creates a self-signed SAML signing cert via Graph API (idempotent).
resource "terraform_data" "nxcloud_saml_signing_cert" {
  for_each = local.flat_nxcloud_apps

  input = azuread_service_principal.nxcloud[each.key].object_id

  provisioner "local-exec" {
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
      $sp = Invoke-RestMethod -Uri "https://graph.microsoft.com/v1.0/servicePrincipals/$env:SP_ID`?`$select=keyCredentials" -Headers $headers
      if ($sp.keyCredentials | Where-Object { $_.usage -eq 'Sign' }) {
        Write-Host "SAML signing cert already present on $env:SP_ID - no-op"
        exit 0
      }
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

# ── NX Cloud User Assignments ────────────────────────────────────────────────
# Assigns users from orgs listed in var.nxcloud_assigned_orgs to the NX Cloud app.
resource "azuread_app_role_assignment" "nxcloud_user" {
  for_each = var.users_enabled ? local.flat_nxcloud_user_assignments : {}

  app_role_id         = "00000000-0000-0000-0000-000000000000"
  principal_object_id = azuread_user.org_role[each.value.user_key].object_id
  resource_object_id  = azuread_service_principal.nxcloud[each.value.tenant_key].object_id

  depends_on = [
    azuread_service_principal.nxcloud,
    azuread_user.org_role,
  ]
}


