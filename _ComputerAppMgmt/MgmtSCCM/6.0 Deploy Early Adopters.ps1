#import-module "C:\Program Files (x86)\Microsoft Configuration Manager\AdminConsole\bin\ConfigurationManager.psd1"
[CmdletBinding()]
Param (
	[Parameter(Mandatory=$true)]
	[string]$PathToApp,
    [Parameter(Mandatory=$true)]
	[string]$PathToAppPackage,
    [Parameter(Mandatory=$false)]
    [datetime]$AvailableDateTime=(get-date).AddMinutes(30),
    [Parameter(Mandatory=$false)]
    [datetime]$DeadlineDateTime=(Get-Date -Hour 23 -Minute 59 -Second 0 ), #Default Midnight tonight
    [Parameter(Mandatory=$false)]
    [Boolean]$ReplaceOtherVersionsInTSs=$true
)
import-module (join-path "$env:SMS_ADMIN_UI_PATH\..\" ConfigurationManager.psd1)

$RegPSAppMgmtTKKey = "HKLM:\Software\ITS\PSAppMgmtTK"
$RegPSAppMgmtTKValue = "BaseDirectory"
$BaseDirectory = Get-ItemPropertyValue -path $RegPSAppMgmtTKKey $RegPSAppMgmtTKValue
. "${BaseDirectory}\_Lib\PSAppMgmtLib\ReplaceApplicationInTaskSequences.ps1"

push-location
Set-Location "C:\"
$GeneralSettings = Get-Content -Path (join-path $BaseDirectory "_ComputerAppMgmt\Generalsettings.json") | ConvertFrom-Json
$AppSettings = Get-Content -Path (join-path $PathToApp AppSettings.json) | ConvertFrom-Json
$VersionedAppSettings = Get-Content -Path (join-path $PathToAppPackage VersionedAppSettings.json) | ConvertFrom-Json






foreach($server in $GeneralSettings.MECM.Servers){
    Set-Location "C:\"
    #Enter MECM Console
    if($null -eq (Get-PSDrive -Name $server.SiteCode -PSProvider CMSite -ErrorAction SilentlyContinue)) {
        New-PSDrive -name $server.SiteCode -psprovider CMSite  -Root $server.FQDN -Scope Script
    }
    
    
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
    $CMAPP = Get-CMApplication -Name "$CMAPPName" -ea SilentlyContinue
    

    
    $DeploymentPurposeMap = @{"Required"="APPie"}
    foreach($CollectionType in ("Device", "User")){
        foreach($DeploymentPurpose in ("Required")){
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
    
}
if ($ReplaceOtherVersionsInTSs){
    foreach($previousproductionPackageStr in $AppSettings.ProductionPackages){
        if ($previousproductionPackageStr -eq "$CMAPPName"){continue}

        #Record status of retiring app deployments.
        $previousproductionPackage = Get-CMApplication -Name "$previousproductionPackageStr" -ea SilentlyContinue
        ReplaceApplicationInTaskSequences -OldApplication $previousproductionPackage -NewApplication $CMAPP
    }
}

pop-location

#Update dependancies. (depenants)
<#
$CMAPPType = Get-CMDeploymentType -InputObject $CMAPP
$DependancyGroups = Get-CMDeploymentTypeDependencyGroup -InputObject $CMAPPType
Get-CMDeploymentTypeDependency -InputObject $DependancyGroups
$Dependency = Get-CMDeploymentTypeDependency -InputObject $dependancyGRP[0]


New-CMDeploymentTypeDependencyGroup

Add-CMDeploymentTypeDependency

$dependancyGRP[0].Rule.Expression    
#>

#Update the json file
#$AppSettings = Get-Content -Path (join-path $PathToApp AppSettings.json) | ConvertFrom-Json
if(-not ($AppSettings.EarlyAdopterPackages.contains($displayName))){
    Write-Host "Noting $displayName has been elevated to Early Adopters."
    $AppSettings.EarlyAdopterPackages += $displayName
    ConvertTo-Json $AppSettings -Depth 50  | Out-file (join-path $PathToApp AppSettings.json)
}


#Distribute to production DPs




#for each prd app
#NumberOfDependedDTs                : 0
#NumberOfDependentDTs               : 1

#countFoundDTs=0

#For each application
#for each app type
#for each dependency group
#for each depenancy

# CI_ID = Old CI_ID
# https://www.petervanderwoude.nl/post/showing-dependent-applications-in-configmgr-2012-via-powershell/

<#
$DependentApplications = Get-WmiObject -Class SMS_AppDependenceRelation `
-Namespace root/SMS/site_$($SiteCode) -ComputerName $SiteServer `
-Filter "ToApplicationCIID='$ApplicationCIID'"

$ApplicationName = (Get-WmiObject -Class SMS_ApplicationLatest `
-Namespace root/SMS/site_$($SiteCode) -ComputerName $SiteServer `
-Filter "CI_ID='$ApplicationCIID'").LocalizedDisplayName

#>