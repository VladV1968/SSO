# ==============================================================================
# TARGETED IMPORT SCRIPT — imports only what is still missing from state
# Run from: C:\Tools\Gitlab\sre\private-cloud\core-infra-iac\SSO\live\region-a\ad-tenant
# AZUREAD_* env vars must be set before running.
# ==============================================================================
# This script uses direct single-quoted terragrunt import calls for reliability.
# Each call is sequential, no concurrent lock contention.
# "Resource already managed by Terraform" = skip silently (already imported).
# ==============================================================================

$ErrorActionPreference = "Continue"
$ok = 0
$skipped = 0
$failed = @()

function tg-import($addr, $id) {
    Write-Host "  $addr" -ForegroundColor Cyan
    $out = terragrunt import $addr $id 2>&1
    $code = $LASTEXITCODE
    $outStr = ($out -join "`n")
    if ($code -eq 0) {
        Write-Host "  --> OK" -ForegroundColor Green
        $script:ok++
    } elseif ($outStr -match "Resource already managed by Terraform") {
        Write-Host "  --> SKIP (already in state)" -ForegroundColor DarkGray
        $script:skipped++
    } else {
        Write-Host "  --> FAILED (exit $code)" -ForegroundColor Red
        # Show last meaningful error line
        $errLine = ($out | Where-Object { $_ -match "Error:" } | Select-Object -Last 1)
        if ($errLine) { Write-Host "      $errLine" -ForegroundColor DarkRed }
        $script:failed += "$addr"
    }
}

Write-Host "`n=== MISSING GROUPS (27) ===" -ForegroundColor Yellow

# Contoso missing: qa-user, qa-viewer, qa2-admin, qa2-viewer, tst-viewer
tg-import 'azuread_group.org_env_role["sim1-contoso-qa-user"]'    "719a4777-b67c-4622-bea6-637d99a65cd6"
tg-import 'azuread_group.org_env_role["sim1-contoso-qa-viewer"]'  "6a8fc338-fdec-4167-8084-8540f8552f2b"
tg-import 'azuread_group.org_env_role["sim1-contoso-qa2-admin"]'  "6253fde5-916b-4fe6-aab3-6ec7781f6fb9"
tg-import 'azuread_group.org_env_role["sim1-contoso-qa2-viewer"]' "d267cae7-9968-4f2d-a592-6a68ef7c68fc"
tg-import 'azuread_group.org_env_role["sim1-contoso-tst-viewer"]' "a07dbdb4-befd-4351-a66a-2c718fa1b213"

# Fabrikam missing: dev-admin, prd-admin, prd-user, qa-user, qa-viewer, qa2-admin, qa2-viewer, tst-admin, tst-viewer
tg-import 'azuread_group.org_env_role["sim1-fabrikam-dev-admin"]'   "15c05556-9624-4536-865d-3bb03cbf68b0"
tg-import 'azuread_group.org_env_role["sim1-fabrikam-prd-admin"]'   "e531bb41-0e43-4bc2-aaaf-1048f5fc99ef"
tg-import 'azuread_group.org_env_role["sim1-fabrikam-prd-user"]'    "11e0fdbe-471d-45b2-9f16-15f0b652fb6e"
tg-import 'azuread_group.org_env_role["sim1-fabrikam-qa-user"]'     "da70bf48-84a0-4498-a6e0-bace9f5e347a"
tg-import 'azuread_group.org_env_role["sim1-fabrikam-qa-viewer"]'   "e7be92c9-11c8-47f4-be06-8ec8ed54fcda"
tg-import 'azuread_group.org_env_role["sim1-fabrikam-qa2-admin"]'   "8a128ba8-e0bc-4acb-a558-6f37801c8212"
tg-import 'azuread_group.org_env_role["sim1-fabrikam-qa2-viewer"]'  "4600ced9-3265-4157-9c79-6a9b7ec28e35"
tg-import 'azuread_group.org_env_role["sim1-fabrikam-tst-admin"]'   "dd142443-8fc3-439a-a352-4799e3fda9a2"
tg-import 'azuread_group.org_env_role["sim1-fabrikam-tst-viewer"]'  "7a793658-19f2-43c7-9f3c-d21c00516fe0"

