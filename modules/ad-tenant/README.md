# ad-tenant Module

Provisions the Azure AD (Entra ID) side of the NX Cloud SSO integration for one or more simulated tenants.

## What it does

Creates a complete identity hierarchy in a target Azure AD tenant:

- **Security groups** — one per `(tenant × org × environment × role)`, e.g. `sg-sim1-nw-dev-admin`
- **Users** — one per `(tenant × org × role)`, e.g. `sim1-nw-admin@sreazrwussim1.onmicrosoft.com`
- **Group memberships** — each user is added to their role's group in every environment
- **NX Cloud enterprise application** — one per tenant with SAML SSO configured
- **Service principal** — linked to the enterprise app with `preferred_single_sign_on_mode = saml`
- **Claims mapping policy** — maps `email`, `firstName`, `lastName`, and `NameID` (UPN) to SAML claims; group display names are emitted via `optional_claims`
- **SAML entity ID** — set via Graph API after app creation (azuread provider rejects unverified domains; this is done by a `local-exec` provisioner using PowerShell)
- **SAML token signing certificate** — created via Graph API; active signing key is set so the Azure portal SAML configuration page renders correctly
- **External group assignments** — assigns pre-existing Azure AD groups to the enterprise app; output consumed by keycloak-sso to create matching realm roles and SAML mappers
- **External user assignments** — assigns pre-existing Azure AD users directly to the enterprise app
- **Role-user memberships** — adds pre-existing Azure AD users to managed role security groups

## Naming conventions

| Resource | Pattern | Example |
|---|---|---|
| Security group | `{prefix}-{tenant}-{code}-{env}-{role}` | `sg-sim1-nw-dev-admin` |
| User UPN | `{tenant}-{code}-{role}@{upn_domain}` | `sim1-nw-admin@sreazrwussim1.onmicrosoft.com` |
| User display name | `{Role} – {Org} ({tenant})` | `Admin – Northwind (sim1)` |
| Group description | `Tenant: {t} \| Org: {o} \| Env: {e} \| Role: {r} \| Managed by Terraform` | — |
| Group membership key | `{tenant}-{company}-{env}-{role}` | `sim1-northwind-dev-admin` |

All prefixes and the base domain are configurable via variables.

## Prerequisites

### Azure AD tenants

Each simulated tenant must be created manually in the Azure portal before running this module. Only tenants listed in `sim_tenant_upn_domains` are active — this controls which tenants receive resources.

### Permissions

The identity running `terragrunt apply` must have one of the following roles in each target tenant:

- **Global Administrator**, or
- **Application Administrator** + **User Administrator** + **Group Administrator** (least-privilege option)

The `az account get-access-token` calls in `local-exec` provisioners require that the CLI is authenticated to each sim tenant (`az login --tenant <tenant-id>`).

### Tools

| Tool | Version | Purpose |
|---|---|---|
| Terraform | >= 1.0 | Infrastructure provisioning |
| Terragrunt | >= 0.45 | Configuration management |
| Azure CLI (`az`) | Latest | Token acquisition for Graph API calls in provisioners |
| PowerShell (`pwsh`) | >= 7.0 | Local-exec provisioner interpreter |

### Providers

| Provider | Source | Version |
|---|---|---|
| `azuread` | `hashicorp/azuread` | `~> 2.50` |
| `random` | `hashicorp/random` | `~> 3.0` |

> **Important:** The `azuread` provider must be configured with the sim tenant's `tenant_id`. In Terragrunt, this is done via a separate `generate "ad_provider"` block that writes to `ad_provider.tf` (distinct from `provider.tf` written by root.hcl). If both use the same output file, the included config's generate block wins and the sim tenant targeting is lost.

## Variables

### Identity hierarchy

| Variable | Type | Default | Description |
|---|---|---|---|
| `tenant_seeds` | `map(object({label=string}))` | `{sim1={label="sim1"}}` | Tenants to provision. Each tenant gets all orgs from `tenant_orgs`. |
| `tenant_orgs` | `map(object({code=string}))` | `{northwind={code="nw"}}` | Organizations per tenant. |
| `environments` | `list(string)` | `["dev","tst","qa","qa2","prd"]` | Environments to provision per org. |
| `roles` | `list(string)` | `["admin","user","viewer"]` | Roles per environment. |

