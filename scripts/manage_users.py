#!/usr/bin/env python3
"""
================================================================================
 manage_users.py -- Keycloak user manager for sim2 realm
================================================================================

PURPOSE
-------
Add users (new or existing) to Keycloak security groups (sg-*) in a given
realm. Supports single-user operations, multi-group targeting, and bulk
imports via CSV file.

REQUIREMENTS
------------
  pip install requests

  Set admin credentials via environment variables (recommended):
    export KEYCLOAK_URL="https://idp-keycloak.cloud.nxteam.dev/auth"
    export KEYCLOAK_USER="admin"
    export KEYCLOAK_PASSWORD="<password>"

  Or pass them directly as CLI flags (see FLAGS section below).

FLAGS
-----
  --realm REALM         Keycloak realm name. Required. (e.g. sim2)

  Group targeting (pick one):
    --group  NAME         Add to a single named group.
    --groups G1,G2,...    Add to multiple groups (comma-separated, no spaces).
    --all-groups          Add to every sg-* group in the realm (15 groups).

  User source (pick one):
    --user EMAIL          Single user by email address.
    --csv  FILE           Path to a CSV file for bulk import.
    --list-groups         Print all groups in the realm and exit.

  Optional:
    --first-name NAME     First name -- used when creating a new user (single-user mode).
    --last-name  NAME     Last name  -- used when creating a new user (single-user mode).
    --dry-run             Simulate all operations. No connection to Keycloak is made.
                          Uses the known sim2 group list for validation.
    --url URL             Keycloak base URL. Overrides KEYCLOAK_URL env var.
    --kc-user ADMIN       Admin username.   Overrides KEYCLOAK_USER env var.
    --kc-password PASS    Admin password.   Overrides KEYCLOAK_PASSWORD env var.

BEHAVIOUR
---------
  - If the user does not exist in Keycloak, they are created automatically.
    A first name and last name should be supplied in this case (via CLI flags
    or the CSV first_name / last_name columns).
  - If the user is already a member of the target group, they are skipped
    (not an error).
  - Group names are validated before any user operations begin. An unknown
    group name prints the full list of available groups and exits.
  - --dry-run never modifies Keycloak. Use it to preview changes before
    applying them to a live realm.

CSV FORMAT
----------
  Required column : email
  Optional columns: first_name, last_name, groups

  The 'groups' column controls which groups each row is assigned to:
    - One group name     : sg-nw-dev-admin
    - Multiple groups    : "sg-nw-dev-admin,sg-nw-tst-user"   (quote if using commas)
    - ALL groups         : ALL
    - Empty / omitted    : falls back to the CLI --group / --groups / --all-groups flag

  Example CSV (save as users.csv):
    email,first_name,last_name,groups
    alice@example.com,Alice,Smith,sg-nw-dev-admin
    bob@example.com,Bob,Jones,"sg-nw-dev-user,sg-nw-tst-user"
    carol@example.com,Carol,White,ALL
    dave@example.com,Dave,Black,

EXAMPLES
--------
  # 1. List all available groups in the realm
  python manage_users.py --realm sim2 --list-groups

  # 2. Preview the group list without connecting to Keycloak
  python manage_users.py --realm sim2 --list-groups --dry-run

  # 3. Add a single existing user to one group
  python manage_users.py --realm sim2 \
      --user john.doe@acme.com \
      --group sg-nw-dev-admin

  # 4. Create a new user and add them to one group
  python manage_users.py --realm sim2 \
      --user jane.doe@acme.com --first-name Jane --last-name Doe \
      --group sg-nw-qa-viewer

  # 5. Add a user to multiple specific groups
  python manage_users.py --realm sim2 \
      --user john.doe@acme.com \
      --groups sg-nw-dev-admin,sg-nw-tst-user,sg-nw-qa-viewer

  # 6. Add a user to ALL sg-* groups in the realm
  python manage_users.py --realm sim2 \
      --user john.doe@acme.com \
      --all-groups

  # 7. Bulk import from CSV -- each row uses its own 'groups' column
  python manage_users.py --realm sim2 --csv users.csv

  # 8. Bulk import -- rows with no 'groups' column fall back to --all-groups
  python manage_users.py --realm sim2 --csv users.csv --all-groups

  # 9. Dry-run a bulk CSV import (no Keycloak password needed)
  python manage_users.py --realm sim2 --csv users.csv --all-groups --dry-run

  # 10. Pass credentials inline (instead of environment variables)
  python manage_users.py --realm sim2 \
      --url https://idp-keycloak.cloud.nxteam.dev/auth \
      --kc-user admin --kc-password mypassword \
      --user john.doe@acme.com --group sg-nw-dev-admin

GROUP NAMES (sim2 realm)
------------------------
  Format: sg-{org_code}-{env}-{role}
  Org code : nw  (northwind)
  Envs     : dev, tst, qa, qa2, prd
  Roles    : admin, user, viewer

  Full list:
    sg-nw-dev-admin    sg-nw-dev-user    sg-nw-dev-viewer
    sg-nw-tst-admin    sg-nw-tst-user    sg-nw-tst-viewer
    sg-nw-qa-admin     sg-nw-qa-user     sg-nw-qa-viewer
    sg-nw-qa2-admin    sg-nw-qa2-user    sg-nw-qa2-viewer
    sg-nw-prd-admin    sg-nw-prd-user    sg-nw-prd-viewer
================================================================================
"""

