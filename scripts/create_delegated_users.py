#!/usr/bin/env python3
"""
create_delegated_users.py
-------------------------
Create Azure AD users and assign them to explicitly specified security groups
in a sim tenant via Microsoft Graph API.

Authentication uses the Azure CLI token (az login must be run first).

PREREQUISITES
-------------
  1. Python 3.10+
  2. Azure CLI installed and on PATH (az / az.cmd)
       https://learn.microsoft.com/en-us/cli/azure/install-azure-cli
  3. Logged in to Azure CLI with access to the target tenant:
       az login
       az account get-access-token --tenant <your-tenant-id> --resource-type ms-graph
  4. The target tenant must already have the security groups created
       (groups are provisioned by Terraform/Terragrunt — run terragrunt apply first)
  5. Your account must have at least these Azure AD roles in the target tenant:
       - User Administrator  (to create users)
       - Groups Administrator or Directory Writer  (to assign group members)
  6. No additional Python packages required — uses stdlib only (csv, json, urllib)

USAGE
-----
  python create_delegated_users.py --help

EXAMPLES
--------
  # Single user assigned to one specific group (dry-run)
  python create_delegated_users.py \
      --tenant-id  <your-tenant-id> \
      --upn-domain sreazrwussim1.onmicrosoft.com \
      --tenant-key sim1 --org-code nw --org-name northwind \
      --role admin --suffix jdoe \
      --first-name Jane --last-name Doe \
      --group sg-sim1-nw-dev-admin \
      --password "MyP@ssw0rd123!" --dry-run

  # Single user assigned to multiple groups
  python create_delegated_users.py \
      --tenant-id  <your-tenant-id> \
      --upn-domain sreazrwussim1.onmicrosoft.com \
      --tenant-key sim1 --org-code nw --org-name northwind \
      --role admin --suffix jdoe \
      --first-name Jane --last-name Doe \
      --group sg-sim1-nw-dev-admin \
      --group sg-sim1-nw-tst-admin \
      --password "MyP@ssw0rd123!"

  # Bulk import from CSV (tenant_id per row, groups pipe-separated)
  python create_delegated_users.py \
      --tenant-id  <your-tenant-id> \
      --input-file users.csv \
      --output-file results.csv \
      --dry-run

  # Delete a user
  python create_delegated_users.py \
      --tenant-id <your-tenant-id> \
      --upn sim1-nw-admin-jdoe@sreazrwussim1.onmicrosoft.com \
      --delete

CSV FORMAT
----------
  Required columns : tenant_id, upn_domain, tenant_key, org_code, role, security_groups
  Optional columns : org_name, suffix, first_name, last_name,
                     display_name, usage_location, password, group_prefix

  - tenant_id      : Azure AD tenant GUID for this row (overrides --tenant-id default)
  - security_groups: pipe-separated exact group display names to assign
                     e.g. sg-sim1-nw-dev-admin|sg-sim1-nw-tst-admin
  - password       : leave empty to auto-generate a secure random password
  - usage_location : ISO 3166-1 alpha-2 country code, defaults to US

  Example users.csv:
    tenant_id,upn_domain,tenant_key,org_code,org_name,role,suffix,first_name,last_name,security_groups,password
    <your-tenant-id>,sreazrwussim1.onmicrosoft.com,sim1,nw,northwind,admin,jdoe,Jane,Doe,sg-sim1-nw-dev-admin,MyP@ss123!
    <your-tenant-id>,sreazrwussim1.onmicrosoft.com,sim1,nw,northwind,user,asmith,Alice,Smith,sg-sim1-nw-dev-user|sg-sim1-nw-tst-user,
    <your-tenant-id>,sreazrwussim1.onmicrosoft.com,sim1,nw,northwind,viewer,bjones,Bob,Jones,sg-sim1-nw-dev-viewer,

NAMING CONVENTION
-----------------
  UPN          : {tenant-key}-{org-code}-{role}-{suffix}@{upn-domain}
                 e.g. sim1-nw-admin-jdoe@sreazrwussim1.onmicrosoft.com
  Mail nickname: {tenant-key}-{org-code}-{role}-{suffix}
  Display name : {Role} - {Org Name} ({tenant-key}) [{suffix}]
                 e.g. Admin - Northwind (sim1) [jdoe]
"""

