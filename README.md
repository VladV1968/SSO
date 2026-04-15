# SSO — Azure AD + Keycloak Infrastructure

Terraform/Terragrunt IaC for the NX Cloud SSO integration. Provisions the full identity stack: Azure AD simulated tenants (Entra ID), a Keycloak SAML broker, and all supporting resources that wire them together.

## Architecture

### Identity flow

```
 ┌─────────────────────────────────────────────────────────────────┐
 │  User                                                           │
 │    │  1. Access NX Cloud                                        │
 │    ▼                                                            │
 │  NX Cloud  ──OIDC──►  Keycloak (realm: default)                 │
 │                           │  2. Redirect to Azure AD (SAML)     │
 │                           ▼                                     │
 │                        Azure AD (Enterprise App)                │
 │                           │  3. User authenticates              │
 │                           │  4. SAML assertion → Keycloak       │
 │                           ▼                                     │
 │                        Keycloak                                 │
 │                           │  5. Attribute importers fire        │
 │                           │     email, firstName, lastName      │
 │                           │  6. Group-to-role mappers fire      │
 │                           │     Azure AD group → Keycloak role  │
 │                           │  7. OIDC token issued to NX Cloud   │
 │                           ▼                                     │
 │                        NX Cloud (authenticated)                 │
 └─────────────────────────────────────────────────────────────────┘
```

### SAML binding detail

- **SP entity ID**: `{keycloak_url}/realms/{realm}` — identifies Keycloak to Azure AD
- **ACS URL**:      `{keycloak_url}/realms/{realm}/broker/{idp_alias}/endpoint` — where Azure AD POSTs the SAML assertion
- **SSO endpoint**: `https://login.microsoftonline.com/{sim_tenant_id}/saml2`
- **Binding**:       HTTP-POST for both AuthnRequest and Response
- **Signature**:     Azure AD signs the response; Keycloak validates against the app's SAML signing certificate
- **NameID**: UPN    (`user@domain.onmicrosoft.com`) via claims mapping policy
- **Sync mode**:     `FORCE` — Keycloak re-imports user attributes on every login

### Identity hierarchy (per SIM tenant)

```
Azure AD Tenant (sim2 — sreazrwussim2.onmicrosoft.com)
└── NX Cloud Enterprise App (SAML SSO)
    ├── Service Principal
    │   ├── SAML claims mapping policy  (email, firstName, lastName, NameID)
    │   ├── SAML token signing certificate
    │   └── App role assignments (security groups)
    └── Security Groups  [sg-{tenant}-{org}-{env}-{role}]
        ├── sg-sim2-nw-dev-admin
        ├── sg-sim2-nw-dev-user
        ├── sg-sim2-nw-dev-viewer
        ├── sg-sim2-nw-tst-*  (×3)
        ├── sg-sim2-nw-qa-*   (×3)
        ├── sg-sim2-nw-qa2-*  (×3)
        └── sg-sim2-nw-prd-*  (×3)

Keycloak (realm: default)
└── Azure AD SAML IdP  [alias: {idp_alias}]
    ├── Attribute importers  (email → email, firstName, lastName)
    ├── Realm roles          [sim2-northwind-{env}-{role}]  ×15
    └── SAML attribute-to-role mappers  ×15
        └── groups claim display name → realm role
```

## Repository structure

```
SSO/
├── variables.hcl                     # Global: subscription, tenants, Keycloak URL
├── root.hcl                          # Remote state (Azure Blob), provider generation
├── modules/
│   ├── ad-tenant/                    # Azure AD provisioning module
│   │   ├── main.tf                   # Groups, users, enterprise app, SP, cert, claims policy
│   │   ├── variables.tf
│   │   ├── outputs.tf
│   │   └── locals.tf
│   └── keycloak-sso/                 # Keycloak SAML broker module
│       ├── main.tf                   # SAML IdP, attribute importers, roles, mappers
│       ├── variables.tf
│       └── outputs.tf
└── live/
    └── region-a/
        ├── ad-tenant/
        │   └── terragrunt.hcl        # Org/tenant config, SAML URLs, tags
        └── keycloak-sso/
            └── terragrunt.hcl        # IdP alias, dependency on ad-tenant outputs
```

## Deployed resources

### Module: `ad-tenant`

Manages the Azure AD (Entra ID) side. One invocation targets one simulated tenant.