import argparse
import csv
import os
import sys
import textwrap
import uuid
from dataclasses import dataclass, field
from typing import Optional

try:
    import requests
    HAS_REQUESTS = True
except ImportError:
    HAS_REQUESTS = False

# -- Constants -----------------------------------------------------------------

DEFAULT_URL  = "https://idp-keycloak.cloud.nxteam.dev/auth"
ALL_SENTINEL = "ALL"

# Groups that exist in Keycloak sim2 (used for dry-run simulation)
MOCK_GROUPS = [
    {"id": str(uuid.uuid5(uuid.NAMESPACE_DNS, n)), "name": n}
    for n in [
        "sg-nw-dev-admin",   "sg-nw-dev-user",   "sg-nw-dev-viewer",
        "sg-nw-tst-admin",   "sg-nw-tst-user",   "sg-nw-tst-viewer",
        "sg-nw-qa-admin",    "sg-nw-qa-user",     "sg-nw-qa-viewer",
        "sg-nw-qa2-admin",   "sg-nw-qa2-user",    "sg-nw-qa2-viewer",
        "sg-nw-prd-admin",   "sg-nw-prd-user",    "sg-nw-prd-viewer",
    ]
]


# -- Data classes ---------------------------------------------------------------

@dataclass
class UserRecord:
    email:      str
    first_name: str = ""
    last_name:  str = ""
    groups:     list[str] = field(default_factory=list)
    all_groups: bool = False


# -- Dry-run Keycloak stub ------------------------------------------------------

class KeycloakDryRun:
    """Simulates KeycloakAdmin without any HTTP calls."""

    def __init__(self, base_url: str, realm: str, **_):
        self.base_url = base_url
        self.realm    = realm
        self._users: dict[str, dict] = {}       # email -> {id, groups: set[str]}
        print(f"  [dry-run] No connection made -- simulating realm '{realm}'")

    def list_groups(self) -> list[dict]:
        return MOCK_GROUPS

    def sg_groups(self) -> list[dict]:
        return [g for g in MOCK_GROUPS if g["name"].startswith("sg-")]

    def find_group(self, name: str) -> Optional[dict]:
        return next((g for g in MOCK_GROUPS if g["name"] == name), None)

    def resolve_groups(self, names: list[str]) -> list[dict]:
        result, unknown = [], []
        for name in names:
            g = self.find_group(name)
            (result if g else unknown).append(g if g else name)
        if unknown:
            available = sorted(g["name"] for g in MOCK_GROUPS)
            print(f"\nUnknown group(s): {', '.join(unknown)}")
            print("Available groups:")
            for g in available:
                print(f"  {g}")
            sys.exit(1)
        return result

    def find_user(self, email: str) -> Optional[dict]:
        return self._users.get(email)

    def create_user(self, record: "UserRecord") -> str:
        uid = str(uuid.uuid4())
        self._users[record.email] = {"id": uid, "groups": set()}
        return uid

    def get_or_create_user(self, record: "UserRecord") -> tuple[str, bool]:
        existing = self.find_user(record.email)
        if existing:
            return existing["id"], False
        uid = self.create_user(record)
        return uid, True

    def user_groups(self, user_id: str) -> set[str]:
        for u in self._users.values():
            if u["id"] == user_id:
                return u["groups"]
        return set()

    def add_to_group(self, user_id: str, group_id: str) -> None:
        for u in self._users.values():
            if u["id"] == user_id:
                u["groups"].add(group_id)
                return