import argparse
import csv
import json
import secrets
import shutil
import string
import subprocess
import sys
import urllib.error
import urllib.parse
import urllib.request
from dataclasses import dataclass, field
from typing import Optional

# Resolve az executable -- on Windows it is az.cmd, not az
AZ = shutil.which("az") or shutil.which("az.cmd") or "az"

GRAPH = "https://graph.microsoft.com/v1.0"

CSV_REQUIRED = {"tenant_id", "upn_domain", "tenant_key", "org_code", "role", "security_groups"}


# -- Data model ----------------------------------------------------------------

@dataclass
class UserSpec:
    tenant_id:      str
    upn_domain:     str
    tenant_key:     str
    org_code:       str
    role:           str
    security_groups: list        # explicit list of group display names to assign
    org_name:       str  = ""
    suffix:         str  = ""
    first_name:     str  = ""
    last_name:      str  = ""
    display_name:   str  = ""
    usage_location: str  = "US"
    password:       str  = ""
    group_prefix:   str  = "sg"

    # Derived -- populated during __post_init__
    upn:           str  = field(default="", init=False)
    mail_nickname: str  = field(default="", init=False)

    def __post_init__(self):
        self.org_name       = self.org_name or self.org_code
        self.usage_location = self.usage_location or "US"
        self.group_prefix   = self.group_prefix or "sg"
        if not self.password:
            self.password   = _generate_password()

        nick_parts = [self.tenant_key, self.org_code, self.role]
        if self.suffix:
            nick_parts.append(self.suffix)
        self.mail_nickname = "-".join(nick_parts)
        self.upn = f"{self.mail_nickname}@{self.upn_domain}"

        if not self.display_name:
            org_label = self.org_name.title()
            self.display_name = (
                f"{self.role.title()} - {org_label} ({self.tenant_key})"
                + (f" [{self.suffix}]" if self.suffix else "")
            )


@dataclass
class UserResult:
    upn:       str
    status:    str   # created | skipped | failed | dry-run
    object_id: str  = ""
    password:  str  = ""
    error:     str  = ""
    groups:    list = field(default_factory=list)


# -- Helpers -------------------------------------------------------------------

def _generate_password(length: int = 20) -> str:
    """Generate a random password meeting Azure AD complexity requirements."""
    lower   = string.ascii_lowercase
    upper   = string.ascii_uppercase
    digits  = string.digits
    special = "!@#%^&*()-_=+[]"
    pwd = (
        [secrets.choice(lower)   for _ in range(3)] +
        [secrets.choice(upper)   for _ in range(3)] +
        [secrets.choice(digits)  for _ in range(3)] +
        [secrets.choice(special) for _ in range(2)]
    )
    remaining = length - len(pwd)
    all_chars = lower + upper + digits + special
    pwd += [secrets.choice(all_chars) for _ in range(remaining)]
    secrets.SystemRandom().shuffle(pwd)
    return "".join(pwd)


# -- Graph API helpers ---------------------------------------------------------

# Token cache: {tenant_id -> token} -- one fetch per unique tenant per run
_token_cache: dict[str, str] = {}


def get_token(tenant_id: str) -> str:
    if tenant_id in _token_cache:
        return _token_cache[tenant_id]
    result = subprocess.run(
        [AZ, "account", "get-access-token",
         "--tenant", tenant_id, "--resource-type", "ms-graph",
         "--query", "accessToken", "--output", "tsv"],
        capture_output=True, text=True
    )
    if result.returncode != 0:
        print(f"ERROR: Failed to get token for tenant {tenant_id}\n{result.stderr.strip()}")
        sys.exit(1)
    token = result.stdout.strip()
    _token_cache[tenant_id] = token
    return token


