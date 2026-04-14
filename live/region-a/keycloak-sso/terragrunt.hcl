# Keycloak SSO — live configuration (region-a).
# Configures Azure AD as a SAML IdP in the Keycloak realm used by NX Cloud.
# Depends on ad-tenant: reads group_display_names and nxcloud_app_client_ids.

locals {
  global_vars     = read_terragrunt_config(find_in_parent_folders("variables.hcl"))
  tenant_key      = local.global_vars.locals.active_sim_tenant_key
  azure_tenant_id = local.global_vars.locals.active_sim_tenant_id
  keycloak_url    = local.global_vars.locals.keycloak_url
  realm           = local.global_vars.locals.keycloak_realm
}

include {
  path = find_in_parent_folders("root.hcl")
}

# Pull group_display_names and nxcloud_app_client_ids from the ad-tenant stack.
dependency "ad_tenant" {
  config_path = "../ad-tenant"

  mock_outputs_allowed_terraform_commands = ["validate", "plan"]
  mock_outputs_merge_strategy_with_state  = "shallow"
  mock_outputs = {
    group_display_names          = { "mock-key" = "mock-group" }
    nxcloud_app_client_ids       = { sim2 = "00000000-0000-0000-0000-000000000000" }
    external_group_display_names = {}
  }
}

generate "keycloak_provider" {
  path      = "keycloak_provider.tf"
  if_exists = "overwrite"
  contents  = <<-EOF
    provider "keycloak" {
      client_id = "admin-cli"
      url       = "${local.keycloak_url}"
      username  = "${get_env("KEYCLOAK_USER", "")}"
      password  = "${get_env("KEYCLOAK_PASSWORD", "")}"
    }
  EOF
}

terraform {
  source = "../../../modules/keycloak-sso"
}

inputs = {
  keycloak_url = local.keycloak_url
  realm        = local.realm

  azure_tenant_id     = local.azure_tenant_id
  azure_app_client_id = dependency.ad_tenant.outputs.nxcloud_app_client_ids[local.tenant_key]

  # Retrieve the Azure AD SAML signing certificate after ad-tenant apply:
  #   SP_ID=<service-principal-object-id>
  #   TENANT_ID=027de348-f78d-44e5-93a7-f0472d5cb35a
  #   az rest --method GET \
  #     --url "https://graph.microsoft.com/v1.0/servicePrincipals/$SP_ID/tokenSigningCertificates" \
  #     --headers "Authorization=Bearer $(az account get-access-token --tenant $TENANT_ID --resource-type ms-graph --query accessToken -o tsv)" \
  #     | jq -r '.value[] | select(.isActive == true) | .rawValue'
  #
  # Pass as environment variable:  export TF_VAR_azure_ad_signing_certificate=<value>
  # Or store in a secrets manager and reference here.
  azure_ad_signing_certificate = get_env("TF_VAR_azure_ad_signing_certificate", "")

  idp_alias        = "4f97ed66-25db-427d-b660-a7fae5f337c4"
  idp_display_name = "Azure AD (${local.tenant_key})"

  # All security groups provisioned by ad-tenant — drives role creation and mappers.
  group_display_names = dependency.ad_tenant.outputs.group_display_names

  # Externally-managed Azure AD groups added to SSO via sso_external_groups in ad-tenant.
  # Each entry creates a Keycloak realm role and SAML attribute-to-role mapper.
  external_group_display_names = dependency.ad_tenant.outputs.external_group_display_names
}