# -- Real Keycloak client -------------------------------------------------------

class KeycloakAdmin:
    def __init__(self, base_url: str, realm: str, username: str, password: str):
        if not HAS_REQUESTS:
            print("Error: 'requests' library not installed. Run: pip install requests")
            sys.exit(1)
        self.base_url = base_url.rstrip("/")
        self.realm    = realm
        self._token: Optional[str] = None
        self._group_cache: Optional[list[dict]] = None
        self._authenticate(username, password)

    def _authenticate(self, username: str, password: str) -> None:
        url  = f"{self.base_url}/realms/master/protocol/openid-connect/token"
        resp = requests.post(url, data={
            "client_id":  "admin-cli",
            "username":   username,
            "password":   password,
            "grant_type": "password",
        }, timeout=15)
        resp.raise_for_status()
        self._token = resp.json()["access_token"]

    def _h(self) -> dict:
        return {"Authorization": f"Bearer {self._token}", "Content-Type": "application/json"}

    def _url(self, path: str) -> str:
        return f"{self.base_url}/admin/realms/{self.realm}/{path.lstrip('/')}"

    def list_groups(self) -> list[dict]:
        if self._group_cache is None:
            resp = requests.get(self._url("groups"), headers=self._h(),
                                params={"max": 500}, timeout=15)
            resp.raise_for_status()
            self._group_cache = resp.json()
        return self._group_cache

    def sg_groups(self) -> list[dict]:
        return [g for g in self.list_groups() if g["name"].startswith("sg-")]

    def find_group(self, name: str) -> Optional[dict]:
        return next((g for g in self.list_groups() if g["name"] == name), None)

    def resolve_groups(self, names: list[str]) -> list[dict]:
        result, unknown = [], []
        for name in names:
            g = self.find_group(name)
            (result if g else unknown).append(g if g else name)
        if unknown:
            available = sorted(g["name"] for g in self.list_groups())
            print(f"\nUnknown group(s): {', '.join(unknown)}")
            print("Available groups:")
            for g in available:
                print(f"  {g}")
            sys.exit(1)
        return result

    def find_user(self, email: str) -> Optional[dict]:
        resp = requests.get(self._url("users"), headers=self._h(),
                            params={"email": email, "exact": "true", "max": 2},
                            timeout=15)
        resp.raise_for_status()
        users = resp.json()
        return users[0] if users else None

    def create_user(self, record: UserRecord) -> str:
        resp = requests.post(self._url("users"), headers=self._h(), timeout=15,
                             json={"username":  record.email,
                                   "email":     record.email,
                                   "firstName": record.first_name,
                                   "lastName":  record.last_name,
                                   "enabled":   True})
        resp.raise_for_status()
        return resp.headers["Location"].rstrip("/").split("/")[-1]

    def get_or_create_user(self, record: UserRecord) -> tuple[str, bool]:
        existing = self.find_user(record.email)
        if existing:
            return existing["id"], False
        return self.create_user(record), True

    def user_groups(self, user_id: str) -> set[str]:
        resp = requests.get(self._url(f"users/{user_id}/groups"), headers=self._h(),
                            params={"max": 500}, timeout=15)
        resp.raise_for_status()
        return {g["id"] for g in resp.json()}

    def add_to_group(self, user_id: str, group_id: str) -> None:
        resp = requests.put(self._url(f"users/{user_id}/groups/{group_id}"),
                            headers=self._h(), timeout=15)
        resp.raise_for_status()


# -- Core logic ----------------------------------------------------------------

