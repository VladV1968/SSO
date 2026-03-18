# ==============================================================================
# STATE IMPORT SCRIPT — sim1 tenant
# Imports all Azure AD resources from sim1 into Terraform state.
# Run from: C:\Tools\Gitlab\sre\private-cloud\core-infra-iac\SSO\live\region-a\ad-tenant
# Requires: AZUREAD_TENANT_ID, AZUREAD_CLIENT_ID, AZUREAD_CLIENT_SECRET env vars set
# ==============================================================================

$ErrorActionPreference = "Continue"
$failed = @()
$succeeded = @()

function Import-TF {
    param($address, $id)
    Write-Host "  Importing: $address" -ForegroundColor Cyan
    # Use array-based invocation to avoid PowerShell quoting issues with brackets
    $output = & terragrunt @('import', $address, $id) 2>&1
    if ($LASTEXITCODE -ne 0) {
        $outputStr = $output -join ' '
        if ($outputStr -match 'already exists in Terraform state') {
            Write-Host "  SKIP (already in state)" -ForegroundColor DarkGray
            $script:succeeded += "$address (already)"
        } else {
            Write-Host "  FAILED: $address" -ForegroundColor Red
            Write-Host "  $(($output | Select-Object -Last 5) -join ' ')" -ForegroundColor DarkRed
            $script:failed += "$address => $id"
        }
    } else {
        Write-Host "  OK" -ForegroundColor Green
        $script:succeeded += "$address"
    }
}

# ==============================================================================
# STEP 1: NX CLOUD CORE RESOURCES
# ==============================================================================
Write-Host ""
Write-Host "=== STEP 1: NX CLOUD CORE RESOURCES ===" -ForegroundColor Yellow

Import-TF `
    'azuread_application.nxcloud["sim1"]' `
    "/applications/e8687e54-6adb-4959-9db1-305b334ee145"

Import-TF `
    'azuread_service_principal.nxcloud["sim1"]' `
    "10e1e6b0-94d0-40ed-ab96-15d0cd5bf450"

Import-TF `
    'azuread_claims_mapping_policy.nxcloud_saml["sim1"]' `
    "be2ce858-a4e6-43f7-8560-ef102ee946b6"

Import-TF `
    'azuread_service_principal_claims_mapping_policy_assignment.nxcloud_saml["sim1"]' `
    "10e1e6b0-94d0-40ed-ab96-15d0cd5bf450/claimsMappingPolicy/be2ce858-a4e6-43f7-8560-ef102ee946b6"

# ==============================================================================
# STEP 2: SECURITY GROUPS (45 total)
# ==============================================================================
Write-Host ""
Write-Host "=== STEP 2: SECURITY GROUPS ===" -ForegroundColor Yellow

