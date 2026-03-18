Set-Location "C:\Tools\Gitlab\sre\private-cloud\core-infra-iac\SSO\live\region-a\ad-tenant"

# ==============================================================================
# Step 1: Remove all resources with wrong NxDev IDs from Terraform state
# ==============================================================================
Write-Host "=== STEP 1: Removing resources with wrong NxDev IDs ==="

$toRemove = @(
    'azuread_application.nxcloud["sim1"]',
    'azuread_service_principal.nxcloud["sim1"]',
    'azuread_claims_mapping_policy.nxcloud_saml["sim1"]',
    'azuread_service_principal_claims_mapping_policy_assignment.nxcloud_saml["sim1"]',
    'azuread_group.org_env_role["sim1-contoso-dev-admin"]',
    'azuread_group.org_env_role["sim1-contoso-dev-user"]',
    'azuread_group.org_env_role["sim1-contoso-dev-viewer"]',
    'azuread_group.org_env_role["sim1-contoso-prd-admin"]',
    'azuread_group.org_env_role["sim1-contoso-prd-user"]',
    'azuread_group.org_env_role["sim1-contoso-prd-viewer"]',
    'azuread_group.org_env_role["sim1-contoso-qa-admin"]',
    'azuread_group.org_env_role["sim1-contoso-qa-user"]',
    'azuread_group.org_env_role["sim1-contoso-qa-viewer"]',
    'azuread_group.org_env_role["sim1-contoso-qa2-admin"]',
    'azuread_group.org_env_role["sim1-contoso-qa2-user"]',
    'azuread_group.org_env_role["sim1-contoso-qa2-viewer"]',
    'azuread_group.org_env_role["sim1-contoso-tst-admin"]',
    'azuread_group.org_env_role["sim1-contoso-tst-user"]',
    'azuread_group.org_env_role["sim1-contoso-tst-viewer"]',
    'azuread_group.org_env_role["sim1-fabrikam-dev-admin"]',
    'azuread_group.org_env_role["sim1-fabrikam-dev-user"]',
    'azuread_group.org_env_role["sim1-fabrikam-dev-viewer"]',
    'azuread_group.org_env_role["sim1-fabrikam-prd-admin"]',
    'azuread_group.org_env_role["sim1-fabrikam-prd-user"]',
    'azuread_group.org_env_role["sim1-fabrikam-prd-viewer"]',
    'azuread_group.org_env_role["sim1-fabrikam-qa-admin"]',
    'azuread_group.org_env_role["sim1-fabrikam-qa-user"]',
    'azuread_group.org_env_role["sim1-fabrikam-qa-viewer"]',
    'azuread_group.org_env_role["sim1-fabrikam-qa2-admin"]',
    'azuread_group.org_env_role["sim1-fabrikam-qa2-user"]',
    'azuread_group.org_env_role["sim1-fabrikam-qa2-viewer"]',
    'azuread_group.org_env_role["sim1-fabrikam-tst-admin"]',
    'azuread_group.org_env_role["sim1-fabrikam-tst-user"]',
    'azuread_group.org_env_role["sim1-fabrikam-tst-viewer"]',
    'azuread_group.org_env_role["sim1-northwind-dev-admin"]',
    'azuread_group.org_env_role["sim1-northwind-dev-user"]',
    'azuread_group.org_env_role["sim1-northwind-dev-viewer"]',
    'azuread_group.org_env_role["sim1-northwind-prd-admin"]',
    'azuread_group.org_env_role["sim1-northwind-prd-user"]',
    'azuread_group.org_env_role["sim1-northwind-prd-viewer"]',
    'azuread_group.org_env_role["sim1-northwind-qa-admin"]',
    'azuread_group.org_env_role["sim1-northwind-qa-user"]',
    'azuread_group.org_env_role["sim1-northwind-qa-viewer"]',
    'azuread_group.org_env_role["sim1-northwind-qa2-admin"]',
    'azuread_group.org_env_role["sim1-northwind-qa2-user"]',
    'azuread_group.org_env_role["sim1-northwind-qa2-viewer"]',
    'azuread_group.org_env_role["sim1-northwind-tst-admin"]',
    'azuread_group.org_env_role["sim1-northwind-tst-user"]',
    'azuread_group.org_env_role["sim1-northwind-tst-viewer"]'
)

foreach ($r in $toRemove) {
    $result = & terragrunt state rm $r 2>&1
    if ($LASTEXITCODE -eq 0) {
        Write-Host "  Removed: $r"
    } else {
        Write-Host "  Skipped (not in state): $r"
    }
}

Write-Host ""
Write-Host "=== STEP 2: Importing correct sim1 resources ==="

# nxcloud application (ID format: /applications/{object_id})
Write-Host "Importing nxcloud application..."
& terragrunt import 'azuread_application.nxcloud["sim1"]' '/applications/e8687e54-6adb-4959-9db1-305b334ee145' 2>&1 | Where-Object {$_ -match 'Import|Error'} | Select-Object -Last 3

# nxcloud service principal
Write-Host "Importing nxcloud service principal..."
& terragrunt import 'azuread_service_principal.nxcloud["sim1"]' '10e1e6b0-94d0-40ed-ab96-15d0cd5bf450' 2>&1 | Where-Object {$_ -match 'Import|Error'} | Select-Object -Last 3

# claims mapping policy
Write-Host "Importing claims mapping policy..."
& terragrunt import 'azuread_claims_mapping_policy.nxcloud_saml["sim1"]' 'be2ce858-a4e6-43f7-8560-ef102ee946b6' 2>&1 | Where-Object {$_ -match 'Import|Error'} | Select-Object -Last 3

# claims mapping policy assignment
Write-Host "Importing claims mapping policy assignment..."
& terragrunt import 'azuread_service_principal_claims_mapping_policy_assignment.nxcloud_saml["sim1"]' '10e1e6b0-94d0-40ed-ab96-15d0cd5bf450/claimsMappingPolicy/be2ce858-a4e6-43f7-8560-ef102ee946b6' 2>&1 | Where-Object {$_ -match 'Import|Error'} | Select-Object -Last 3

Write-Host ""
Write-Host "=== STEP 3: Importing sim1 groups ==="

# Group mapping: terraform-key => sim1-object-id
# Key format: sim1-{company}-{env}-{role}
# Group display format: sg-sim1-{cc}-{env}-{role}
$groups = @{
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

foreach ($key in $groups.Keys) {
    $id = $groups[$key]
    $addr = "azuread_group.org_env_role[`"$key`"]"
    Write-Host "  Importing group $key -> $id"
    & terragrunt import $addr $id 2>&1 | Where-Object {$_ -match 'Import|Error|successful'} | Select-Object -Last 2
}

Write-Host ""
Write-Host "=== State repair complete ==="
Write-Host "Remaining operations (users, group members, app role assignments)"
Write-Host "will be handled by the next apply with correct auth."