def _graph_request(token: str, method: str, url: str,
                   body: Optional[dict] = None) -> Optional[bytes]:
    """Execute a Graph API request using urllib (avoids az.cmd shell quoting issues)."""
    data = json.dumps(body).encode() if body else None
    headers = {
        "Authorization": f"Bearer {token}",
        "Content-Type":  "application/json",
        "Accept":        "application/json",
    }
    req = urllib.request.Request(url, data=data, headers=headers, method=method)
    try:
        with urllib.request.urlopen(req) as resp:
            return resp.read()
    except urllib.error.HTTPError as e:
        raise RuntimeError(f"{method} {url}\nHTTP {e.code}: {e.read().decode()}")


def graph_get(token: str, path: str, params: str = "") -> dict:
    url = f"{GRAPH}/{path.lstrip('/')}"
    if params:
        url += "?" + urllib.parse.quote(params, safe="=&$,@")
    raw = _graph_request(token, "GET", url)
    return json.loads(raw)


def graph_post(token: str, path: str, body: dict) -> dict:
    url = f"{GRAPH}/{path.lstrip('/')}"
    raw = _graph_request(token, "POST", url, body)
    return json.loads(raw) if raw else {}


def graph_delete(token: str, path: str) -> None:
    url = f"{GRAPH}/{path.lstrip('/')}"
    _graph_request(token, "DELETE", url)


# -- Core operations -----------------------------------------------------------

def find_user(token: str, upn: str) -> Optional[dict]:
    resp = graph_get(token, "users",
                     f"$filter=userPrincipalName eq '{upn}'&$select=id,displayName,userPrincipalName")
    users = resp.get("value", [])
    return users[0] if users else None


def resolve_group(token: str, display_name: str) -> Optional[dict]:
    """Look up a group by exact display name. Returns {id, displayName} or None."""
    resp = graph_get(token, "groups",
                     f"$filter=displayName eq '{display_name}'&$select=id,displayName")
    groups = resp.get("value", [])
    return groups[0] if groups else None


def create_user(token: str, spec: UserSpec, dry_run: bool) -> UserResult:
    print(f"\n[{spec.upn}]")
    print(f"  tenant_id     : {spec.tenant_id}")
    print(f"  display_name  : {spec.display_name}")
    print(f"  mail_nickname : {spec.mail_nickname}")
    print(f"  usage_location: {spec.usage_location}")
    print(f"  SAML claims   : firstName={spec.first_name or '(not set)'}, lastName={spec.last_name or '(not set)'}")
    print(f"  security_groups: {spec.security_groups}")

    existing = find_user(token, spec.upn)
    if existing:
        print(f"  SKIP -- already exists (object_id={existing['id']})")
        return UserResult(upn=spec.upn, status="skipped", object_id=existing["id"])

    body = {
        "accountEnabled":    True,
        "displayName":       spec.display_name,
        "mailNickname":      spec.mail_nickname,
        "userPrincipalName": spec.upn,
        "mail":              spec.upn,
        "usageLocation":     spec.usage_location,
        "passwordProfile": {
            "forceChangePasswordNextSignIn": True,
            "password": spec.password,
        },
    }
    # SAML claims: firstName -> givenName, lastName -> surname
    if spec.first_name:
        body["givenName"] = spec.first_name
    if spec.last_name:
        body["surname"] = spec.last_name

    # Provenance tag: marks this user as created by automation.
    # Queryable via: $filter=employeeType eq 'delegated-user:create_delegated_users.py'
    body["employeeType"] = "delegated-user:create_delegated_users.py"

    if dry_run:
        print(f"  DRY-RUN -- would POST: {json.dumps(body, indent=4)}")
        return UserResult(upn=spec.upn, status="dry-run", password=spec.password)

    try:
        user = graph_post(token, "users", body)
        print(f"  CREATED -- object_id={user['id']}")
        return UserResult(upn=spec.upn, status="created",
                          object_id=user["id"], password=spec.password)
    except RuntimeError as e:
        print(f"  ERROR -- {e}")
        return UserResult(upn=spec.upn, status="failed", error=str(e))


