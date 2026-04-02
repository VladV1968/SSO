# keycloak-sso Module

Configures Keycloak to broker authentication from Azure AD via SAML 2.0 for NX Cloud.

## What it does

One module invocation configures a single SIM tenant's identity provider in a Keycloak realm:

- **Azure AD SAML IdP** — registers Azure AD as a SAML 2.0 identity provider in Keycloak; unauthenticated users are redirected to Azure AD's SSO endpoint
- **Attribute importers** — maps `email`, `firstName`, and `lastName` from SAML assertion attributes into the Keycloak user profile
- **Realm roles** — creates one Keycloak realm role per security group (both managed groups from ad-tenant and externally-managed groups)
- **SAML attribute-to-role mappers** — maps each Azure AD group display name from the SAML assertion to the corresponding Keycloak realm role

### Authentication flow

```
User → NX Cloud → Keycloak
                 → Azure AD (SAML AuthnRequest via POST binding)
                 ← SAML assertion (email, firstName, lastName, groups)
                 Attribute importers fire → user profile populated
                 Group-to-role mappers fire → realm roles assigned
                 → Keycloak token issued to NX Cloud
```

## Prerequisites

### Keycloak

- Keycloak instance running and accessible at `keycloak_url`
- Realm already created (the module configures an existing realm, it does not create one)
- Admin credentials available — the Keycloak provider reads them from environment variables:
  ```bash
  export KEYCLOAK_USER=<admin-username>
  export KEYCLOAK_PASSWORD=<admin-password>
  ```

### Azure AD (from ad-tenant module)

The following outputs from the `ad-tenant` module are required inputs:

| ad-tenant output | keycloak-sso input | Description |
|---|---|---|
| `group_display_names` | `group_display_names` | All managed security groups |
| `external_group_display_names` | `external_group_display_names` | All external groups added to SSO |
| `nxcloud_app_client_ids[tenant_key]` | `azure_app_client_id` | Enterprise app client ID |

### SAML signing certificate

Before running this module, retrieve the active SAML signing certificate from the Azure AD service principal created by ad-tenant:

```bash
SP_ID=<service-principal-object-id>
TENANT_ID=<azure-ad-tenant-id>

az rest --method GET \
  --url "https://graph.microsoft.com/v1.0/servicePrincipals/$SP_ID/tokenSigningCertificates" \
  --headers "Authorization=Bearer $(az account get-access-token --tenant $TENANT_ID --resource-type ms-graph --query accessToken -o tsv)" \
  | jq -r '.value[] | select(.isActive == true) | .rawValue'
```

Set the result as an environment variable:

```bash
export TF_VAR_azure_ad_signing_certificate=<base64-value>
```

The value is a base64-encoded DER certificate (no PEM headers). Do not store it in plaintext in source control.

### Tools

| Tool | Version | Purpose |
|---|---|---|
| Terraform | >= 1.0 | Infrastructure provisioning |
| Terragrunt | >= 0.45 | Configuration management |
| Azure CLI (`az`) | Latest | Token acquisition (for prereq cert retrieval) |

### Providers

| Provider | Source | Version |
|---|---|---|
| `mrparkers/keycloak` | `mrparkers/keycloak` | `~> 4.4` |
| `hashicorp/azurerm` | `hashicorp/azurerm` | `~> 4.35` |

## Variables

### Keycloak connection

| Variable | Type | Default | Description |
|---|---|---|---|
| `keycloak_url` | `string` | — | Base URL of the Keycloak server (no trailing slash). |
| `realm` | `string` | `default` | Keycloak realm to configure. |

### Azure AD IdP

| Variable | Type | Default | Description |
|---|---|---|---|
| `azure_tenant_id` | `string` | — | Azure AD tenant GUID for the SIM tenant. Used to build Azure AD SAML endpoint URLs. |
| `azure_app_client_id` | `string` | — | Enterprise app client ID from ad-tenant. Used to construct the federation metadata URL. |
| `azure_ad_signing_certificate` | `string` (sensitive) | — | Base64 DER certificate used by Azure AD to sign SAML assertions. Retrieve after ad-tenant apply. |
| `idp_alias` | `string` | `azure-ad` | Keycloak IdP alias. Must match the path segment in the ACS URL registered in Azure AD (e.g. `…/broker/azure-ad/endpoint`). |
| `idp_display_name` | `string` | `Azure AD` | Label shown on the Keycloak login UI. |

