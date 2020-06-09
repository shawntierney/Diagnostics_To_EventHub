#Create SPN specifically to delete the diagnostics table and IIS blob from the dedicated storage 
#account in each subscription 

$automationAccountRG = "accounttest"
$automationAccountName = "accounttest"

Select-AzSubscription -Subscription "TW-ITCORP-POCLAB"
$connectionName = "shawndiagnosticsdelete"
Try
{
    # Get the connection "AzureRunAsConnection "
    $servicePrincipalConnection = Get-AzAutomationConnection `
    -Name $connectionName `
    -AutomationAccountName $automationAccountName `
    -ResourceGroupName $automationAccountRG         

    "Logging in to Azure..."
    Connect-AzAccount -ServicePrincipal -Tenant $servicePrincipalConnection.FieldDefinitionValues.TenantId -ApplicationId $servicePrincipalConnection.FieldDefinitionValues.ApplicationId -CertificateThumbprint $servicePrincipalConnection.FieldDefinitionValues.CertificateThumbprint
}
Catch {
    If (!$servicePrincipalConnection)
    {
        $ErrorMessage = "Connection $connectionName not found."
        throw $ErrorMessage
    } 
    Else{
        Write-Error -Message $_.Exception
        throw $_.Exception
    }
}

#Get the subscription list
$subscriptions = Get-AzSubscription 

#For testing - change $subs to $subscriptions for production usage
$subs = $subscriptions.Where({$_.Name -eq "TW-ITCORP-POCLAB" -or $_.Name -eq "WTW-ITCORP-DEV"}) 

$subs.ForEach({
    #Set context to the correct subscription
    "Getting list of subscriptions..."
    Select-AzSubscription -Subscription $subs.Name $_.Name | Out-Null

    #Get the storage account 
    "Getting diagnostic logs storage account for $($subs.Name) subscription..."
    $storageAccount = (Get-AzStorageAccount).Where({$_.StorageAccountName -like "*siemdiaglogs"})

    #Get the storage account key
    "Retrieving storage account key for $($_storageAccount.storageAccountName)..."
    $storageAccountKey = `
        (Get-AzStorageAccountKey `
        -ResourceGroupName $storageAccount.ResourceGroupName `
        -Name $storageAccount.storageAccountName).Value[0]

    #Create the storage account context
    $storageAccountContext = New-AzStorageContext -StorageAccountName $storageAccount.storageAccountName -StorageAccountKey $storageAccountKey
    
    #Query the existence of the WADWindowsEventLogsTable
    $wadDiagnosticLogTables = Get-AzStorageTable –Context $storageAccountContext
    $wadEventsTable = $wadDiagnosticLogTables.Where({$_.Name -eq "WADWindowsEventLogsTable"})

    #Query the existence of the iislogs blob
    $wadStorageContainers = Get-AzStorageContainer -Context $storageAccountContext
    $iisLogs = $wadStorageContainers.Where({$_.Name -eq "iislogs"})

    "Checking to see if WADWindowsEventLogsTable exist..."

    If ($wadEventsTable)
        {
            "$($wadEventsTable.Name) is present on $($storageAccount.storageAccountName)"

            "Removing the $($wadEventsTable.Name) table"  

            #Remove the WADWindowsEventLogsTable
            Remove-AzStorageTable -Name $wadEventsTable.Name -Context $storageAccountContext -Force

            #Define $confirmDelete variable for deletion check
            $confirmDelete = (Get-AzStorageTable –Context $storageAccountContext).Where({$_.Name -eq "WADWindowsEventLogsTable"})

        If (!$confirmDelete)
            {
                " $($wadEventsTable.Name) has successfully been deleted from $($storageAccount.storageAccountName)."
            }
        Else {
                "Deletion of $($wadEventsTable.Name) on $($storageAccount.storageAccountName) has failed."
        }
        }

    Else {
            "The WADWindowsEventLogsTable table does not exist for $($storageAccount.storageAccountName) ."
    }

    If ($iisLogs)
    {
        "$($iisLogs.Name) is present on $($storageAccount.storageAccountName)"

        "Removing the $($iisLogs.Name) blob"  

        #Remove the iislogs blob
        Remove-AzStorageContainer -Name $iisLogs.Name -Context $storageAccountContext -Force

        #Define $confirmDelete variable for deletion check
        $confirmDelete = (Get-AzStorageTable –Context $storageAccountContext).Where({$_.Name -eq "WADWindowsEventLogsTable"})

        If (!$confirmDelete)
            {
                " $($iisLogs.Name) has successfully been deleted from $($storageAccount.storageAccountName)."
            }
        Else {
                "Deletion of $($iisLogs.Name) on $($storageAccount.storageAccountName) has failed."
        }
    }

Else {
        "The iislogs blob does not exist for $($storageAccount.storageAccountName) ."
}
})




