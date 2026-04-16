# keycloak-sso Module

Configures Keycloak as the primary IDP for NX Cloud — internal users, groups, realm roles, and group-role assignments.

## What it does

One module invocation provisions the full identity hierarchy inside a Keycloak realm:

- **Groups** — one group per `(tenant × org × env × role)`, named `<prefix>-<tenant>-<org_code>-<env>-<role>`
- **Realm roles** — one realm role per group, keyed `<tenant>-<org_name>-<env>-<role>`
- **Group → role assignments** — each group carries its corresponding realm role via `keycloak_group_roles`
- **Users** — one internal user per `(tenant × org × role)`, env-agnostic; assigned to their role's group in every environment

### Authentication flow

```
User → NX Cloud (OIDC) → Keycloak realm
                          internal login (username + password)
                          group membership → realm roles assigned
                          → OIDC token issued to NX Cloud
```

### Identity hierarchy

```
tenant (sim2)
  └─ org (northwind / nw)
       └─ env (dev, tst, qa, qa2, prd)
            └─ role (admin, user, viewer)
                 ├─ Group:    sg-sim2-nw-dev-admin
                 ├─ Role:     sim2-northwind-dev-admin
                 └─ User:     sim2-nw-admin  (member of all env-groups for role=admin)
```

## Prerequisites

- Keycloak instance running and accessible at `keycloak_url`
- Target realm already created (this module configures an existing realm)
- Admin credentials available via environment variables:

  ```bash
  export KEYCLOAK_USER=admin
  export KEYCLOAK_PASSWORD=<password>
  ```

### Tools

| Tool       | Version  | Purpose                    |
|------------|----------|----------------------------|
| Terraform  | >= 1.0   | Infrastructure provisioning|
| Terragrunt | >= 0.45  | Configuration management   |

### Providers

| Provider             | Source               | Version  |
|----------------------|----------------------|----------|
| `mrparkers/keycloak` | `mrparkers/keycloak` | `~> 4.4` |
| `hashicorp/random`   | `hashicorp/random`   | `~> 3.0` |

## Variables

### Keycloak connection

| Variable | Type     | Default   | Description                          |
|----------|----------|-----------|--------------------------------------|
| `realm`  | `string` | `default` | Keycloak realm to configure.         |

### Identity hierarchy

| Variable              | Type                                       | Default                          | Description                                              |
|-----------------------|--------------------------------------------|----------------------------------|----------------------------------------------------------|
| `tenant_seeds`        | `map(object({ label = string }))`          | —                                | Active tenants. Key is tenant shortname.                 |
| `tenant_orgs`         | `map(object({ code = string }))`           | `{ northwind = { code = "nw" }}` | Organizations per tenant.                                |
| `environments`        | `list(string)`                             | `[dev,tst,qa,qa2,prd]`           | Environment names to provision groups for.               |
| `roles`               | `list(string)`                             | `[admin,user,viewer]`            | Role names to provision per environment.                 |

### Naming

| Variable       | Type     | Default | Description                                          |
|----------------|----------|---------|------------------------------------------------------|
| `group_prefix` | `string` | `sg`    | Prefix for group names (e.g. `sg-sim2-nw-dev-admin`) |

### Users

| Variable              | Type     | Default     | Description                                                 |
|-----------------------|----------|-------------|-------------------------------------------------------------|
| `users_enabled`       | `bool`   | `true`      | Create internal users and group memberships.                |
| `user_password_length`| `number` | `20`        | Length of generated initial passwords (min 16).             |
| `user_email_domain`   | `string` | `nxteam.dev`| Email domain for generated users.                           |

## Outputs

| Output                  | Description                                                   |
|-------------------------|---------------------------------------------------------------|
| `group_names`           | Map of group key → Keycloak group name.                       |
| `role_names`            | Map of group key → Keycloak realm role name.                  |
| `user_usernames`        | Map of user key → Keycloak username.                          |
| `user_initial_passwords`| Map of user key → initial password (sensitive).               |

## Deployment

```bash
cd live/keycloak-sso

export KEYCLOAK_USER=admin
export KEYCLOAK_PASSWORD=<password>

terragrunt init
terragrunt plan
terragrunt apply
```

Retrieve initial passwords after apply:

```bash
terragrunt output -json user_initial_passwords
```

## Operational notes

### Adding tenants or orgs

Extend `tenant_seeds` or `tenant_orgs` in the live config and re-apply. New groups, roles, users, and memberships are added; existing resources are unchanged.

### Adding environments or roles

Extend `environments` or `roles` in the live config and re-apply. New groups and roles are created; existing users are automatically enrolled in the new groups.

### Destroy

`terragrunt destroy` removes all groups, realm roles, group-role assignments, users, and memberships from Keycloak.