def assign_groups(token: str, spec: UserSpec, user_id: str, dry_run: bool) -> list[str]:
    """Assign user to each explicitly named security group in spec.security_groups."""
    if not spec.security_groups:
        print("  WARNING: No security_groups specified -- skipping group assignment.")
        return []

    assigned = []
    for group_name in spec.security_groups:
        print(f"  [GROUP] {group_name}", end="")

        if dry_run:
            print(" (dry-run)")
            assigned.append(group_name)
            continue

        group = resolve_group(token, group_name)
        if not group:
            print(f" NOT FOUND -- skipping")
            continue

        try:
            graph_post(token, f"groups/{group['id']}/members/$ref",
                       {"@odata.id": f"{GRAPH}/directoryObjects/{user_id}"})
            print(" OK")
            assigned.append(group_name)
        except RuntimeError as e:
            err = str(e)
            if "already exist" in err.lower() or "conflict" in err.lower():
                print(" already member")
                assigned.append(group_name)
            else:
                print(f" ERROR -- {e}")
    return assigned


def delete_user_by_upn(token: str, upn: str, dry_run: bool) -> None:
    print(f"[DELETE] {upn}")
    user = find_user(token, upn)
    if not user:
        print("  Not found -- nothing to delete.")
        return
    if dry_run:
        print(f"  DRY-RUN -- would delete object_id={user['id']}")
        return
    graph_delete(token, f"users/{user['id']}")
    print(f"  Deleted object_id={user['id']}")


# -- CSV I/O -------------------------------------------------------------------

def _parse_groups(value: str) -> list[str]:
    """Parse pipe-separated group display names, filtering empty strings."""
    return [g.strip() for g in value.split("|") if g.strip()]


def load_csv(path: str, default_tenant_id: str) -> list[UserSpec]:
    specs = []
    with open(path, newline="", encoding="utf-8-sig") as f:
        reader = csv.DictReader(f)
        headers = set(reader.fieldnames or [])
        # tenant_id is required in CSV OR a default must be supplied
        required = CSV_REQUIRED - ({"tenant_id"} if default_tenant_id else set())
        missing = required - headers
        if missing:
            print(f"ERROR: CSV missing required columns: {', '.join(sorted(missing))}")
            sys.exit(1)

        for i, row in enumerate(reader, start=2):
            row = {k: v.strip() for k, v in row.items()}
            tenant_id = row.get("tenant_id", "").strip() or default_tenant_id
            if not tenant_id:
                print(f"ERROR: Row {i} -- no tenant_id in row and no --tenant-id default provided.")
                sys.exit(1)
            try:
                specs.append(UserSpec(
                    tenant_id      = tenant_id,
                    upn_domain     = row["upn_domain"],
                    tenant_key     = row["tenant_key"],
                    org_code       = row["org_code"],
                    role           = row["role"],
                    security_groups= _parse_groups(row.get("security_groups", "")),
                    org_name       = row.get("org_name", ""),
                    suffix         = row.get("suffix", ""),
                    first_name     = row.get("first_name", ""),
                    last_name      = row.get("last_name", ""),
                    display_name   = row.get("display_name", ""),
                    usage_location = row.get("usage_location", "US"),
                    password       = row.get("password", ""),
                    group_prefix   = row.get("group_prefix", "sg"),
                ))
            except Exception as e:
                print(f"ERROR: Row {i} invalid -- {e}")
                sys.exit(1)
    return specs


def write_results_csv(path: str, results: list[UserResult]) -> None:
    with open(path, "w", newline="", encoding="utf-8") as f:
        writer = csv.DictWriter(f, fieldnames=[
            "upn", "status", "object_id", "password", "groups", "error"
        ])
        writer.writeheader()
        for r in results:
            writer.writerow({
                "upn":       r.upn,
                "status":    r.status,
                "object_id": r.object_id,
                "password":  r.password,
                "groups":    "|".join(r.groups),
                "error":     r.error,
            })
    print(f"\nResults written to: {path}")


