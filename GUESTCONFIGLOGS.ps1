
New-GuestConfigurationPolicy `
-ContentUri "https://shawninttestdiag.blob.core.windows.net/antimalwareaudit/Antimalware_Audit.zip?sp=r&st=2019-09-24T11:32:24Z&se=2020-03-01T20:32:24Z&spr=https&sv=2018-03-28&sig=Bpmh8nhPSrsqOQutXogAJJKdU5XwbfGNEW7geKE1zb4%3D&sr=b" `
-DisplayName "Antimalware Audit for Windows VMs" `
-Path 'C:\KB\DSC\Antimalware\Artifacts' `
-Platform 'Windows' `
-Description 'Audit to ensure antimalware is running on Windows VMs.' `
-Verbose
select-azsubscription -Subscription "TW-ITCORP-POCLAB"

Publish-GuestConfigurationPolicy -Path 'C:\KB\DSC\Antimalware\Artifacts'

