#import-module "C:\Program Files (x86)\Microsoft Configuration Manager\AdminConsole\bin\ConfigurationManager.psd1"
[CmdletBinding()]
Param (
	[Parameter(Mandatory=$true)]
	[string]$PathToApp,
    [Parameter(Mandatory=$true)]
	[string]$PathToAppPackage,
    [Parameter(Mandatory=$false)]
    [int]$RefreshType =2, ## 6 = Incremental and Scheduled Updates             # 4 = Incremental Updates Only             # 2 = Scheduled Updates only             # 1 = Manual Update only 
    [Parameter(Mandatory=$false)]
    [Boolean]$AddOtherVersionsDependencies=$false
)
import-module (join-path "$env:SMS_ADMIN_UI_PATH\..\" ConfigurationManager.psd1)

$RegPSAppMgmtTKKey = "HKLM:\Software\ITS\PSAppMgmtTK"
$RegPSAppMgmtTKValue = "BaseDirectory"
$BaseDirectory = Get-ItemPropertyValue -path $RegPSAppMgmtTKKey $RegPSAppMgmtTKValue

push-location
Set-Location "C:\"
$GeneralSettings = Get-Content -Path (join-path $BaseDirectory "_ComputerAppMgmt\Generalsettings.json") | ConvertFrom-Json
$AppSettings = Get-Content -Path (join-path $PathToApp AppSettings.json) | ConvertFrom-Json
$VersionedAppSettings = Get-Content -Path (join-path $PathToAppPackage VersionedAppSettings.json) | ConvertFrom-Json
pop-location


$displayName = Split-Path $PathToAppPackage -Leaf
$sections = $displayName.Split("_")
$publisher = $sections[0]
$app = $sections[1]
$version = $sections[2]
$revision = $sections[3]


$description = "Installs ${displayName}"
$SourceDirectory = Join-path $PathToAppPackage "ADTP"


if (get-item (join-path $SourceDirectory ".git" ) -ea SilentlyContinue){
    write-host "Git directory detected. Creating copy to remove git files from"
    $SourceDirectoryPruned = Join-Path $PathToAppPackage "ADTP-Pruned"
    robocopy.exe "$SourceDirectory" "$SourceDirectoryPruned" /XD ".git" /E /Purge /R:0 /W:1
    if ( $lastexitcode -ge 8) { #robocopy exit code 8 or above is error https://ss64.com/nt/robocopy-exit.html
        Write-Log -Message "Error: Failed to copy files from ${src} to ${dst}    Exited: $lastexitcode" -ErrorAction 'Continue'
        throw "Failed to copy files from $(${src}) to $(${dst}) $lastexitcode"
    } else {
        Write-Log -Message "Successfully robocopied files to $src" -ErrorAction 'Continue'
    }
    $SourceDirectory = $SourceDirectoryPruned
}


$InstallCmdLine    = $VersionedAppSettings.MECM.InstallCmdLine 
$UninstallCmdLine  = $VersionedAppSettings.MECM.UninstallCmdLine 
$RepairCommandLine = $VersionedAppSettings.MECM.RepairCommandLine

foreach($server in $GeneralSettings.MECM.Servers){
    #Enter MECM Console
    if($null -eq (Get-PSDrive -Name $server.SiteCode -PSProvider CMSite -ErrorAction SilentlyContinue)) {
        New-PSDrive -name $server.SiteCode -psprovider CMSite  -Root $server.FQDN -Scope Script
    }
    push-location
    Set-Location "$($server.SiteCode):\"


    $CMAPP = Get-CMApplication -Name "$displayName" -ea SilentlyContinue
    $CMAPPType = Get-CMDeploymentType -ApplicationName "$displayName"
    if (-not $CMAPP){
        #https://docs.microsoft.com/en-us/powershell/module/configurationmanager/new-cmapplication?view=sccm-ps
        $CMAPP = New-CMApplication -Name "$displayName" -Description $description -AutoInstall $true -SoftwareVersion $version -Publisher $publisher -IconLocationFile (Join-path $PathToAppPackage "MECM_ICON.ico") -verbose
        $ret = Move-CMObject -FolderPath ".\Application\PSAppMgmtTK" -InputObject $CMAPP
    }else {
        Write-Host "$displayName is already an Application"
    }
    $CMAPPType = Get-CMDeploymentType -InputObject $CMAPP
    

    

    if(-not $CMAPPType){
        #https://docs.microsoft.com/en-us/powershell/module/configurationmanager/add-cmscriptdeploymenttype?view=sccm-ps
        $CMAPPType=Add-CMScriptDeploymentType -ApplicationName "$displayName" -DeploymentTypeName "PSAppMGmtTK $displayName" -ContentLocation $SourceDirectory `
            -InstallCommand $installCmdLine -UninstallCommand $uninstallCmdLine -RepairCommand $RepairCommandLine `
            -ScriptLanguage PowerShell -ScriptFile (join-path $PathToAppPackage "InstallStateDetection.ps1") `
            -InstallationBehaviorType InstallForSystem -UserInteractionMode $VersionedAppSettings.MECM.UserInteractionMode -LogonRequirementType $VersionedAppSettings.MECM.LogonRequirementType -MaximumRuntimeMins $VersionedAppSettings.MECM.MaximumRuntimeMins -RebootBehavior $VersionedAppSettings.MECM.RebootBehavior `
            -SlowNetworkDeploymentMode Download -Verbose
    }
    
    #supersede existing prd deployment
    
    if(-not $CMAPPType){
        $CMAPPType = Get-CMDeploymentType -ApplicationName "$displayName"
    }
    $ExistingSupersendence = Get-CMDeploymentTypeSupersedence -inputObject $CMAPPType
    foreach( $package in $AppSettings.ProductionPackages){
        $CMAPPTypeOld = Get-CMDeploymentType -ApplicationName $package
        if(-not($CMAPPTypeOld.contentID -in $ExistingSupersendence.contentID)){
            write-host "Setting Supersedence on: $package"
            $ret = Add-CMDeploymentTypeSupersedence -SupersedingDeploymentType $CMAPPType -SupersededDeploymentType $CMAPPTypeOld -IsUninstall $VersionedAppSettings.MECM.UninstallOldVersionFirst
            $CMAPPType = Get-CMDeploymentType -ApplicationName "$displayName" # Avoiding error - Object reference not set to an instance of an object.
        }
    }
    $ExistingSupersendence = Get-CMDeploymentTypeSupersedence -inputObject $CMAPPType
    foreach( $package in $AppSettings.EarlyAdopterPackages){
        $CMAPPTypeOld = Get-CMDeploymentType -ApplicationName $package
        if(-not($CMAPPTypeOld.contentID -in $ExistingSupersendence.contentID)){
            write-host "Setting Supersedence on: $package"
            $ret = Add-CMDeploymentTypeSupersedence -SupersedingDeploymentType $CMAPPType -SupersededDeploymentType $CMAPPTypeOld -IsUninstall $VersionedAppSettings.MECM.UninstallOldVersionFirst
        }
    }



    if(-not ($CMAPP.PackageID)){
        $CMAPP = Get-CMApplication -Name "$displayName" -ea SilentlyContinue
    }

    if ($AddOtherVersionsDependencies){
        write-host "Todo - Add depenedencies found in other versions." -ForegroundColor "Magenta"
        foreach($previousproductionPackageStr in $AppSettings.ProductionPackages){
            if ($previousproductionPackageStr -eq "$CMAPPName"){continue}

            $CMAPPPrevious = Get-CMApplication -Name "$previousproductionPackageStr" -ea SilentlyContinue
            $CMAPPTypePrevious = Get-CMDeploymentType -InputObject $CMAPPPrevious
            $DependancyGroupsPrevious = Get-CMDeploymentTypeDependencyGroup -InputObject $CMAPPTypePrevious
            foreach($DependancyGroupPrevious in $DependancyGroupsPrevious){
                if($CMAPPTypePrevious.ModelName -eq $DependancyGroupPrevious.ParentDeploymentTypeModelName){continue}
                Get-CMDeploymentTypeDependency -InputObject $DependancyGroupPrevious
                $Dependency = Get-CMDeploymentTypeDependency -InputObject $dependancyGRP[0]
            }
          
            

            Get-CMDeploymentType -ApplicationName MyApp | New-CMDeploymentTypeDependencyGroup -GroupName MyGroup | Add-CMDeploymentTypeDependency -DeploymentTypeDependency (Get-CMDeploymentType -ApplicationName MyChildApp) -IsAutoInstall $true


        }
    }
        

    foreach( $DPG in $AppSettings.MECM.DistributionPointGroupsTesting){
        $DPG_obj = Get-CMDistributionPointGroup -Name $DPG
        if(-not $DPG_obj){
            $DPG_obj = New-CMDistributionPointGroup -Name $DPG
        }
        #Get-CMContentDistribution -ApplicationName $displayName -DistributionPointGroupName $DPG -Verbose
        write-host "Distributing `'$displayName`' to DPG: $DPG"
        write-host "Todo - find way to check that's it's not already distributed to the DP Group." -ForegroundColor "Magenta"
        $ret = start-CMContentDistribution -ApplicationName "$displayName" -DistributionPointGroupName $DPG -Verbose
        write-host "^ Done with distribution errors. " -ForegroundColor "Magenta"
    }
    
    
    
    #create Deployment availble All avail computer
    $CollectionType="Device"
    $CollectionName="AllAvailable-PSAppMgmtTK-$CollectionType"
    $Collection = Get-CMCollection -Name $CollectionName -CollectionType $CollectionType 
    $Deployment=Get-CMApplicationDeployment -Name $displayName -CollectionName $CollectionName -ea SilentlyContinue
    if(-not $Deployment){
    $Deployment=New-CMApplicationDeployment -InputObject $CMAPP -Collection $Collection -DeployAction "Install" -DeployPurpose "Available" `
        -AllowRepairApp $VersionedAppSettings.MECM.DeploymentSettings.AllowRepairApp `
        -EnableSoftDeadline $VersionedAppSettings.MECM.DeploymentSettings.EnableSoftDeadline `
        -OverrideServiceWindow $VersionedAppSettings.MECM.DeploymentSettings.OverrideServiceWindow `
        -RebootOutsideServiceWindow $VersionedAppSettings.MECM.DeploymentSettings.RebootOutsideServiceWindow `
        -TimeBaseOn $VersionedAppSettings.MECM.DeploymentSettings.TimeBaseOn `
        -UserNotification $VersionedAppSettings.MECM.DeploymentSettings.UserNotification -verbose 
    }

    #create Deployment available All available user
    $CollectionType="User"
    $CollectionName="AllAvailable-PSAppMgmtTK-$CollectionType" 
    $Collection = Get-CMCollection -Name $CollectionName -CollectionType $CollectionType -ea SilentlyContinue
    $Deployment=Get-CMApplicationDeployment -Name $displayName -CollectionName $CollectionName
    if(-not $Deployment){
        $Deployment=New-CMApplicationDeployment -InputObject $CMAPP -Collection $Collection -DeployAction "Install" -DeployPurpose "Available" `
            -AllowRepairApp $VersionedAppSettings.MECM.DeploymentSettings.AllowRepairApp `
            -EnableSoftDeadline $VersionedAppSettings.MECM.DeploymentSettings.EnableSoftDeadline `
            -OverrideServiceWindow $VersionedAppSettings.MECM.DeploymentSettings.OverrideServiceWindow `
            -RebootOutsideServiceWindow $VersionedAppSettings.MECM.DeploymentSettings.RebootOutsideServiceWindow `
            -TimeBaseOn $VersionedAppSettings.MECM.DeploymentSettings.TimeBaseOn `
            -UserNotification $VersionedAppSettings.MECM.DeploymentSettings.UserNotification -verbose 
    }
    pop-location
}






