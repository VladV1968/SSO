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
  display_name          = "${title(each.value.role)} – ${title(each.value.company)} (${each.value.tenant_key})"
  mail_nickname         = "${each.value.tenant_key}-${each.value.code}-${each.value.role}"
  given_name            = title(each.value.role)
  surname               = title(each.value.company)
  password              = random_password.user[each.key].result
  force_password_change = true
  account_enabled       = true
  usage_location        = var.usage_location

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

  display_name            = var.nxcloud_app_display_name
  group_membership_claims = ["SecurityGroup"]

  api {
    requested_access_token_version = 2
  }

  # SAML Entity ID set out-of-band via terraform_data.nxcloud_saml_entity_id
  # because the domain is not verified in Entra. Ignored to prevent reversion.
  web {
    redirect_uris = each.value.acs_url != "" ? [each.value.acs_url] : []
  }

  # Emit group display names (e.g. sg-sim1-nw-dev-admin) instead of object IDs
  # in the SAML groups claim. Custom claims mapping policies cannot override this
  # behaviour — optional_claims with cloud_displayname is the correct mechanism.
  optional_claims {
    saml2_token {
      name                  = "groups"
      additional_properties = ["cloud_displayname"]
    }
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
    custom_single_sign_on = true
    enterprise            = true
    hide                  = false
  }
}

# ── NX Cloud SAML Claims Mapping Policy ──────────────────────────────────────
# Maps: email, firstName, lastName, NameID (UPN).
# Groups are handled separately via optional_claims on azuread_application.
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
        # Groups claim is intentionally omitted here. It is handled via
        # optional_claims { saml2_token { name = "groups", additional_properties = ["cloud_displayname"] } }
        # on the azuread_application resource, which emits display names instead of object IDs.
        # Defining it here alongside optional_claims causes claim conflicts in Entra.
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
      $entityId = "${each.value.entity_id}"
      if (-not $entityId) {
        Write-Warning "nxcloud_saml_entity_ids['${each.key}'] not configured - skipping SAML Entity ID provisioning"
        exit 0
      }
      $tok = (az account get-access-token --tenant $tenantId --resource-type ms-graph --query accessToken -o tsv 2>&1)
      if ($LASTEXITCODE -ne 0) { Write-Error "Failed to acquire Graph API token for tenant $tenantId"; exit 1 }
      $body = "{`"identifierUris`":[`"$entityId`"]}"
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
      $existingSign = $sp.keyCredentials | Where-Object { $_.usage -eq 'Sign' }
      if ($existingSign) {
        # Cert exists — ensure it is selected as the active signing key.
        $raw = [Convert]::FromBase64String($existingSign.customKeyIdentifier)
        $hex = ($raw | ForEach-Object { '{0:X2}' -f $_ }) -join ''
        $thumbBody = "{`"preferredTokenSigningKeyThumbprint`":`"$hex`"}"
        Invoke-RestMethod -Method PATCH `
          -Uri "https://graph.microsoft.com/v1.0/servicePrincipals/$env:SP_ID" `
          -Headers $headers -Body $thumbBody | Out-Null
        Write-Host "SAML signing cert already present on $env:SP_ID - ensured active key: $hex"
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
      # Set the newly created cert as the active signing key so the SAML config
      # page renders correctly in the Azure Portal.
      $thumbBody = "{`"preferredTokenSigningKeyThumbprint`":`"$($cert.thumbprint)`"}"
      Invoke-RestMethod -Method PATCH `
        -Uri "https://graph.microsoft.com/v1.0/servicePrincipals/$env:SP_ID" `
        -Headers $headers -Body $thumbBody | Out-Null
      Write-Host "Active signing key set for ${each.key}: $($cert.thumbprint)"
    EOT
  }

  depends_on = [azuread_service_principal.nxcloud]
}

# ── NX Cloud User Assignments ────────────────────────────────────────────────
# Assigns security groups from orgs listed in var.nxcloud_assigned_orgs to the NX Cloud app.
resource "azuread_app_role_assignment" "nxcloud_group" {
  for_each = local.flat_nxcloud_group_assignments

  app_role_id         = "00000000-0000-0000-0000-000000000000"
  principal_object_id = azuread_group.org_env_role[each.value.group_key].object_id
  resource_object_id  = azuread_service_principal.nxcloud[each.value.tenant_key].object_id

  depends_on = [
    azuread_service_principal.nxcloud,
    azuread_group.org_env_role,
  ]
}

# ── External Security Group Assignments ──────────────────────────────────────
# Assigns pre-existing Azure AD security groups to the NX Cloud enterprise app.
# Use for groups not managed by this module (e.g. existing RBAC or real-user groups).
# Keycloak-sso will create a matching realm role and SAML mapper via external_group_display_names output.
resource "azuread_app_role_assignment" "nxcloud_external_group" {
  for_each = var.sso_external_groups

  app_role_id         = "00000000-0000-0000-0000-000000000000"
  principal_object_id = each.value.object_id
  resource_object_id  = azuread_service_principal.nxcloud[each.value.tenant_key].object_id

  depends_on = [azuread_service_principal.nxcloud]
}

# ── External User Assignments ─────────────────────────────────────────────────
# Assigns pre-existing Azure AD users directly to the NX Cloud enterprise app.
# These users authenticate via SSO without requiring group membership.
# Note: Keycloak roles are still assigned via group membership in the SAML assertion.
resource "azuread_app_role_assignment" "nxcloud_external_user" {
  for_each = var.sso_external_users

  app_role_id         = "00000000-0000-0000-0000-000000000000"
  principal_object_id = each.value.object_id
  resource_object_id  = azuread_service_principal.nxcloud[each.value.tenant_key].object_id

  depends_on = [azuread_service_principal.nxcloud]
}

# ── Role-Based Group Memberships for Existing Users ───────────────────────────
# Adds pre-existing Azure AD users to managed role security groups.
# Grants SSO access and the Keycloak role associated with that group.
# group_key must reference a key in local.flat_groups (e.g. "sim1-northwind-dev-admin").
resource "azuread_group_member" "sso_role_user" {
  for_each = var.sso_role_user_memberships

  group_object_id  = azuread_group.org_env_role[each.value.group_key].object_id
  member_object_id = each.value.user_object_id

  depends_on = [azuread_group.org_env_role]
}