# Northwind all 15 missing
tg-import 'azuread_group.org_env_role["sim1-northwind-dev-admin"]'  "325e9cfa-9322-416f-b4ec-3ad8fbebf660"
tg-import 'azuread_group.org_env_role["sim1-northwind-dev-user"]'   "f9614dd9-2594-4c25-b5ba-ee361b747b35"
tg-import 'azuread_group.org_env_role["sim1-northwind-dev-viewer"]' "c3e6ef73-6849-497b-b391-0d48a25fd042"
tg-import 'azuread_group.org_env_role["sim1-northwind-prd-admin"]'  "f029ac7e-fe26-4f27-8056-e54026f84ea8"
tg-import 'azuread_group.org_env_role["sim1-northwind-prd-user"]'   "f0964ba0-712e-432d-824b-f4e0f58d20ff"
tg-import 'azuread_group.org_env_role["sim1-northwind-prd-viewer"]' "55980c5a-ff04-44c4-9a13-8609fac67f81"
tg-import 'azuread_group.org_env_role["sim1-northwind-qa-admin"]'   "1df7c963-f4f1-4a17-a6ff-87c1e1fc09d4"
tg-import 'azuread_group.org_env_role["sim1-northwind-qa-user"]'    "d48d0010-285e-49ff-8e09-3e6a3afacb6f"
tg-import 'azuread_group.org_env_role["sim1-northwind-qa-viewer"]'  "7524c970-8200-426d-87af-87ef12975528"
tg-import 'azuread_group.org_env_role["sim1-northwind-qa2-admin"]'  "64704eff-8538-49ca-9cb2-1e3f53e401de"
tg-import 'azuread_group.org_env_role["sim1-northwind-qa2-user"]'   "60a95217-7d07-4c50-9a39-eb736c4194b0"
tg-import 'azuread_group.org_env_role["sim1-northwind-qa2-viewer"]' "6ad35ba9-7af5-4017-9315-daa571984215"
tg-import 'azuread_group.org_env_role["sim1-northwind-tst-admin"]'  "e4c95c70-44d4-4e41-9729-5bed1817ea04"
tg-import 'azuread_group.org_env_role["sim1-northwind-tst-user"]'   "9db48c3e-f118-407d-9e52-5fa587d5c229"
tg-import 'azuread_group.org_env_role["sim1-northwind-tst-viewer"]' "130c5e5a-7cfc-4786-93c8-7239af0a1805"

Write-Host "`n=== USERS (9) ===" -ForegroundColor Yellow
tg-import 'azuread_user.org_role["sim1-contoso-admin"]'    "aa222cb1-eb3b-4458-89ec-ecba1a59101e"
tg-import 'azuread_user.org_role["sim1-contoso-user"]'     "14853fe9-f01d-43f1-8162-fad1054ad7a8"
tg-import 'azuread_user.org_role["sim1-contoso-viewer"]'   "7b96d539-05d6-4973-8005-5a8703f0c2fd"
tg-import 'azuread_user.org_role["sim1-fabrikam-admin"]'   "924f1703-ba0b-4d5d-b36e-e9920de2e0cc"
tg-import 'azuread_user.org_role["sim1-fabrikam-user"]'    "b1748142-e0c5-4057-83d7-4fbe24e6f890"
tg-import 'azuread_user.org_role["sim1-fabrikam-viewer"]'  "dbb136dc-fb6e-46d8-83a3-4b9b8a462e3c"
tg-import 'azuread_user.org_role["sim1-northwind-admin"]'  "48b4bac3-1b67-463e-9114-fa7a2c4d5114"
tg-import 'azuread_user.org_role["sim1-northwind-user"]'   "b4b2b88a-aad9-4235-a4de-3f679b9ef7d4"
tg-import 'azuread_user.org_role["sim1-northwind-viewer"]' "4d8486e4-e9cb-4303-8446-711f07ad2e06"