def process_user(kc, record: UserRecord, target_groups: list[dict],
                 dry_run: bool = False) -> tuple[int, int]:
    """Returns (added, skipped)."""
    prefix = "[DRY-RUN] " if dry_run else ""
    user_id, created = kc.get_or_create_user(record)
    verb = "create" if created else "found"
    short_id = user_id[:8]
    print(f"  {prefix}[{verb}] {record.email}  ({short_id}...)")

    existing = kc.user_groups(user_id)
    added = skipped = 0

    for group in target_groups:
        if group["id"] in existing:
            print(f"    already in  {group['name']}")
            skipped += 1
        else:
            kc.add_to_group(user_id, group["id"])
            action = "would add ->" if dry_run else "added ->  "
            print(f"    {action} {group['name']}")
            added += 1

    return added, skipped


# -- CSV loader ----------------------------------------------------------------

def load_csv(path: str) -> list[UserRecord]:
    records: list[UserRecord] = []
    with open(path, newline="", encoding="utf-8") as fh:
        reader = csv.DictReader(fh)
        if "email" not in (reader.fieldnames or []):
            print(f"Error: CSV must have an 'email' column. Found: {reader.fieldnames}")
            sys.exit(1)
        for i, row in enumerate(reader, start=2):
            email = row.get("email", "").strip()
            if not email:
                print(f"  Row {i}: empty email -- skipped")
                continue
            raw    = row.get("groups", "").strip()
            is_all = raw.upper() == ALL_SENTINEL
            glist  = [] if (not raw or is_all) else [g.strip() for g in raw.split(",") if g.strip()]
            records.append(UserRecord(
                email=email,
                first_name=row.get("first_name", "").strip(),
                last_name=row.get("last_name",  "").strip(),
                groups=glist,
                all_groups=is_all,
            ))
    return records


# -- CLI -----------------------------------------------------------------------

def build_parser() -> argparse.ArgumentParser:
    p = argparse.ArgumentParser(
        description="Add Keycloak users to specific or all SG groups.",
        formatter_class=argparse.RawDescriptionHelpFormatter,
        epilog=textwrap.dedent(f"""
            Group targeting (precedence: row 'groups' column > CLI flags):
              --all-groups          all sg-* groups in the realm
              --groups g1,g2,g3     named groups (comma-separated)
              --group  name         single group
              CSV 'groups' column   per-row override; '{ALL_SENTINEL}' = all groups

            CSV format (email required):
              email,first_name,last_name,groups
              alice@x.com,Alice,Smith,sg-nw-dev-admin
              bob@x.com,Bob,Jones,"sg-nw-dev-user,sg-nw-tst-user"
              carol@x.com,Carol,White,ALL
              dave@x.com,Dave,Black,   <- inherits CLI --group/--groups/--all-groups

            Examples:
              python manage_users.py --realm sim2 --user j@x.com --group sg-nw-dev-admin
              python manage_users.py --realm sim2 --user j@x.com --groups sg-nw-dev-admin,sg-nw-tst-user
              python manage_users.py --realm sim2 --user j@x.com --all-groups
              python manage_users.py --realm sim2 --csv users.csv --all-groups
              python manage_users.py --realm sim2 --csv users.csv --all-groups --dry-run
              python manage_users.py --realm sim2 --list-groups
        """),
    )

    p.add_argument("--realm", required=True, help="Keycloak realm (e.g. sim2)")
    p.add_argument("--dry-run", action="store_true",
                   help="Simulate all operations without connecting to Keycloak")

    grp = p.add_mutually_exclusive_group()
    grp.add_argument("--all-groups", action="store_true",
                     help="Target all sg-* groups")
    grp.add_argument("--groups", metavar="G1,G2,...",
                     help="Comma-separated group names")
    grp.add_argument("--group", metavar="GROUP",
                     help="Single group name")

    src = p.add_mutually_exclusive_group()
    src.add_argument("--user",        metavar="EMAIL", help="Single user email")
    src.add_argument("--csv",         metavar="FILE",  help="CSV file path")
    src.add_argument("--list-groups", action="store_true",
                     help="List all groups in the realm and exit")

    p.add_argument("--first-name", default="", help="First name (single-user mode)")
    p.add_argument("--last-name",  default="", help="Last name  (single-user mode)")
    p.add_argument("--url",
                   default=os.environ.get("KEYCLOAK_URL", DEFAULT_URL),
                   help="Keycloak base URL")
    p.add_argument("--kc-user",
                   default=os.environ.get("KEYCLOAK_USER", "admin"),
                   metavar="ADMIN")
    p.add_argument("--kc-password",
                   default=os.environ.get("KEYCLOAK_PASSWORD", ""),
                   metavar="PASSWORD")
    return p


