#!/usr/bin/env python3
"""
create_delegated_users.py
─────────────────────────
Create Azure AD users and assign them to existing security groups
in a sim tenant via Microsoft Graph API.

Authentication uses the Azure CLI token (az login must be run first).

USAGE
─────
  python create_delegated_users.py --help

EXAMPLES
────────
  # Create a single delegated user and add to all matching groups
  python create_delegated_users.py \\
      --tenant-id  1ebd14fa-33f0-474d-b9b8-bc87d0a0effe \\
      --upn-domain sreazrwussim1.onmicrosoft.com \\
      --tenant-key sim1 \\
      --org-code   nw \\
      --role       admin \\
      --password   "MyP@ssw0rd123!" \\
      --dry-run

  # Create user and actually apply
  python create_delegated_users.py \\
      --tenant-id  1ebd14fa-33f0-474d-b9b8-bc87d0a0effe \\
      --upn-domain sreazrwussim1.onmicrosoft.com \\
      --tenant-key sim1 \\
      --org-code   nw \\
      --role       admin \\
      --password   "MyP@ssw0rd123!"

  # Override display name and usage location
  python create_delegated_users.py \\
      --tenant-id    1ebd14fa-33f0-474d-b9b8-bc87d0a0effe \\
      --upn-domain   sreazrwussim1.onmicrosoft.com \\
      --tenant-key   sim1 \\
      --org-code     nw \\
      --role         viewer \\
      --display-name "Jane Doe (NW Viewer)" \\
      --usage-location DE \\
      --password     "MyP@ssw0rd123!"

  # Delete a delegated user by UPN
  python create_delegated_users.py \\
      --tenant-id 1ebd14fa-33f0-474d-b9b8-bc87d0a0effe \\
      --upn       sim1-nw-admin-jdoe@sreazrwussim1.onmicrosoft.com \\
      --delete

NAMING CONVENTION
─────────────────
  UPN          : {tenant-key}-{org-code}-{role}-{suffix}@{upn-domain}
                 e.g. sim1-nw-admin-jdoe@sreazrwussim1.onmicrosoft.com
  Mail nickname: {tenant-key}-{org-code}-{role}-{suffix}
  Groups added : sg-{tenant-key}-{org-code}-*-{role}  (all environments)
                 e.g. sg-sim1-nw-dev-admin
                      sg-sim1-nw-tst-admin
                      sg-sim1-nw-qa-admin  ...
"""

import argparse
import json
import subprocess
import sys
from typing import Optional


GRAPH = "https://graph.microsoft.com/v1.0"


# ── Graph API helpers ──────────────────────────────────────────────────────────

def get_token(tenant_id: str) -> str:
    """Acquire a Graph API access token via Azure CLI."""
    result = subprocess.run(
        ["az", "account", "get-access-token",
         "--tenant", tenant_id,
         "--resource-type", "ms-graph",
         "--query", "accessToken",
         "--output", "tsv"],
        capture_output=True, text=True
    )
    if result.returncode != 0:
        print(f"ERROR: Failed to get token for tenant {tenant_id}")
        print(result.stderr.strip())
        sys.exit(1)
    return result.stdout.strip()


def graph_get(token: str, path: str, params: str = "") -> dict:
    url = f"{GRAPH}/{path.lstrip('/')}"
    if params:
        url += f"?{params}"
    result = subprocess.run(
        ["az", "rest", "--method", "GET", "--url", url,
         "--headers", f"Authorization=Bearer {token}",
         "--output", "json"],
        capture_output=True, text=True
    )
    if result.returncode != 0:
        print(f"ERROR: GET {url}\n{result.stderr.strip()}")
        sys.exit(1)
    return json.loads(result.stdout)