### Naming and domain

| Variable | Type | Default | Description |
|---|---|---|---|
| `base_domain` | `string` | `cloud.hwd.mx` | Base domain for org tenant domains. |
| `group_prefix` | `string` | `sg` | Prefix for security group display names. |
| `sim_tenant_upn_domains` | `map(string)` | `{}` | Map of tenant key → verified UPN domain. Only tenants with an entry here are provisioned. |

### Users

| Variable | Type | Default | Description |
|---|---|---|---|
| `users_enabled` | `bool` | `true` | Whether to create `azuread_user` resources. |
| `user_password_length` | `number` | `20` | Length of generated passwords (min 16). |
| `usage_location` | `string` | `US` | ISO 3166-1 alpha-2 country code required for license assignment. |

### NX Cloud SAML SSO

| Variable | Type | Default | Description |
|---|---|---|---|
| `sim_tenant_ids` | `map(string)` | `{}` | Tenant GUID per tenant key. Used by local-exec provisioners. |
| `nxcloud_app_display_name` | `string` | `nx cloud` | Enterprise app display name in Entra ID. |
| `nxcloud_saml_login_urls` | `map(string)` | `{}` | Keycloak realm root URL per tenant key. |
| `nxcloud_saml_acs_urls` | `map(string)` | `{}` | Keycloak SAML ACS (broker endpoint) URL per tenant key. |
| `nxcloud_saml_entity_ids` | `map(string)` | `{}` | SAML Entity ID URI per tenant key. |
| `nxcloud_assigned_orgs` | `list(string)` | `[]` | Orgs whose security groups get assigned to the enterprise app. |

### External SSO assignments

| Variable | Type | Default | Description |
|---|---|---|---|
| `sso_external_groups` | `map(object({object_id, display_name, tenant_key}))` | `{}` | Pre-existing groups to assign to the enterprise app. Output as `external_group_display_names` for keycloak-sso. |
| `sso_external_users` | `map(object({object_id, tenant_key}))` | `{}` | Pre-existing users to assign directly to the enterprise app. |
| `sso_role_user_memberships` | `map(object({user_object_id, group_key}))` | `{}` | Add pre-existing users to managed role security groups. `group_key` must match a key in `local.flat_groups`. |

### Metadata

| Variable | Type | Default | Description |
|---|---|---|---|
| `tags` | `map(string)` | `{}` | Tags applied to all taggable Azure resources. |

## Outputs

| Output | Description |
|---|---|
| `simulated_tenants` | Full identity hierarchy (tenants → orgs → envs → groups/users). |
| `group_object_ids` | Map of `{tenant}-{org}-{env}-{role}` → group object ID. |
| `group_display_names` | Map of `{tenant}-{org}-{env}-{role}` → group display name. Consumed by keycloak-sso. |
| `user_object_ids` | Map of `{tenant}-{org}-{role}` → user object ID. |
| `user_upns` | Map of `{tenant}-{org}-{role}` → user principal name. |
| `user_initial_passwords` | Map of `{tenant}-{org}-{role}` → initial password. Sensitive — retrieve with `terraform output -json user_initial_passwords`. |
| `flat_groups` | Flattened group map used internally for `for_each`. |
| `flat_users` | Flattened user map used internally for `for_each`. |
| `nxcloud_app_client_ids` | Map of tenant key → enterprise app client ID. Consumed by keycloak-sso to build federation metadata URLs. |
| `external_group_display_names` | Map of external group key → display name. Consumed by keycloak-sso for realm role and SAML mapper creation. |

## Deployment

### First apply

```bash
cd live/region-a/ad-tenant

# Authenticate to the management tenant (for azurerm state backend).
az login

# Authenticate to the sim tenant (for azuread provider and provisioner token calls).
az login --tenant 1ebd14fa-33f0-474d-b9b8-bc87d0a0effe

terragrunt init
terragrunt plan
terragrunt apply
```