| Resource                       | Type                                                        | Count (default config)                             |
|--------------------------------|-------------------------------------------------------------|----------------------------------------------------|
| Security groups                | `azuread_group`                                             | `tenants × orgs × envs × roles` = 1×1×5×3 = **15** |
| Users                          | `azuread_user`                                              | `tenants × orgs × roles` = 1×1×3 = **3**           |
| Group memberships              | `azuread_group_member`                                      | `tenants × orgs × envs × roles` = **15**           |
| Enterprise application         | `azuread_application`                                       | **1 per tenant**                                   |
| Service principal              | `azuread_service_principal`                                 | **1 per tenant**                                   |
| SAML claims mapping policy     | `azuread_claims_mapping_policy`                             | **1 per tenant**                                   |
| Claims policy assignment       | `azuread_service_principal_claims_mapping_policy_assignment`| **1 per tenant**                                   |
| App role assignments (groups)  | `azuread_app_role_assignment`                               | **15 per tenant** (all org groups)                 |
| SAML entity ID                 | `terraform_data` + Graph API `PATCH`                        | **1 per tenant** (local-exec)                      |
| SAML token signing certificate | `terraform_data` + Graph API `POST`                         | **1 per tenant** (local-exec)                      |
| Random passwords               | `random_password`                                           | **3**                                              |

> Claims include: `email` (mail), `firstName` (givenname), `lastName` (surname), `NameID` (userprincipalname). Groups are emitted as display names via `optional_claims` (not through the claims mapping policy).

### Module: `keycloak-sso`

Manages the Keycloak side. One invocation configures one SIM tenant's IdP in the realm.

| Resource                        | Type                                                   | Count (default config)             |
|---------------------------------|--------------------------------------------------------|------------------------------------|
| Azure AD SAML Identity Provider | `keycloak_saml_identity_provider`                      | **1**                              |
| Attribute importers             | `keycloak_attribute_importer_identity_provider_mapper` | **3** (email, firstName, lastName) |
| Realm roles                     | `keycloak_role`                                        | **15** (one per security group)    |
| SAML attribute-to-role mappers  | `keycloak_attribute_to_role_identity_provider_mapper`  | **15**                             |
 
## Prerequisites

### 1. Azure AD tenants

Each SIM tenant must be manually created in the Azure Portal before first apply. Add the tenant ID and UPN domain to `variables.hcl`:

```hcl
sim_tenant_ids = {
  sim2 = "027de348-f78d-44e5-93a7-f0472d5cb35a"
}
```

And in `live/region-a/ad-tenant/terragrunt.hcl`:

```hcl
sim_tenant_upn_domains = {
  sim2 = "sreazrwussim2.onmicrosoft.com"
}
```

### 2. Azure CLI authentication

Two tenants require authentication: the management tenant (for state backend) and each SIM tenant (for `azuread` provider and Graph API calls):

```bash
# Management tenant (state backend + azurerm provider)
az login

# SIM tenant (azuread provider + local-exec provisioners)
az login --tenant 027de348-f78d-44e5-93a7-f0472d5cb35a
```

### 3. Keycloak

- Keycloak instance accessible at `keycloak_url` (see `variables.hcl`)
- Realm already created (the module configures an existing realm, it does not create one)

### 4. Tools

| Tool       | Version         | Notes                                        |
|------------|-----------------|----------------------------------------------|
| Terraform  | >= 1.0          |                                              |
| Terragrunt | >= 0.99         | Uses new CLI: `terragrunt run --all apply`   |
| Azure CLI  | Latest          | Token acquisition for Graph API provisioners |
| PowerShell | >= 7.0 (`pwsh`) | Local-exec provisioner interpreter           |
| `jq`       | Latest          | Certificate extraction from Graph API        |

## Deployment

### Environment variables

```bash
# Keycloak admin credentials
export KEYCLOAK_USER=admin
export KEYCLOAK_PASSWORD=<password>

# Azure AD SAML signing certificate (retrieve after ad-tenant apply — see below)
export TF_VAR_azure_ad_signing_certificate=<base64-cert>
```

### Step 1 — Apply `ad-tenant`

Provisions security groups, users, enterprise app, and SAML configuration in Azure AD:

```bash
cd live/region-a/ad-tenant

terragrunt init
terragrunt plan
terragrunt apply
```

> Azure AD has eventual consistency. `group replication not yet complete` errors on first apply are transient — re-run `terragrunt apply` to self-resolve.

### Step 2 — Retrieve the SAML signing certificate

The NX Cloud enterprise app's SAML signing certificate is created by the `ad-tenant` provisioner. Retrieve it using the federation metadata XML for the app:

```bash
TENANT_ID=027de348-f78d-44e5-93a7-f0472d5cb35a
CLIENT_ID=$(cd live/region-a/ad-tenant && terragrunt output -json nxcloud_app_client_ids | jq -r '.sim2')

# Fetch the app-specific federation metadata and extract the signing cert
curl -s "https://login.microsoftonline.com/${TENANT_ID}/federationmetadata/2007-06/federationmetadata.xml?appid=${CLIENT_ID}" \
  | grep -oP '(?<=<X509Certificate>)[^<]+' \
  | head -1
```

