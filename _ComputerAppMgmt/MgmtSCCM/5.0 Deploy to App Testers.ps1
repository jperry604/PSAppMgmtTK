#import-module "C:\Program Files (x86)\Microsoft Configuration Manager\AdminConsole\bin\ConfigurationManager.psd1"
[CmdletBinding()]
Param (
	[Parameter(Mandatory=$false)]
	#[string]$PathToApp="\\mecm\SOURCES\AppInstallersManaged\Microsoft_Visual C++ 2015-2022 Redistributable (x64)",
    [string]$PathToApp="\\mecm\SOURCES\AppInstallersManaged\ITS_StartMenuLayout",
    [Parameter(Mandatory=$false)]
	[string]$PathToAppPackage="\\mecm\SOURCES\AppInstallersManaged\ITS_StartMenuLayout\ITS_StartMenuLayout_1.1.0_R1",
    [Parameter(Mandatory=$false)]
    [datetime]$AvailableDateTime=(get-date).AddMinutes(30),
    [Parameter(Mandatory=$false)]
    [datetime]$DeadlineDateTime=(Get-Date -Hour 23 -Minute 59 -Second 0 ) #Default Midnight tonight
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






foreach($server in $GeneralSettings.MECM.Servers){
    #Enter MECM Console
    if($null -eq (Get-PSDrive -Name $server.SiteCode -PSProvider CMSite -ErrorAction SilentlyContinue)) {
        New-PSDrive -name $server.SiteCode -psprovider CMSite  -Root $server.FQDN -Scope Script
    }
    push-location
    Set-Location "$($server.SiteCode):\"

    
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
    
    $CMAPP = Get-CMApplication -Name "$CMAPPName" -ea SilentlyContinue

    $DeploymentPurposeMap = @{"Available"="APPaTesters"; "Required"="APPiTesters"}
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
    }
    pop-location
}