def write_sample_csv(path: str) -> None:
    rows = [
        {
            "tenant_id":      "",
            "upn_domain":     "sreazrwussim1.onmicrosoft.com",
            "tenant_key":     "sim1",
            "org_code":       "nw",
            "org_name":       "northwind",
            "role":           "admin",
            "suffix":         "jdoe",
            "first_name":     "Jane",
            "last_name":      "Doe",
            "security_groups": "sg-sim1-nw-dev-admin",
            "display_name":   "",
            "usage_location": "US",
            "password":       "",
            "group_prefix":   "sg",
        },
        {
            "tenant_id":      "",
            "upn_domain":     "sreazrwussim1.onmicrosoft.com",
            "tenant_key":     "sim1",
            "org_code":       "nw",
            "org_name":       "northwind",
            "role":           "user",
            "suffix":         "asmith",
            "first_name":     "Alice",
            "last_name":      "Smith",
            "security_groups": "sg-sim1-nw-dev-user|sg-sim1-nw-tst-user",
            "display_name":   "",
            "usage_location": "US",
            "password":       "",
            "group_prefix":   "sg",
        },
        {
            "tenant_id":      "",
            "upn_domain":     "sreazrwussim1.onmicrosoft.com",
            "tenant_key":     "sim1",
            "org_code":       "nw",
            "org_name":       "northwind",
            "role":           "viewer",
            "suffix":         "bjones",
            "first_name":     "Bob",
            "last_name":      "Jones",
            "security_groups": "sg-sim1-nw-dev-viewer",
            "display_name":   "",
            "usage_location": "US",
            "password":       "",
            "group_prefix":   "sg",
        },
    ]
    with open(path, "w", newline="", encoding="utf-8") as f:
        writer = csv.DictWriter(f, fieldnames=list(rows[0].keys()))
        writer.writeheader()
        writer.writerows(rows)
    print(f"Sample CSV written to: {path}")


# -- CLI -----------------------------------------------------------------------

def build_parser() -> argparse.ArgumentParser:
    p = argparse.ArgumentParser(
        prog="create_delegated_users.py",
        description="Create Azure AD delegated users and assign them to specified security groups.",
        formatter_class=argparse.RawDescriptionHelpFormatter,
        epilog=__doc__,
    )

    p.add_argument("--tenant-id",
                   help="Default Azure AD tenant GUID. Used as fallback when tenant_id "
                        "column is absent or empty in CSV. Required for single-user mode.")

    # -- Bulk mode
    bulk = p.add_argument_group("Bulk CSV mode")
    bulk.add_argument("--input-file",
                      help="Path to CSV file. tenant_id column per row overrides --tenant-id.")
    bulk.add_argument("--output-file",
                      help="Path to write results CSV (upn, status, object_id, password, groups, error).")
    bulk.add_argument("--generate-sample",
                      help="Write a sample CSV template to the given path and exit.")

    # -- Single user mode
    single = p.add_argument_group("Single user mode (ignored when --input-file is set)")
    single.add_argument("--upn-domain",
                        help="UPN domain suffix (e.g. sreazrwussim1.onmicrosoft.com).")
    single.add_argument("--upn",
                        help="Full UPN. Required for --delete.")
    single.add_argument("--tenant-key",
                        help="Tenant short key (e.g. sim1).")
    single.add_argument("--org-code",
                        help="Org short code (e.g. nw).")
    single.add_argument("--org-name",
                        help="Full org name (e.g. northwind). Defaults to --org-code.")
    single.add_argument("--role",
                        help="Role: admin | user | viewer.")
    single.add_argument("--suffix", default="",
                        help="UPN suffix for uniqueness (e.g. jdoe).")
    single.add_argument("--first-name",
                        help="Given name -> SAML 'firstName' claim.")
    single.add_argument("--last-name",
                        help="Surname -> SAML 'lastName' claim.")
    single.add_argument("--display-name",
                        help="Override auto-generated display name.")
    single.add_argument("--usage-location", default="US",
                        help="ISO 3166-1 alpha-2 country code (default: US).")
    single.add_argument("--group-prefix", default="sg",
                        help="Security group prefix (default: sg).")
    single.add_argument("--group", dest="groups", action="append", default=[],
                        metavar="GROUP_NAME",
                        help="Exact security group display name to assign the user to. "
                             "Repeat for multiple groups: --group sg-sim1-nw-dev-admin --group sg-sim1-nw-tst-admin")
    single.add_argument("--password",
                        help="Initial password. Auto-generated if omitted.")

    # -- Actions
    p.add_argument("--delete", action="store_true",
                   help="Delete the user specified by --upn.")
    p.add_argument("--dry-run", action="store_true",
                   help="Preview actions without making any changes.")

    return p


