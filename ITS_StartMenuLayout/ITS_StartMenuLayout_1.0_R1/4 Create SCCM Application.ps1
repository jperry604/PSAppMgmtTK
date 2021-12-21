#import-module "C:\Program Files (x86)\Microsoft Configuration Manager\AdminConsole\bin\ConfigurationManager.psd1"

import-module (join-path "$env:SMS_ADMIN_UI_PATH\..\" ConfigurationManager.psd1)
Set-Location DNV:
#https://www.powershellgallery.com/packages/Create-SCCMApplication/2.0/Content/Create-SCCMApplication.ps1


$displayName = Split-Path $PSScriptRoot -Leaf
$sections = $displayName.Split("_")
$publisher = $sections[0]
$app = $sections[1]
$version = $sections[2]
$revision = $sections[3]
$description = "Installs ${displayName}"
$SourceDirectory = Join-path $PSScriptRoot "ADTP"
$MaximumRuntimeMins = 60
$LogonRequirementType = "WhetherOrNotUserLoggedOn" #OnlyWhenUserLoggedOn, WhereOrNotUserLoggedOn, WhetherOrNotUserLoggedOn, OnlyWhenNoUserLoggedOn
$UserInteractionMode = "Hidden" #Normal Minimized Maximized Hidden

$installCmdLine = "powershell -executionpolicy bypass -file `"ServiceUIWrapper.ps1`"" 
$uninstallCmdLine = "powershell -executionpolicy bypass -file `"Deploy-Application.ps1`"  -DeploymentType Uninstall -DeployMode Silent"
$RepairCommand = "powershell -executionpolicy bypass -file `"Deploy-Application.ps1`"  -DeploymentType Repair -DeployMode Silent"


if (-not (Get-CMApplication -Name "$displayName")){
    #https://docs.microsoft.com/en-us/powershell/module/configurationmanager/new-cmapplication?view=sccm-ps
    New-CMApplication -Name "$displayName" -Description $description -AutoInstall $true -SoftwareVersion $version -Publisher $publisher -verbose

    #https://docs.microsoft.com/en-us/powershell/module/configurationmanager/add-cmscriptdeploymenttype?view=sccm-ps
    Add-CMScriptDeploymentType -ApplicationName "$displayName" -DeploymentTypeName "Install $displayName" -ContentLocation $SourceDirectory `
        -InstallCommand $installCmdLine -UninstallCommand $uninstallCmdLine -RepairCommand $RepairCommand `
        -ScriptLanguage PowerShell -ScriptFile (join-path $PSScriptRoot "InstallStateDetection.ps1") `
        -InstallationBehaviorType InstallForSystem -UserInteractionMode $UserInteractionMode -LogonRequirementType $LogonRequirementType -MaximumRuntimeMins $MaximumRuntimeMins -RebootBehavior BasedOnExitCode `
        -SlowNetworkDeploymentMode Download -Verbose

    start-CMContentDistribution -ApplicationName "$displayName" -DistributionPointGroupName "AppInstallersManaged-ALL" -Verbose
}else {
    Write-Host "$displayName is already an Application"
}



#
#New-CMApplicationDeployment -CollectionName “Deploy Google Chrome” -Name "$displayName" -DeployAction Install -DeployPurpose Available -UserNotification DisplayAll -AvailableDateTime (get-date) -TimeBaseOn LocalTime -Verbose