Azure AD has eventual consistency. Expect occasional `group replication not yet complete` errors on the first apply. Re-run `terragrunt apply` — these are transient and self-resolve.

### Retrieving credentials

```bash
# Initial passwords (sensitive output).
terragrunt output -json user_initial_passwords

# Service principal object ID (needed for keycloak-sso prereq: signing cert retrieval).
terragrunt output -json nxcloud_app_client_ids
```

### Retrieving the SAML signing certificate

After apply, retrieve the active signing certificate for use in keycloak-sso:

```bash
SP_ID=<service-principal-object-id>
TENANT_ID=1ebd14fa-33f0-474d-b9b8-bc87d0a0effe

az rest --method GET \
  --url "https://graph.microsoft.com/v1.0/servicePrincipals/$SP_ID/tokenSigningCertificates" \
  --headers "Authorization=Bearer $(az account get-access-token --tenant $TENANT_ID --resource-type ms-graph --query accessToken -o tsv)" \
  | jq -r '.value[] | select(.isActive == true) | .rawValue'
```

Store the result and pass it to keycloak-sso as `TF_VAR_azure_ad_signing_certificate`.

### Importing existing resources

If users or groups already exist in Azure AD (e.g. from a failed apply), import them before re-applying:

```bash
terragrunt import 'azuread_user.org_role["sim1-northwind-admin"]' <object-id>
terragrunt import 'azuread_group.org_env_role["sim1-northwind-dev-admin"]' <object-id>
```

Ensure the `azuread` provider is targeting the correct tenant (`ad_provider.tf`, not overwritten by root.hcl) before importing.

## Adding a new org

1. Add the org to `tenant_orgs` in `live/region-a/ad-tenant/terragrunt.hcl`:
   ```hcl
   tenant_orgs = {
     northwind = { code = "nw" }
     contoso   = { code = "cs" }
   }
   ```
2. Add the org to `nxcloud_assigned_orgs` if its groups should have enterprise app access.
3. Run `terragrunt plan` to review: `5 × 3 = 15` new groups, `3` users, `15` memberships, `15` app role assignments.

## Adding external groups to SSO

Add entries to `sso_external_groups`. The `object_id` must be the group's Azure AD object ID:

```hcl
sso_external_groups = {
  my-ops-team = {
    object_id    = "xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx"
    display_name = "my-ops-team"
    tenant_key   = "sim1"
  }
}
```

The `display_name` value must match the group name that Azure AD will emit in the SAML groups claim. After apply, the `external_group_display_names` output is automatically consumed by keycloak-sso to create a matching realm role and SAML mapper.

## Adding external users to SSO

Add entries to `sso_external_users` for direct app access (without group membership):

```hcl
sso_external_users = {
  jsmith = {
    object_id  = "xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx"
    tenant_key = "sim1"
  }
}
```

To also grant a Keycloak role, add the user to a managed group via `sso_role_user_memberships`:

```hcl
sso_role_user_memberships = {
  jsmith-dev-admin = {
    user_object_id = "xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx"
    group_key      = "sim1-northwind-dev-admin"
  }
}
```

## Operational notes

- **Password rotation**: Initial passwords are stored in Terraform state. After first login, users are required to change their password (`force_password_change = true`). The password attribute is ignored after first apply (`lifecycle.ignore_changes`).
- **users_enabled = false**: Skips all `azuread_user`, `random_password`, and `azuread_group_member` (managed users) resources. Useful for customer deployments where users are managed by the customer's IT.
- **State drift**: The SAML entity ID and signing certificate provisioners are `terraform_data` resources with `local-exec`. They do not track remote state. If a provisioner fails, re-running apply will re-execute it — the scripts are idempotent.
- **Destroy**: `terragrunt destroy` removes all managed resources. App role assignments, group memberships, users, groups, and the enterprise app are deleted. The SAML entity ID and cert provisioners have no destroy-time logic.