Write-Host "`n=== GROUP MEMBERSHIPS (45) ===" -ForegroundColor Yellow
# Format: {group_id}/member/{user_id}
# contoso groups → contoso users
tg-import 'azuread_group_member.user_env_role["sim1-contoso-dev-admin"]'    "c44b348f-2bd2-4992-bf09-48b7a504c822/member/aa222cb1-eb3b-4458-89ec-ecba1a59101e"
tg-import 'azuread_group_member.user_env_role["sim1-contoso-dev-user"]'     "9f92c56b-2419-4001-b65c-19ca6ffbc422/member/14853fe9-f01d-43f1-8162-fad1054ad7a8"
tg-import 'azuread_group_member.user_env_role["sim1-contoso-dev-viewer"]'   "5b49d3c5-7b2e-45e2-8fd6-0d8d49fa0d11/member/7b96d539-05d6-4973-8005-5a8703f0c2fd"
tg-import 'azuread_group_member.user_env_role["sim1-contoso-prd-admin"]'    "ac391fda-e490-40ac-92ef-d8c908747671/member/aa222cb1-eb3b-4458-89ec-ecba1a59101e"
tg-import 'azuread_group_member.user_env_role["sim1-contoso-prd-user"]'     "6e25067e-f1c9-41d6-ae3a-6b661dbb71ad/member/14853fe9-f01d-43f1-8162-fad1054ad7a8"
tg-import 'azuread_group_member.user_env_role["sim1-contoso-prd-viewer"]'   "15f39352-f836-44d4-a8ff-8a1a84ec43f9/member/7b96d539-05d6-4973-8005-5a8703f0c2fd"
tg-import 'azuread_group_member.user_env_role["sim1-contoso-qa-admin"]'     "9ed66a80-184e-4e0f-bda6-ef0b82a2911e/member/aa222cb1-eb3b-4458-89ec-ecba1a59101e"
tg-import 'azuread_group_member.user_env_role["sim1-contoso-qa-user"]'      "719a4777-b67c-4622-bea6-637d99a65cd6/member/14853fe9-f01d-43f1-8162-fad1054ad7a8"
tg-import 'azuread_group_member.user_env_role["sim1-contoso-qa-viewer"]'    "6a8fc338-fdec-4167-8084-8540f8552f2b/member/7b96d539-05d6-4973-8005-5a8703f0c2fd"
tg-import 'azuread_group_member.user_env_role["sim1-contoso-qa2-admin"]'    "6253fde5-916b-4fe6-aab3-6ec7781f6fb9/member/aa222cb1-eb3b-4458-89ec-ecba1a59101e"
tg-import 'azuread_group_member.user_env_role["sim1-contoso-qa2-user"]'     "eb00cd3b-f098-449e-8649-ef7bece61d74/member/14853fe9-f01d-43f1-8162-fad1054ad7a8"
tg-import 'azuread_group_member.user_env_role["sim1-contoso-qa2-viewer"]'   "d267cae7-9968-4f2d-a592-6a68ef7c68fc/member/7b96d539-05d6-4973-8005-5a8703f0c2fd"
tg-import 'azuread_group_member.user_env_role["sim1-contoso-tst-admin"]'    "3c6ed00e-43cc-4cc7-a299-fe497b51e8a6/member/aa222cb1-eb3b-4458-89ec-ecba1a59101e"
tg-import 'azuread_group_member.user_env_role["sim1-contoso-tst-user"]'     "df416e17-c1bc-4f20-a68e-6de6e9218b92/member/14853fe9-f01d-43f1-8162-fad1054ad7a8"
tg-import 'azuread_group_member.user_env_role["sim1-contoso-tst-viewer"]'   "a07dbdb4-befd-4351-a66a-2c718fa1b213/member/7b96d539-05d6-4973-8005-5a8703f0c2fd"
# fabrikam groups → fabrikam users
tg-import 'azuread_group_member.user_env_role["sim1-fabrikam-dev-admin"]'   "15c05556-9624-4536-865d-3bb03cbf68b0/member/924f1703-ba0b-4d5d-b36e-e9920de2e0cc"
tg-import 'azuread_group_member.user_env_role["sim1-fabrikam-dev-user"]'    "c201ca87-9214-4f36-b9a3-88b32ad3e7bf/member/b1748142-e0c5-4057-83d7-4fbe24e6f890"
tg-import 'azuread_group_member.user_env_role["sim1-fabrikam-dev-viewer"]'  "d8b7de74-791a-4535-b8d0-684106325113/member/dbb136dc-fb6e-46d8-83a3-4b9b8a462e3c"
tg-import 'azuread_group_member.user_env_role["sim1-fabrikam-prd-admin"]'   "e531bb41-0e43-4bc2-aaaf-1048f5fc99ef/member/924f1703-ba0b-4d5d-b36e-e9920de2e0cc"
tg-import 'azuread_group_member.user_env_role["sim1-fabrikam-prd-user"]'    "11e0fdbe-471d-45b2-9f16-15f0b652fb6e/member/b1748142-e0c5-4057-83d7-4fbe24e6f890"
tg-import 'azuread_group_member.user_env_role["sim1-fabrikam-prd-viewer"]'  "10d28d85-4ff9-4cee-9be5-63bb04df07cc/member/dbb136dc-fb6e-46d8-83a3-4b9b8a462e3c"
tg-import 'azuread_group_member.user_env_role["sim1-fabrikam-qa-admin"]'    "54c1f487-ab2e-4d1d-ab22-1597d7c4a150/member/924f1703-ba0b-4d5d-b36e-e9920de2e0cc"
tg-import 'azuread_group_member.user_env_role["sim1-fabrikam-qa-user"]'     "da70bf48-84a0-4498-a6e0-bace9f5e347a/member/b1748142-e0c5-4057-83d7-4fbe24e6f890"
tg-import 'azuread_group_member.user_env_role["sim1-fabrikam-qa-viewer"]'   "e7be92c9-11c8-47f4-be06-8ec8ed54fcda/member/dbb136dc-fb6e-46d8-83a3-4b9b8a462e3c"
tg-import 'azuread_group_member.user_env_role["sim1-fabrikam-qa2-admin"]'   "8a128ba8-e0bc-4acb-a558-6f37801c8212/member/924f1703-ba0b-4d5d-b36e-e9920de2e0cc"
tg-import 'azuread_group_member.user_env_role["sim1-fabrikam-qa2-user"]'    "3de6935e-640e-47c7-96eb-62b3c197475f/member/b1748142-e0c5-4057-83d7-4fbe24e6f890"
tg-import 'azuread_group_member.user_env_role["sim1-fabrikam-qa2-viewer"]'  "4600ced9-3265-4157-9c79-6a9b7ec28e35/member/dbb136dc-fb6e-46d8-83a3-4b9b8a462e3c"
tg-import 'azuread_group_member.user_env_role["sim1-fabrikam-tst-admin"]'   "dd142443-8fc3-439a-a352-4799e3fda9a2/member/924f1703-ba0b-4d5d-b36e-e9920de2e0cc"
tg-import 'azuread_group_member.user_env_role["sim1-fabrikam-tst-user"]'    "ee37a891-595b-4082-a432-c36d99bde618/member/b1748142-e0c5-4057-83d7-4fbe24e6f890"
tg-import 'azuread_group_member.user_env_role["sim1-fabrikam-tst-viewer"]'  "7a793658-19f2-43c7-9f3c-d21c00516fe0/member/dbb136dc-fb6e-46d8-83a3-4b9b8a462e3c"
# northwind groups → northwind users
tg-import 'azuread_group_member.user_env_role["sim1-northwind-dev-admin"]'  "325e9cfa-9322-416f-b4ec-3ad8fbebf660/member/48b4bac3-1b67-463e-9114-fa7a2c4d5114"
tg-import 'azuread_group_member.user_env_role["sim1-northwind-dev-user"]'   "f9614dd9-2594-4c25-b5ba-ee361b747b35/member/b4b2b88a-aad9-4235-a4de-3f679b9ef7d4"
tg-import 'azuread_group_member.user_env_role["sim1-northwind-dev-viewer"]' "c3e6ef73-6849-497b-b391-0d48a25fd042/member/4d8486e4-e9cb-4303-8446-711f07ad2e06"
tg-import 'azuread_group_member.user_env_role["sim1-northwind-prd-admin"]'  "f029ac7e-fe26-4f27-8056-e54026f84ea8/member/48b4bac3-1b67-463e-9114-fa7a2c4d5114"
tg-import 'azuread_group_member.user_env_role["sim1-northwind-prd-user"]'   "f0964ba0-712e-432d-824b-f4e0f58d20ff/member/b4b2b88a-aad9-4235-a4de-3f679b9ef7d4"
tg-import 'azuread_group_member.user_env_role["sim1-northwind-prd-viewer"]' "55980c5a-ff04-44c4-9a13-8609fac67f81/member/4d8486e4-e9cb-4303-8446-711f07ad2e06"
tg-import 'azuread_group_member.user_env_role["sim1-northwind-qa-admin"]'   "1df7c963-f4f1-4a17-a6ff-87c1e1fc09d4/member/48b4bac3-1b67-463e-9114-fa7a2c4d5114"
tg-import 'azuread_group_member.user_env_role["sim1-northwind-qa-user"]'    "d48d0010-285e-49ff-8e09-3e6a3afacb6f/member/b4b2b88a-aad9-4235-a4de-3f679b9ef7d4"
tg-import 'azuread_group_member.user_env_role["sim1-northwind-qa-viewer"]'  "7524c970-8200-426d-87af-87ef12975528/member/4d8486e4-e9cb-4303-8446-711f07ad2e06"
tg-import 'azuread_group_member.user_env_role["sim1-northwind-qa2-admin"]'  "64704eff-8538-49ca-9cb2-1e3f53e401de/member/48b4bac3-1b67-463e-9114-fa7a2c4d5114"
tg-import 'azuread_group_member.user_env_role["sim1-northwind-qa2-user"]'   "60a95217-7d07-4c50-9a39-eb736c4194b0/member/b4b2b88a-aad9-4235-a4de-3f679b9ef7d4"
tg-import 'azuread_group_member.user_env_role["sim1-northwind-qa2-viewer"]' "6ad35ba9-7af5-4017-9315-daa571984215/member/4d8486e4-e9cb-4303-8446-711f07ad2e06"
tg-import 'azuread_group_member.user_env_role["sim1-northwind-tst-admin"]'  "e4c95c70-44d4-4e41-9729-5bed1817ea04/member/48b4bac3-1b67-463e-9114-fa7a2c4d5114"
tg-import 'azuread_group_member.user_env_role["sim1-northwind-tst-user"]'   "9db48c3e-f118-407d-9e52-5fa587d5c229/member/b4b2b88a-aad9-4235-a4de-3f679b9ef7d4"
tg-import 'azuread_group_member.user_env_role["sim1-northwind-tst-viewer"]' "130c5e5a-7cfc-4786-93c8-7239af0a1805/member/4d8486e4-e9cb-4303-8446-711f07ad2e06"