def graph_post(token: str, path: str, body: dict) -> dict:
    url = f"{GRAPH}/{path.lstrip('/')}"
    result = subprocess.run(
        ["az", "rest", "--method", "POST", "--url", url,
         "--headers", f"Authorization=Bearer {token}", "Content-Type=application/json",
         "--body", json.dumps(body),
         "--output", "json"],
        capture_output=True, text=True
    )
    if result.returncode != 0:
        print(f"ERROR: POST {url}\n{result.stderr.strip()}")
        sys.exit(1)
    return json.loads(result.stdout)


def graph_delete(token: str, path: str) -> None:
    url = f"{GRAPH}/{path.lstrip('/')}"
    result = subprocess.run(
        ["az", "rest", "--method", "DELETE", "--url", url,
         "--headers", f"Authorization=Bearer {token}"],
        capture_output=True, text=True
    )
    if result.returncode != 0:
        print(f"ERROR: DELETE {url}\n{result.stderr.strip()}")
        sys.exit(1)


# ── Core operations ───────────────────────────────────────────────────────────

def find_user(token: str, upn: str) -> Optional[dict]:
    """Return user object if UPN exists, else None."""
    resp = graph_get(token, "users", f"$filter=userPrincipalName eq '{upn}'&$select=id,displayName,userPrincipalName")
    users = resp.get("value", [])
    return users[0] if users else None


def create_user(token: str, upn: str, display_name: str, mail_nickname: str,
                password: str, usage_location: str, dry_run: bool) -> Optional[str]:
    """Create a user and return their object ID."""
    body = {
        "accountEnabled": True,
        "displayName": display_name,
        "mailNickname": mail_nickname,
        "userPrincipalName": upn,
        "mail": upn,
        "usageLocation": usage_location,
        "passwordProfile": {
            "forceChangePasswordNextSignIn": True,
            "password": password,
        }
    }
    print(f"  [CREATE USER] {upn}")
    if dry_run:
        print(f"    (dry-run) body: {json.dumps(body, indent=4)}")
        return None
    user = graph_post(token, "users", body)
    print(f"    object_id: {user['id']}")
    return user["id"]


def get_matching_groups(token: str, tenant_key: str, org_code: str, role: str,
                        group_prefix: str = "sg") -> list[dict]:
    """
    Return all security groups matching the pattern:
      {prefix}-{tenant_key}-{org_code}-*-{role}
    """
    prefix = f"{group_prefix}-{tenant_key}-{org_code}-"
    resp = graph_get(token, "groups",
                     f"$filter=startswith(displayName,'{prefix}')&$select=id,displayName")
    all_groups = resp.get("value", [])
    # Filter to groups that end with the role
    matched = [g for g in all_groups if g["displayName"].endswith(f"-{role}")]
    return matched


def add_user_to_group(token: str, group_id: str, group_name: str,
                      user_id: str, dry_run: bool) -> None:
    print(f"  [ADD TO GROUP] {group_name}")
    if dry_run:
        print(f"    (dry-run) group_id={group_id}, user_id={user_id}")
        return
    graph_post(token, f"groups/{group_id}/members/$ref",
               {"@odata.id": f"{GRAPH}/directoryObjects/{user_id}"})
    print(f"    OK")


def delete_user(token: str, upn: str, dry_run: bool) -> None:
    print(f"  [DELETE USER] {upn}")
    user = find_user(token, upn)
    if not user:
        print(f"    Not found — nothing to delete.")
        return
    if dry_run:
        print(f"    (dry-run) would delete object_id={user['id']}")
        return
    graph_delete(token, f"users/{user['id']}")
    print(f"    Deleted object_id={user['id']}")


# ── CLI ────────────────────────────────────────────────────────────────────────

