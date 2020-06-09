#Script to populate parameters for ARM template deployment to configure VMs to send OS diagnostic event and IIS logs
#direct to the regional Event Hub

param(
        [parameter(Mandatory=$True,HelpMessage="Enter subscription name where the vms are deployed")]
        [string]$vmSubscriptionName, 
        
        [parameter(Mandatory=$True,HelpMessage="Enter resource group name for where the vms are deployed")]
        [string]$vmResourceGroupName,

        [parameter(Mandatory=$True,HelpMessage="Enter the path where the template file and script are located")]
        [string]$templateFilePath

)

#Verify Azure account has been connected
$credCheck = Read-Host "Have you connected and authenticated your Azure account (yes or no)?"

If ($credCheck -eq "yes" -or $credCheck -eq "Yes")
    {
        "Continuing with the script..."
    }
Else {
    "Please run Connect-AzAccount to authenticate to Azure before running this script..."
}

#Set the subscription context
Select-AzSubscription -Subscription $vmSubscriptionName | out-null


#Get a list of all running Windows VMs in the targeted resource group
"Getting a list of VMs in the specfied resource group..."
$vmList = (get-AzVM -ResourceGroupName $vmResourceGroupName -status).where{($_.PowerState -eq "VM running" -and $_.StorageProfile.OsDisk.OsType -eq "Windows")}

#Foreach vm in the vm list, run the ARM template to configure OS diagnostic logs to send to the specified regional event hub
$vmList.ForEach({ 
    Switch($_.location)
        {
            #Build the WTW DCID based on the Region
            {$_ -eq "eastus2"}      {$locID = "NA20"}
            {$_ -eq "eastus"}       {$locID = "NA20"}
            {$_ -eq "centralus"}    {$locID = "NA21"}
            {$_ -eq "canadaeast"}   {$locID = "NA24"}
            {$_ -eq "northeurope"}  {$locID = "EM21"}
            {$_ -eq "westeurope"}   {$locID = "EM20"}
            {$_ -eq "uksouth"}      {$locID = "EM22"}
            {$_ -eq "ukwest"}       {$locID = "EM23"}
            {$_ -eq "southeastasia"}{$locID = "AP20"}
            {$_ -eq "eastasia"}     {$locID = "AP21"}
        }

    #Centralized EventHub static variables
   $EventHubResourceGroupName = "SHAWN-POCLAB-DEV-RGRP"
   $EventHubNamespace = "ITCORP-" + $locID + "-EVENTHUBNS01T"
   $EventHubName = "general"
   $EventHubSharedAccessKeyName = "diagtest"
   $EventHubSubId = "0f00bf6c-29d8-4166-a1a3-9162a4a0beb3"

 #VM variables
   $resourceGroupName = $_.ResourceGroupName
   $vmName = $_.Name
   $vmLocation = $_.Location

   #Central storage account static variables 
   $storageAccountSubId = "0f00bf6c-29d8-4166-a1a3-9162a4a0beb3"
   $storageAccountName = $locID + "shawnsiemdiaglogs"
   $storageAccountResourceGroup = "shawnsiemdiaglogs"

    
    "Executing ARM template deployment on $($_.Name)"
    New-AzResourceGroupDeployment `
        -TemplateFile $templateFilePath `
        -ResourceGroupName $resourceGroupName `
        -storageAccountName $storageAccountName `
        -vmName $vmName `
        -vmLocation $vmLocation `
        -eventHubResourceGroupName $eventHubResourceGroupName `
        -EventHubNameSpace $EventHubNamespace `
        -EventHubName $EventHubName `
        -SharedAccessKeyName $EventHubSharedAccessKeyName `
        -storageAccountResourceGroup $storageAccountResourceGroup `
        -storageAccountSubId $storageAccountSubId `
        -eventHubSubId $EventHubSubId `
        -Mode Incremental `
        -Verbose
    
})