Or using PowerShell:

```powershell
$tenantId = "027de348-f78d-44e5-93a7-f0472d5cb35a"
$clientId = "<client-id-from-ad-tenant-output>"
$url = "https://login.microsoftonline.com/$tenantId/federationmetadata/2007-06/federationmetadata.xml?appid=$clientId"
$raw = (Invoke-WebRequest -Uri $url -UseBasicParsing).Content
[regex]::Match($raw, '(?<=<X509Certificate>)[^<]+').Value
```

Export the result:

```bash
export TF_VAR_azure_ad_signing_certificate=<base64-value>
```

> The value is a base64 DER certificate without PEM headers. Do not commit it to source control.

### Step 3 — Apply `keycloak-sso`

Configures the SAML IdP, attribute mappers, realm roles, and group-to-role mappers in Keycloak:

```bash
cd live/region-a/keycloak-sso

terragrunt init
terragrunt plan
terragrunt apply
```

The `dependency "ad_tenant"` block reads `group_display_names` and `nxcloud_app_client_ids` directly from the ad-tenant state — no manual output copying required.

### Deploy all at once

Terragrunt respects dependency ordering automatically:

```bash
cd live/region-a

export KEYCLOAK_USER=admin
export KEYCLOAK_PASSWORD=<password>
export TF_VAR_azure_ad_signing_certificate=<base64-cert>

terragrunt run --all apply --non-interactive
```

## Key operational notes

### IdP alias and ACS URL coupling

The `idp_alias` in `keycloak-sso/terragrunt.hcl` is the path segment in Keycloak's ACS URL:

```
{keycloak_url}/realms/{realm}/broker/{idp_alias}/endpoint
```

This URL is registered in Azure AD (`nxcloud_saml_acs_urls`). Both must match. Changing `idp_alias` after initial deploy requires re-applying both modules.

### SAML entity ID

The SP entity ID (`{keycloak_url}/realms/{realm}`) is registered in Azure AD as `identifier_uris` via a `local-exec` Graph API PATCH (the `azuread` provider rejects unverified domains). If the provisioner fails, re-running `terragrunt apply` is safe — the script is idempotent.

### First broker login

On first SSO login for a user, Keycloak runs the `first broker login` flow. If a Keycloak user with the same email already exists (e.g. from a stale state after entity ID changes), the flow asks for local Keycloak credentials. Fix by deleting the stale Keycloak user via the admin API or console and re-authenticating:

```bash
KEYCLOAK_URL=https://auth.alicloud-stage-sre.nx-demo.com/auth

TOKEN=$(curl -s -X POST "$KEYCLOAK_URL/realms/master/protocol/openid-connect/token" \
  -d "grant_type=password&client_id=admin-cli&username=$KEYCLOAK_USER&password=$KEYCLOAK_PASSWORD" \
  | jq -r '.access_token')

# Find stale user
curl -s "$KEYCLOAK_URL/admin/realms/default/users?search=<email>" \
  -H "Authorization: Bearer $TOKEN" | jq '.[].id'

# Delete stale user
curl -s -X DELETE "$KEYCLOAK_URL/admin/realms/default/users/<user-id>" \
  -H "Authorization: Bearer $TOKEN"
```

### Signing certificate rotation

1. Retrieve the new certificate (see Step 2 above).
2. Update `TF_VAR_azure_ad_signing_certificate`.
3. Run `terragrunt apply` from `live/region-a/keycloak-sso`.

No downtime if both old and new certificates are briefly active in Azure AD during rotation.

### Syncing groups after ad-tenant changes

After adding or removing security groups in `ad-tenant`, re-apply `keycloak-sso` to sync realm roles and SAML mappers. The dependency block picks up updated outputs automatically:

```bash
cd live/region-a/keycloak-sso && terragrunt apply
```

### Adding a new SIM tenant

1. Create the tenant manually in Azure Portal.
2. Add the tenant ID to `variables.hcl` (`sim_tenant_ids`) and set it as `active_sim_tenant_key`.
3. Add the UPN domain to `ad-tenant/terragrunt.hcl` (`sim_tenant_upn_domains`, `tenant_seeds`, `nxcloud_saml_*_urls`).
4. Run `terragrunt run --all apply` from `live/region-a`.

## Remote state

State is stored in Azure Blob Storage (`root.hcl`):

| Setting           | Value                                      |
|-------------------|--------------------------------------------|
| Resource group    | `rg-sre-azr-eus-dev-str-tf`                |
| Storage account   | `sreazreusdevtfstr`                        |
| Container         | `sreazreusdevstrtfcontainer`               |
| State key pattern | `live/region-a/{module}/terraform.tfstate` |