def build_parser() -> argparse.ArgumentParser:
    p = argparse.ArgumentParser(
        prog="create_delegated_users.py",
        description="Create Azure AD delegated users and assign them to security groups via Graph API.",
        formatter_class=argparse.RawDescriptionHelpFormatter,
        epilog=__doc__,
    )

    # Target tenant
    p.add_argument("--tenant-id", required=True,
                   help="Azure AD tenant GUID to operate against.")

    # User identity
    p.add_argument("--upn-domain",
                   help="UPN domain suffix (e.g. sreazrwussim1.onmicrosoft.com). "
                        "Required unless --upn is given.")
    p.add_argument("--upn",
                   help="Full UPN of an existing user. Required for --delete.")
    p.add_argument("--tenant-key",
                   help="Tenant short key (e.g. sim1). Used for UPN and group name construction.")
    p.add_argument("--org-code",
                   help="Org short code (e.g. nw). Used for UPN and group name construction.")
    p.add_argument("--role",
                   help="Role name (admin | user | viewer). Used for UPN and group matching.")
    p.add_argument("--suffix", default="",
                   help="Optional suffix appended to UPN to make it unique "
                        "(e.g. 'jdoe' → sim1-nw-admin-jdoe@domain). "
                        "If omitted, the standard service account UPN is used.")
    p.add_argument("--display-name",
                   help="Override the auto-generated display name.")
    p.add_argument("--usage-location", default="US",
                   help="ISO 3166-1 alpha-2 country code (default: US).")
    p.add_argument("--group-prefix", default="sg",
                   help="Security group display name prefix (default: sg).")

    # Credentials
    p.add_argument("--password",
                   help="Initial password. Required when creating a user.")

    # Actions
    p.add_argument("--delete", action="store_true",
                   help="Delete the user specified by --upn instead of creating one.")
    p.add_argument("--dry-run", action="store_true",
                   help="Print what would be done without making any changes.")

    return p


def main():
    parser = build_parser()
    args = parser.parse_args()

    print(f"\nTenant : {args.tenant_id}")
    print(f"Dry run: {args.dry_run}\n")

    token = get_token(args.tenant_id)

    # ── DELETE mode ──────────────────────────────────────────────────────────
    if args.delete:
        if not args.upn:
            parser.error("--upn is required with --delete")
        delete_user(token, args.upn, args.dry_run)
        print("\nDone.")
        return

    # ── CREATE mode ──────────────────────────────────────────────────────────
    for req in ("tenant_key", "org_code", "role", "upn_domain"):
        if not getattr(args, req):
            parser.error(f"--{req.replace('_', '-')} is required when creating a user")
    if not args.password:
        parser.error("--password is required when creating a user")

    # Build UPN
    nick_parts = [args.tenant_key, args.org_code, args.role]
    if args.suffix:
        nick_parts.append(args.suffix)
    mail_nickname = "-".join(nick_parts)
    upn = f"{mail_nickname}@{args.upn_domain}"

    display_name = args.display_name or (
        f"{args.role.title()} – {args.org_code.upper()} ({args.tenant_key})"
        + (f" [{args.suffix}]" if args.suffix else "")
    )

    print(f"UPN          : {upn}")
    print(f"Display name : {display_name}")
    print(f"Mail nickname: {mail_nickname}")
    print(f"Usage loc    : {args.usage_location}\n")

    # Check for existing user
    existing = find_user(token, upn)
    if existing:
        print(f"  User already exists: {existing['id']} — skipping creation.")
        user_id = existing["id"]
    else:
        user_id = create_user(token, upn, display_name, mail_nickname,
                              args.password, args.usage_location, args.dry_run)

    # Find and assign security groups
    groups = get_matching_groups(token, args.tenant_key, args.org_code,
                                 args.role, args.group_prefix)
    if not groups:
        print(f"\nWARNING: No groups found matching "
              f"'{args.group_prefix}-{args.tenant_key}-{args.org_code}-*-{args.role}'")
    else:
        print(f"\nMatched {len(groups)} group(s):")
        for g in sorted(groups, key=lambda x: x["displayName"]):
            add_user_to_group(token, g["id"], g["displayName"],
                              user_id or "DRY_RUN_ID", args.dry_run)

    print("\nDone.")


if __name__ == "__main__":
    main()