Write-Host "`n=== APP ROLE ASSIGNMENTS (3) ===" -ForegroundColor Yellow
tg-import 'azuread_app_role_assignment.nxcloud_contoso["sim1-contoso-admin"]'  "10e1e6b0-94d0-40ed-ab96-15d0cd5bf450/appRoleAssignment/sSwiqjvrWESJ7Oy6GlkQHlwPi7bX23NIg0dWqKmGRjc"
tg-import 'azuread_app_role_assignment.nxcloud_contoso["sim1-contoso-user"]'   "10e1e6b0-94d0-40ed-ab96-15d0cd5bf450/appRoleAssignment/6T-FFB3w8UOBYvrRBUrXqJO0kew7L8lDrpSevZw7BKU"
tg-import 'azuread_app_role_assignment.nxcloud_contoso["sim1-contoso-viewer"]' "10e1e6b0-94d0-40ed-ab96-15d0cd5bf450/appRoleAssignment/OdWWe9YFc0mABVqHA_DC_TdTBMT-e0xBsInBxuRiV2M"

Write-Host "`n=== SUMMARY ===" -ForegroundColor Yellow
Write-Host "OK:      $ok" -ForegroundColor Green
Write-Host "Skipped: $skipped" -ForegroundColor DarkGray
Write-Host "Failed:  $($failed.Count)" -ForegroundColor $(if ($failed.Count -gt 0) { "Red" } else { "Green" })
if ($failed.Count -gt 0) {
    Write-Host "Failed resources:" -ForegroundColor Red
    $failed | ForEach-Object { Write-Host "  $_" -ForegroundColor Red }
}
Write-Host "=== DONE ===" -ForegroundColor Yellow
