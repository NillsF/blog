# Setup couple of variables
$staccname = "nfadfkvread"
$staccname2 = "nfadfkvwrite"
$rgname = "kv-adf"
$location = "westus2"
$kvname = "kv-nf-adf-sas"
$keyVaultSpAppId = "cfa8b339-82a2-471a-a3c9-0fc0be7a4093"
$storageAccountKey = "key1"
$SASDefinitionName = "readFromAccount1"
$SASDefinitionName2 = "writeToAccount2"

# Login
Connect-AzAccount  

# Create all resources
Write-Output "Create all resources"

New-AzResourceGroup -Name $rgname -Location $location
$stacc = New-AzStorageAccount -ResourceGroupName $rgname -Location $location -Name $staccname -SkuName Standard_LRS
$stacc2 = New-AzStorageAccount -ResourceGroupName $rgname -Location $location -Name $staccname2 -SkuName Standard_LRS
$kv = New-AzKeyVault -VaultName $kvname -ResourceGroupName $rgname -Location $location

# Give KV permissions on Storage to rotate keys
Write-Output "Give KV permissions on Storage to rotate keys"

New-AzRoleAssignment -ApplicationId $keyVaultSpAppId -RoleDefinitionName 'Storage Account Key Operator Service Role' -Scope $stacc.Id
New-AzRoleAssignment -ApplicationId $keyVaultSpAppId -RoleDefinitionName 'Storage Account Key Operator Service Role' -Scope $stacc2.Id

# Give my user access to KV storage permissions
Write-Output "Give my user access to KV storage permissions"

$userId = (Get-AzContext).Account.Id
Set-AzKeyVaultAccessPolicy -VaultName $kvname -UserPrincipalName $userId -PermissionsToStorage get, list, delete, set, update, regeneratekey, getsas, listsas, deletesas, setsas, recover, backup, restore, purge

# Add storage accounts to key vault
$regenPeriod = [System.Timespan]::FromDays(2)
Write-Output "Sleeping 30 seconds to have role assignments propagate and catch up"
Start-Sleep -Seconds 30
Write-Output "Done sleeping. Add storage accounts to key vault"

Add-AzKeyVaultManagedStorageAccount -VaultName $kvname -AccountName $staccname -AccountResourceId $stacc.Id -ActiveKeyName $storageAccountKey -RegenerationPeriod $regenPeriod
Add-AzKeyVaultManagedStorageAccount -VaultName $kvname -AccountName $staccname2 -AccountResourceId $stacc2.Id -ActiveKeyName $storageAccountKey -RegenerationPeriod $regenPeriod

# Onboard first account with list/read permissions only
Write-Output "Onboard first account with list/read permissions only"

$storageContext = New-AzStorageContext -StorageAccountName $staccname -Protocol Https -StorageAccountKey Key1 
$start = [System.DateTime]::Now.AddDays(-1)
$end = [System.DateTime]::Now.AddMonths(1)

$sasToken = New-AzStorageAccountSasToken -Service blob -ResourceType Container,Object -Permission "rl" -Protocol HttpsOnly -StartTime $start -ExpiryTime $end -Context $storageContext

Set-AzKeyVaultManagedStorageSasDefinition -AccountName $staccname -VaultName $kvname `
-Name $SASDefinitionName -TemplateUri $sasToken -SasType 'account' -ValidityPeriod ([System.Timespan]::FromDays(1))




# Onboard second account with write/list permissions only
Write-Output "Onboard second account with list/read permissions only"

$storageContext = New-AzStorageContext -StorageAccountName $staccname2 -Protocol Https -StorageAccountKey Key1 
$start = [System.DateTime]::Now.AddDays(-1)
$end = [System.DateTime]::Now.AddMonths(1)

$sasToken = New-AzStorageAccountSasToken -Service blob -ResourceType Container,Object -Permission "wl" -Protocol HttpsOnly -StartTime $start -ExpiryTime $end -Context $storageContext

Set-AzKeyVaultManagedStorageSasDefinition -AccountName $staccname2 -VaultName $kvname `
-Name $SASDefinitionName2 -TemplateUri $sasToken -SasType 'account' -ValidityPeriod ([System.Timespan]::FromDays(1))

# Getting secrets to verify everything works
Write-Host "Getting secrets to verify things work."

$secret = Get-AzKeyVaultSecret -VaultName $kvname -Name "$staccname-$SASDefinitionName"
$secret.SecretValueText
$secret = Get-AzKeyVaultSecret -VaultName $kvname -Name "$staccname2-$SASDefinitionName2"
$secret.SecretValueText