$groups = @{
    # Contoso
    "sim1-contoso-dev-admin"    = "c44b348f-2bd2-4992-bf09-48b7a504c822"
    "sim1-contoso-dev-user"     = "9f92c56b-2419-4001-b65c-19ca6ffbc422"
    "sim1-contoso-dev-viewer"   = "5b49d3c5-7b2e-45e2-8fd6-0d8d49fa0d11"
    "sim1-contoso-prd-admin"    = "ac391fda-e490-40ac-92ef-d8c908747671"
    "sim1-contoso-prd-user"     = "6e25067e-f1c9-41d6-ae3a-6b661dbb71ad"
    "sim1-contoso-prd-viewer"   = "15f39352-f836-44d4-a8ff-8a1a84ec43f9"
    "sim1-contoso-qa-admin"     = "9ed66a80-184e-4e0f-bda6-ef0b82a2911e"
    "sim1-contoso-qa-user"      = "719a4777-b67c-4622-bea6-637d99a65cd6"
    "sim1-contoso-qa-viewer"    = "6a8fc338-fdec-4167-8084-8540f8552f2b"
    "sim1-contoso-qa2-admin"    = "6253fde5-916b-4fe6-aab3-6ec7781f6fb9"
    "sim1-contoso-qa2-user"     = "eb00cd3b-f098-449e-8649-ef7bece61d74"
    "sim1-contoso-qa2-viewer"   = "d267cae7-9968-4f2d-a592-6a68ef7c68fc"
    "sim1-contoso-tst-admin"    = "3c6ed00e-43cc-4cc7-a299-fe497b51e8a6"
    "sim1-contoso-tst-user"     = "df416e17-c1bc-4f20-a68e-6de6e9218b92"
    "sim1-contoso-tst-viewer"   = "a07dbdb4-befd-4351-a66a-2c718fa1b213"
    # Fabrikam
    "sim1-fabrikam-dev-admin"   = "15c05556-9624-4536-865d-3bb03cbf68b0"
    "sim1-fabrikam-dev-user"    = "c201ca87-9214-4f36-b9a3-88b32ad3e7bf"
    "sim1-fabrikam-dev-viewer"  = "d8b7de74-791a-4535-b8d0-684106325113"
    "sim1-fabrikam-prd-admin"   = "e531bb41-0e43-4bc2-aaaf-1048f5fc99ef"
    "sim1-fabrikam-prd-user"    = "11e0fdbe-471d-45b2-9f16-15f0b652fb6e"
    "sim1-fabrikam-prd-viewer"  = "10d28d85-4ff9-4cee-9be5-63bb04df07cc"
    "sim1-fabrikam-qa-admin"    = "54c1f487-ab2e-4d1d-ab22-1597d7c4a150"
    "sim1-fabrikam-qa-user"     = "da70bf48-84a0-4498-a6e0-bace9f5e347a"
    "sim1-fabrikam-qa-viewer"   = "e7be92c9-11c8-47f4-be06-8ec8ed54fcda"
    "sim1-fabrikam-qa2-admin"   = "8a128ba8-e0bc-4acb-a558-6f37801c8212"
    "sim1-fabrikam-qa2-user"    = "3de6935e-640e-47c7-96eb-62b3c197475f"
    "sim1-fabrikam-qa2-viewer"  = "4600ced9-3265-4157-9c79-6a9b7ec28e35"
    "sim1-fabrikam-tst-admin"   = "dd142443-8fc3-439a-a352-4799e3fda9a2"
    "sim1-fabrikam-tst-user"    = "ee37a891-595b-4082-a432-c36d99bde618"
    "sim1-fabrikam-tst-viewer"  = "7a793658-19f2-43c7-9f3c-d21c00516fe0"
    # Northwind
    "sim1-northwind-dev-admin"  = "325e9cfa-9322-416f-b4ec-3ad8fbebf660"
    "sim1-northwind-dev-user"   = "f9614dd9-2594-4c25-b5ba-ee361b747b35"
    "sim1-northwind-dev-viewer" = "c3e6ef73-6849-497b-b391-0d48a25fd042"
    "sim1-northwind-prd-admin"  = "f029ac7e-fe26-4f27-8056-e54026f84ea8"
    "sim1-northwind-prd-user"   = "f0964ba0-712e-432d-824b-f4e0f58d20ff"
    "sim1-northwind-prd-viewer" = "55980c5a-ff04-44c4-9a13-8609fac67f81"
    "sim1-northwind-qa-admin"   = "1df7c963-f4f1-4a17-a6ff-87c1e1fc09d4"
    "sim1-northwind-qa-user"    = "d48d0010-285e-49ff-8e09-3e6a3afacb6f"
    "sim1-northwind-qa-viewer"  = "7524c970-8200-426d-87af-87ef12975528"
    "sim1-northwind-qa2-admin"  = "64704eff-8538-49ca-9cb2-1e3f53e401de"
    "sim1-northwind-qa2-user"   = "60a95217-7d07-4c50-9a39-eb736c4194b0"
    "sim1-northwind-qa2-viewer" = "6ad35ba9-7af5-4017-9315-daa571984215"
    "sim1-northwind-tst-admin"  = "e4c95c70-44d4-4e41-9729-5bed1817ea04"
    "sim1-northwind-tst-user"   = "9db48c3e-f118-407d-9e52-5fa587d5c229"
    "sim1-northwind-tst-viewer" = "130c5e5a-7cfc-4786-93c8-7239af0a1805"
}