def process_spec(spec: UserSpec, dry_run: bool) -> UserResult:
    """Create one user and assign to specified groups. Fetches token per spec.tenant_id."""
    token = get_token(spec.tenant_id)
    result = create_user(token, spec, dry_run)
    if result.status in ("created", "skipped", "dry-run"):
        uid = result.object_id or "DRY_RUN_ID"
        result.groups = assign_groups(token, spec, uid, dry_run)
    return result


def main():
    parser = build_parser()
    args = parser.parse_args()

    # -- Generate sample CSV and exit
    if args.generate_sample:
        write_sample_csv(args.generate_sample)
        return

    # -- DELETE mode
    if args.delete:
        if not args.upn:
            parser.error("--upn is required with --delete")
        if not args.tenant_id:
            parser.error("--tenant-id is required with --delete")
        token = get_token(args.tenant_id)
        delete_user_by_upn(token, args.upn, args.dry_run)
        print("\nDone.")
        return

    # -- BULK mode
    if args.input_file:
        specs = load_csv(args.input_file, args.tenant_id or "")
        print(f"\nInput file : {args.input_file} ({len(specs)} users)")
        print(f"Dry run    : {args.dry_run}\n")

        results = []
        for i, spec in enumerate(specs, 1):
            print(f"-- [{i}/{len(specs)}]", end="")
            results.append(process_spec(spec, args.dry_run))

        counts = {"created": 0, "skipped": 0, "failed": 0, "dry-run": 0}
        for r in results:
            counts[r.status] = counts.get(r.status, 0) + 1

        print(f"\n{'-'*50}")
        print(f"Total  : {len(results)}")
        print(f"Created: {counts['created']}")
        print(f"Skipped: {counts['skipped']}")
        print(f"Failed : {counts['failed']}")
        if args.dry_run:
            print(f"Dry-run: {counts['dry-run']}")

        if args.output_file:
            write_results_csv(args.output_file, results)
        elif any(r.password for r in results):
            print("\nWARNING: Passwords were generated but --output-file not set. "
                  "Use --output-file to save credentials.")
        print("\nDone.")
        return

    # -- SINGLE user mode
    if not args.tenant_id:
        parser.error("--tenant-id is required")
    for req in ("tenant_key", "org_code", "role", "upn_domain"):
        if not getattr(args, req):
            parser.error(f"--{req.replace('_', '-')} is required when creating a single user")

    print(f"\nTenant : {args.tenant_id}")
    print(f"Dry run: {args.dry_run}")

    spec = UserSpec(
        tenant_id      = args.tenant_id,
        upn_domain     = args.upn_domain,
        tenant_key     = args.tenant_key,
        org_code       = args.org_code,
        role           = args.role,
        security_groups= args.groups,
        org_name       = args.org_name or "",
        suffix         = args.suffix or "",
        first_name     = args.first_name or "",
        last_name      = args.last_name or "",
        display_name   = args.display_name or "",
        usage_location = args.usage_location,
        password       = args.password or "",
        group_prefix   = args.group_prefix,
    )

    result = process_spec(spec, args.dry_run)

    if args.output_file:
        write_results_csv(args.output_file, [result])
    elif result.password and result.status == "created":
        print(f"\nPassword : {result.password}")
        print("WARNING  : Use --output-file to save credentials securely.")

    print("\nDone.")


if __name__ == "__main__":
    main()
