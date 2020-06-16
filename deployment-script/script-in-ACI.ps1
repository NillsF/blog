Connect-AzAccount -Identity 
$ctx = New-AzStorageContext -StorageAccountName nfwestus2 -UseConnectedAccount
$queue = Get-AzStorageQueue –Name deployment-script –Context $ctx
$queueMessage = [Microsoft.Azure.Storage.Queue.CloudQueueMessage]::new("##Need to pass in output from NIC in here.##")
$queue.CloudQueue.AddMessageAsync($QueueMessage)