foreach ($key in ($groups.Keys | Sort-Object)) {
    Import-TF "azuread_group.org_env_role[`"$key`"]" $groups[$key]
}

# ==============================================================================
# STEP 3: USERS (9 total)
# ==============================================================================
Write-Host ""
Write-Host "=== STEP 3: USERS ===" -ForegroundColor Yellow

Import-TF 'azuread_user.org_role["sim1-contoso-admin"]'   "aa222cb1-eb3b-4458-89ec-ecba1a59101e"
Import-TF 'azuread_user.org_role["sim1-contoso-user"]'    "14853fe9-f01d-43f1-8162-fad1054ad7a8"
Import-TF 'azuread_user.org_role["sim1-contoso-viewer"]'  "7b96d539-05d6-4973-8005-5a8703f0c2fd"
Import-TF 'azuread_user.org_role["sim1-fabrikam-admin"]'  "924f1703-ba0b-4d5d-b36e-e9920de2e0cc"
Import-TF 'azuread_user.org_role["sim1-fabrikam-user"]'   "b1748142-e0c5-4057-83d7-4fbe24e6f890"
Import-TF 'azuread_user.org_role["sim1-fabrikam-viewer"]' "dbb136dc-fb6e-46d8-83a3-4b9b8a462e3c"
Import-TF 'azuread_user.org_role["sim1-northwind-admin"]'  "48b4bac3-1b67-463e-9114-fa7a2c4d5114"
Import-TF 'azuread_user.org_role["sim1-northwind-user"]'   "b4b2b88a-aad9-4235-a4de-3f679b9ef7d4"
Import-TF 'azuread_user.org_role["sim1-northwind-viewer"]' "4d8486e4-e9cb-4303-8446-711f07ad2e06"

# ==============================================================================
# STEP 4: GROUP MEMBERSHIPS (45 total)
# Format: {group_id}/member/{user_id}
# Mapping: group key sim1-{company}-{env}-{role} -> user key sim1-{company}-{role}
# ==============================================================================
Write-Host ""
Write-Host "=== STEP 4: GROUP MEMBERSHIPS ===" -ForegroundColor Yellow

$users = @{
    "sim1-contoso-admin"    = "aa222cb1-eb3b-4458-89ec-ecba1a59101e"
    "sim1-contoso-user"     = "14853fe9-f01d-43f1-8162-fad1054ad7a8"
    "sim1-contoso-viewer"   = "7b96d539-05d6-4973-8005-5a8703f0c2fd"
    "sim1-fabrikam-admin"   = "924f1703-ba0b-4d5d-b36e-e9920de2e0cc"
    "sim1-fabrikam-user"    = "b1748142-e0c5-4057-83d7-4fbe24e6f890"
    "sim1-fabrikam-viewer"  = "dbb136dc-fb6e-46d8-83a3-4b9b8a462e3c"
    "sim1-northwind-admin"  = "48b4bac3-1b67-463e-9114-fa7a2c4d5114"
    "sim1-northwind-user"   = "b4b2b88a-aad9-4235-a4de-3f679b9ef7d4"
    "sim1-northwind-viewer" = "4d8486e4-e9cb-4303-8446-711f07ad2e06"
}

foreach ($groupKey in ($groups.Keys | Sort-Object)) {
    # Derive user key: strip env component
    # e.g. "sim1-contoso-dev-admin" -> "sim1-contoso-admin"
    if ($groupKey -match '^(sim\d+)-(contoso|fabrikam|northwind)-(dev|tst|qa|qa2|prd)-(admin|user|viewer)$') {
        $userKey = "$($Matches[1])-$($Matches[2])-$($Matches[4])"
        $groupId = $groups[$groupKey]
        $userId  = $users[$userKey]
        Import-TF "azuread_group_member.user_env_role[`"$groupKey`"]" "$groupId/member/$userId"
    } else {
        Write-Host "  SKIP (no match): $groupKey" -ForegroundColor DarkYellow
    }
}

# ==============================================================================
# STEP 5: APP ROLE ASSIGNMENTS (3 contoso users)
# Format: {service_principal_id}/appRoleAssignment/{assignment_id}
# SP object ID: 10e1e6b0-94d0-40ed-ab96-15d0cd5bf450
# ==============================================================================
Write-Host ""
Write-Host "=== STEP 5: APP ROLE ASSIGNMENTS ===" -ForegroundColor Yellow

Import-TF `
    'azuread_app_role_assignment.nxcloud_contoso["sim1-contoso-admin"]' `
    "10e1e6b0-94d0-40ed-ab96-15d0cd5bf450/appRoleAssignment/sSwiqjvrWESJ7Oy6GlkQHlwPi7bX23NIg0dWqKmGRjc"

Import-TF `
    'azuread_app_role_assignment.nxcloud_contoso["sim1-contoso-user"]' `
    "10e1e6b0-94d0-40ed-ab96-15d0cd5bf450/appRoleAssignment/6T-FFB3w8UOBYvrRBUrXqJO0kew7L8lDrpSevZw7BKU"

Import-TF `
    'azuread_app_role_assignment.nxcloud_contoso["sim1-contoso-viewer"]' `
    "10e1e6b0-94d0-40ed-ab96-15d0cd5bf450/appRoleAssignment/OdWWe9YFc0mABVqHA_DC_TdTBMT-e0xBsInBxuRiV2M"

# ==============================================================================
# SUMMARY
# ==============================================================================
Write-Host ""
Write-Host "=== IMPORT SUMMARY ===" -ForegroundColor Yellow
Write-Host "Succeeded: $($succeeded.Count)" -ForegroundColor Green
Write-Host "Failed:    $($failed.Count)" -ForegroundColor $(if ($failed.Count -gt 0) { "Red" } else { "Green" })
if ($failed.Count -gt 0) {
    Write-Host ""
    Write-Host "Failed resources:" -ForegroundColor Red
    foreach ($f in $failed) { Write-Host "  $f" -ForegroundColor Red }
}
Write-Host ""
Write-Host "=== DONE ===" -ForegroundColor Yellow
