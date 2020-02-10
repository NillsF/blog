$action = Get-AzActionGroup -Name "email_nills" -ResourceGroupName "Default-ActivityLogAlerts"
$act = New-AzActionGroup -ActionGroupId $action.Id
$crit = New-AzMetricAlertRuleV2Criteria -MetricName transactions -TimeAggregation Total -Operator GreaterThan -Threshold 1000

$staccs = Get-AzStorageAccount
foreach ($stacc in $staccs){
    $alertrulename = $stacc.StorageAccountName + " exceeded transactions" 
    Add-AzMetricAlertRuleV2 -ResourceGroupName $stacc.ResourceGroupName -Name $alertrulename -WindowSize 00:05:00 -ActionGroup $act `
    -TargetResourceId $stacc.Id -Frequency 00:05:00 -Condition $crit -severity 2
}
