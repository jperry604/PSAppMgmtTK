#parameters when available, when required

#import-module "C:\Program Files (x86)\Microsoft Configuration Manager\AdminConsole\bin\ConfigurationManager.psd1"
[CmdletBinding()]
Param (
	[Parameter(Mandatory=$false)]
    [string]$PathToApp="\\mecm\SOURCES\AppInstallersManaged\Microsoft_Visual C++ 2015-2022 Redistributable (x64)",
	#[string]$PathToApp="\\mecm\SOURCES\AppInstallersManaged\ITS_StartMenuLayout",
    [Parameter(Mandatory=$false)]
	[string]$PathToAppPackage="\\mecm\SOURCES\AppInstallersManaged\ITS_StartMenuLayout\ITS_StartMenuLayout_1.1.0_R1",
    [Parameter(Mandatory=$false)]
    [datetime]$AvailableDateTime=(get-date).AddMinutes(30),
    [Parameter(Mandatory=$false)]
    [datetime]$DeadlineDateTime=(Get-Date -Hour 23 -Minute 59 -Second 0 ), #Default Midnight tonight
    [Parameter(Mandatory=$false)]
    [Boolean]$RetireOtherVersions=$true,
    [Parameter(Mandatory=$false)]
    [Boolean]$ReplaceOtherVersionsInTSs=$true
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






foreach($server in $GeneralSettings.MECM.Servers){
    #Enter MECM Console
    if($null -eq (Get-PSDrive -Name $server.SiteCode -PSProvider CMSite -ErrorAction SilentlyContinue)) {
        New-PSDrive -name $server.SiteCode -psprovider CMSite  -Root $server.FQDN -Scope Script
    }
    
    Set-Location "C:\"


    #Handle Patch my PC name mapping
    if("MECM-PMPC" -eq $AppSettings.ComputerAppMgmt.AppType) { 
        $CMAPPName = $AppSettings.PMPC.AppName
        $displayName= Split-Path $PathToApp -Leaf
        #$AppSettings.PMPC.Vendor
    }else{
        $displayName = Split-Path $PathToAppPackage -Leaf
        $CMAPPName = "$displayName"
    }
    $sections = $displayName.Split("_")
    $publisher = $sections[0]
    $app = $sections[1]
    $version = $sections[2]
    $revision = $sections[3]
    
    Set-Location "$($server.SiteCode):\"
    write-host "$CMAPPName"
    $CMAPP = Get-CMApplication -Name "$CMAPPName" -ea SilentlyContinue
    write-host "$($Null -eq $CMAPP)"

    
    $DeploymentPurposeMap = @{"Available"="APPa"; "Required"="APPi"}
    foreach($CollectionType in ("Device", "User")){
        foreach($DeploymentPurpose in ("Available", "Required")){
            $CollectionName="$($DeploymentPurposeMap[$DeploymentPurpose])-${publisher}_${app}-$CollectionType"
            $Collection = Get-CMCollection -Name $CollectionName -CollectionType $CollectionType 
            if(-not $Collection){
                write-host "No Collection Named: $CollectionName"
                continue
            }
            $Deployment=Get-CMApplicationDeployment -Name $CMAPPName -CollectionName $CollectionName -ea SilentlyContinue

            if($Deployment){
                write-host "Deployment already exists to: $CollectionName"
            } else {
                Write-host "Creating App Deployment to collection: $CollectionName"
                Write-host "AvailableDateTime: $AvailableDateTime    UTC[$($AvailableDateTime.ToUniversalTime())]"
                Write-host "DeadlineDateTime $DeadlineDateTime UTC[$($DeadlineDateTime.ToUniversalTime())]"
                $Deployment=New-CMApplicationDeployment -InputObject $CMAPP -Collection $Collection -DeployAction "Install" -DeployPurpose $DeploymentPurpose `
                    -AllowRepairApp $VersionedAppSettings.MECM.DeploymentSettings.AllowRepairApp `
                    -EnableSoftDeadline $VersionedAppSettings.MECM.DeploymentSettings.EnableSoftDeadline `
                    -OverrideServiceWindow $VersionedAppSettings.MECM.DeploymentSettings.OverrideServiceWindow `
                    -RebootOutsideServiceWindow $VersionedAppSettings.MECM.DeploymentSettings.RebootOutsideServiceWindow `
                    -TimeBaseOn $VersionedAppSettings.MECM.DeploymentSettings.TimeBaseOn `
                    -UserNotification $VersionedAppSettings.MECM.DeploymentSettings.UserNotification `
                    -AvailableDateTime $AvailableDateTime `
                    -DeadlineDateTime $DeadlineDateTime.ToUniversalTime() -verbose 
            }
        }

        foreach( $CollectionName in ("AllAvailable-PSAppMgmtTK-$CollectionType",  "AllPrdAvailable-PSAppMgmtTK-$CollectionType")){
            $Collection = Get-CMCollection -Name $CollectionName -CollectionType $CollectionType -ea SilentlyContinue
            $Deployment=Get-CMApplicationDeployment  -InputObject $CMAPP -CollectionName $CollectionName
            if(-not $Deployment){
                $Deployment=New-CMApplicationDeployment -InputObject $CMAPP -Collection $Collection -DeployAction "Install" -DeployPurpose "Available" `
                    -AllowRepairApp $VersionedAppSettings.MECM.DeploymentSettings.AllowRepairApp `
                    -EnableSoftDeadline $VersionedAppSettings.MECM.DeploymentSettings.EnableSoftDeadline `
                    -OverrideServiceWindow $VersionedAppSettings.MECM.DeploymentSettings.OverrideServiceWindow `
                    -RebootOutsideServiceWindow $VersionedAppSettings.MECM.DeploymentSettings.RebootOutsideServiceWindow `
                    -TimeBaseOn $VersionedAppSettings.MECM.DeploymentSettings.TimeBaseOn `
                    -UserNotification $VersionedAppSettings.MECM.DeploymentSettings.UserNotification -verbose 
            }
        }
    }
}

pop-location


#Update the json file
#$AppSettings = Get-Content -Path (join-path $PathToApp AppSettings.json) | ConvertFrom-Json
if(-not ($AppSettings.ProductionPackages.contains($displayName))){
    Write-Host "Noting $displayName has been elevated to Production."
    $AppSettings.ProductionPackages += $displayName
    ConvertTo-Json $AppSettings -Depth 50  | Out-file (join-path $PathToApp AppSettings.json)
}

#Automatically update or remove an application in all of your ConfigMgr task sequences - Jose Espitia
# https://www.joseespitia.com/2020/05/08/automatically-update-or-remove-an-application-in-all-of-your-configmgr-task-sequences/


#Update dependancies. (depenants)
# Done when early adopters



#Record status of retiring app deployments.
#Get-CMApplicationDeploymentStatus