### SAML claim attribute names

These must match the `SamlClaimType` values in the Azure AD claims mapping policy created by ad-tenant.

| Variable | Type | Default | Description |
|---|---|---|---|
| `saml_attribute_email` | `string` | `email` | SAML attribute name for user email. |
| `saml_attribute_first_name` | `string` | `firstName` | SAML attribute name for given name. |
| `saml_attribute_last_name` | `string` | `lastName` | SAML attribute name for surname. |
| `saml_attribute_groups` | `string` | `http://schemas.microsoft.com/ws/2008/06/identity/claims/groups` | SAML attribute carrying Azure AD group display names. |

### Group-to-role mapping

| Variable | Type | Default | Description |
|---|---|---|---|
| `group_display_names` | `map(string)` | — | Map of group key → display name. Sourced from `ad-tenant.group_display_names`. Required. |
| `external_group_display_names` | `map(string)` | `{}` | Map of group key → display name for externally-managed groups. Sourced from `ad-tenant.external_group_display_names`. |

## Outputs

| Output | Description |
|---|---|
| `idp_alias` | Alias of the Azure AD SAML IdP registered in Keycloak. Matches the path segment in the ACS URL. |
| `role_names` | Map of group key → Keycloak realm role name for all groups (managed and external). |

## Deployment

### Apply order

This module must be applied **after** `ad-tenant`. The Terragrunt live config uses a `dependency` block to read ad-tenant outputs automatically.

```bash
cd live/region-a/keycloak-sso

export KEYCLOAK_USER=<admin-username>
export KEYCLOAK_PASSWORD=<admin-password>
export TF_VAR_azure_ad_signing_certificate=<base64-cert>

terragrunt init
terragrunt plan
terragrunt apply
```

### Plan with mock outputs

During development, plan without a real ad-tenant state using Terragrunt mock outputs:

```bash
terragrunt plan
```

The `dependency.ad_tenant` block has `mock_outputs_allowed_terraform_commands = ["validate", "plan"]` — plan succeeds with placeholder values.

### Updating groups

When security groups are added or removed in ad-tenant, re-apply keycloak-sso to sync realm roles and mappers:

```bash
terragrunt apply  # from live/region-a/keycloak-sso
```

Terragrunt reads the updated `ad-tenant` outputs automatically via the dependency block.

## Operational notes

### IdP alias and ACS URL must match

The `idp_alias` variable controls the URL path segment in Keycloak's SAML ACS endpoint:

```
{keycloak_url}/realms/{realm}/broker/{idp_alias}/endpoint
```

This URL is registered in Azure AD (`nxcloud_saml_acs_urls` in ad-tenant). Changing `idp_alias` after initial deployment requires updating the ACS URL in Azure AD and re-applying both modules.

### Sync mode

The IdP is configured with `sync_mode = "FORCE"`. Keycloak re-imports user attributes (email, firstName, lastName) from the SAML assertion on every login. Changes to a user's profile in Azure AD propagate to Keycloak automatically without manual intervention.

### First broker login flow

The `first_broker_login_flow_alias = "first broker login"` setting links existing Keycloak users to their Azure AD identity by email on first SSO login. Users created before SSO was enabled are matched automatically without requiring re-registration.

### Signing certificate rotation

When the Azure AD SAML signing certificate is rotated:

1. Retrieve the new certificate value (see [Prerequisites](#saml-signing-certificate)).
2. Update `TF_VAR_azure_ad_signing_certificate`.
3. Run `terragrunt apply` — Keycloak will begin accepting assertions signed by the new certificate.

There is no downtime if the old certificate is kept active in Azure AD during the transition window.

### Adding external groups

Add entries to `sso_external_groups` in the ad-tenant live config, then re-apply ad-tenant followed by keycloak-sso. The `external_group_display_names` output is passed through the Terragrunt dependency and automatically creates the new realm role and SAML mapper.

### Destroy

`terragrunt destroy` removes the SAML IdP, all attribute importers, all realm roles, and all attribute-to-role mappers from Keycloak. Users already federated via the IdP will lose their external identity link but their Keycloak accounts are not deleted.
