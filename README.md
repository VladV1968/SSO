# SSO — Keycloak IDP Infrastructure

Terraform/Terragrunt IaC for the NX Cloud SSO integration. Provisions the full identity stack inside Keycloak as the primary IDP: internal users, groups, realm roles, and group-role assignments.

## Architecture

### Identity flow

```
 ┌─────────────────────────────────────────────────────────────────┐
 │  User                                                           │
 │    │  1. Access NX Cloud                                        │
 │    ▼                                                            │
 │  NX Cloud  ──OIDC──►  Keycloak (realm: default)                 │
 │                           │  2. Internal login (user + password) │
 │                           │  3. Group membership evaluated      │
 │                           │     sg-sim2-nw-dev-admin → role     │
 │                           │  4. OIDC token issued to NX Cloud   │
 │                           ▼                                     │
 │                        NX Cloud (authenticated)                 │
 └─────────────────────────────────────────────────────────────────┘
```

### Identity hierarchy (per tenant)

```
Keycloak (realm: default)
└── Tenant: sim2
    └── Org: northwind (nw)
        ├── Groups  [sg-sim2-nw-{env}-{role}]
        │   ├── sg-sim2-nw-dev-admin  ──► role: sim2-northwind-dev-admin
        │   ├── sg-sim2-nw-dev-user   ──► role: sim2-northwind-dev-user
        │   ├── sg-sim2-nw-dev-viewer ──► role: sim2-northwind-dev-viewer
        │   ├── sg-sim2-nw-tst-*  (×3)
        │   ├── sg-sim2-nw-qa-*   (×3)
        │   ├── sg-sim2-nw-qa2-*  (×3)
        │   └── sg-sim2-nw-prd-*  (×3)
        │
        ├── Realm Roles  [sim2-northwind-{env}-{role}]  (15 total)
        │
        └── Users  [sim2-nw-{role}]  (3 total, env-agnostic)
            ├── sim2-nw-admin   → member of all sg-sim2-nw-*-admin groups
            ├── sim2-nw-user    → member of all sg-sim2-nw-*-user groups
            └── sim2-nw-viewer  → member of all sg-sim2-nw-*-viewer groups
```

## Repository structure

```
SSO/
├── root.hcl                     # Terragrunt root: local state, provider generation
├── variables.hcl                # Global vars: Keycloak URL, realm, naming
│
├── modules/
│   └── keycloak-sso/            # Keycloak realm module (users, groups, roles)
│       ├── main.tf
│       ├── variables.tf
│       ├── outputs.tf
│       └── README.md
│
└── live/
    └── keycloak-sso/            # Live configuration
        └── terragrunt.hcl
```

## Keycloak instance

- **URL**: `https://idp-keycloak.cloud.nxteam.dev/auth`
- **Realm**: `default`
- **Admin console**: `https://idp-keycloak.cloud.nxteam.dev/auth/admin/master/console/`

## Deployment

### Prerequisites

| Tool       | Version  |
|------------|----------|
| Terraform  | >= 1.0   |
| Terragrunt | >= 0.45  |

### Apply

```bash
cd live/keycloak-sso

export KEYCLOAK_USER=admin
export KEYCLOAK_PASSWORD=<password>

terragrunt init
terragrunt plan
terragrunt apply
```

### Retrieve initial passwords

```bash
terragrunt output -json user_initial_passwords
```

Users are created with `temporary = true` — they must change their password on first login.

## Naming conventions

| Resource    | Pattern                                    | Example                        |
|-------------|--------------------------------------------|--------------------------------|
| Group       | `sg-{tenant}-{org_code}-{env}-{role}`      | `sg-sim2-nw-dev-admin`         |
| Realm role  | `{tenant}-{org_name}-{env}-{role}`         | `sim2-northwind-dev-admin`     |
| Username    | `{tenant}-{org_code}-{role}`               | `sim2-nw-admin`                |
| Email       | `{username}@{user_email_domain}`           | `sim2-nw-admin@nxteam.dev`     |

## State

State is stored locally (`terraform.tfstate` in each live directory). To migrate to a remote backend, update `root.hcl` with the desired backend configuration.

## Extending

### Add a tenant

```hcl
# live/keycloak-sso/terragrunt.hcl
tenant_seeds = {
  sim2 = { label = "sim2" }
  sim3 = { label = "sim3" }   # new
}
```

### Add an org

```hcl
tenant_orgs = {
  northwind = { code = "nw" }
  contoso   = { code = "cs" }  # new
}
```

### Add environments or roles

```hcl
environments = ["dev", "tst", "qa", "qa2", "prd", "stg"]
roles        = ["admin", "user", "viewer", "readonly"]
```

Re-apply after any change — Terraform only adds new resources without touching existing ones.