def main() -> None:
    parser = build_parser()
    args   = parser.parse_args()

    dry_run = args.dry_run

    if not dry_run and not args.kc_password:
        parser.error("KEYCLOAK_PASSWORD required (or use --dry-run for simulation)")

    print(f"Keycloak : {args.url}")
    print(f"Realm    : {args.realm}")
    if dry_run:
        print(f"Mode     : DRY-RUN (no changes will be made)")

    # -- Instantiate client ----------------------------------------------------
    if dry_run:
        kc = KeycloakDryRun(base_url=args.url, realm=args.realm)
    else:
        kc = KeycloakAdmin(
            base_url=args.url, realm=args.realm,
            username=args.kc_user, password=args.kc_password,
        )

    # -- List groups -----------------------------------------------------------
    if args.list_groups:
        all_g = kc.list_groups()
        sg    = sorted(g["name"] for g in all_g if g["name"].startswith("sg-"))
        rest  = sorted(g["name"] for g in all_g if not g["name"].startswith("sg-"))
        print(f"\nSG groups ({len(sg)}):")
        for g in sg:
            print(f"  {g}")
        if rest:
            print(f"\nOther groups ({len(rest)}):")
            for g in rest:
                print(f"  {g}")
        return

    # -- Resolve CLI-level groups ----------------------------------------------
    cli_all    = args.all_groups
    cli_groups: list[dict] = []

    if cli_all:
        cli_groups = kc.sg_groups()
        print(f"Target   : ALL sg-* groups ({len(cli_groups)})\n")
    elif args.groups:
        names      = [n.strip() for n in args.groups.split(",") if n.strip()]
        cli_groups = kc.resolve_groups(names)
        print(f"Target   : {', '.join(g['name'] for g in cli_groups)}\n")
    elif args.group:
        cli_groups = kc.resolve_groups([args.group])
        print(f"Target   : {args.group}\n")

    # -- Single user -----------------------------------------------------------
    if args.user:
        if not cli_groups:
            parser.error("Specify --group, --groups, or --all-groups")
        added, skipped = process_user(
            kc,
            UserRecord(email=args.user, first_name=args.first_name,
                       last_name=args.last_name),
            cli_groups, dry_run,
        )
        print(f"\n{'-'*48}")
        print(f"{'Would add' if dry_run else 'Added'}  : {added}")
        print(f"Skipped  : {skipped} (already member)")
        return

    # -- CSV bulk --------------------------------------------------------------
    if args.csv:
        records = load_csv(args.csv)
        print(f"CSV      : {args.csv} ({len(records)} rows)")
        print(f"{'-'*48}")

        total_added = total_skipped = total_err = 0

        for rec in records:
            if rec.all_groups:
                target = kc.sg_groups()
            elif rec.groups:
                target = kc.resolve_groups(rec.groups)
            elif cli_groups or cli_all:
                target = cli_groups if cli_groups else kc.sg_groups()
            else:
                print(f"  SKIP {rec.email}: no group (add --group/--groups/--all-groups or CSV 'groups' column)")
                continue

            try:
                a, s = process_user(kc, rec, target, dry_run)
                total_added   += a
                total_skipped += s
            except Exception as exc:
                print(f"  ERROR {rec.email}: {exc}")
                total_err += 1

        print(f"\n{'-'*48}")
        print(f"{'Would add' if dry_run else 'Added'}  : {total_added}")
        print(f"Skipped  : {total_skipped} (already member)")
        print(f"Errors   : {total_err}")
        return

    parser.print_help()


if __name__ == "__main__":
    main()
