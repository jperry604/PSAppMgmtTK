#parameters when available, when required

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
    [Boolean]$RetireOtherVersions=$true,
    [Parameter(Mandatory=$false)]
    [Boolean]$ReplaceOtherVersionsInTSs=$true,
    [Parameter(Mandatory=$false)]
    [Boolean]$ReplaceOtherVersionsDependents=$true
)
import-module (join-path "$env:SMS_ADMIN_UI_PATH\..\" ConfigurationManager.psd1)


$RegPSAppMgmtTKKey = "HKLM:\Software\ITS\PSAppMgmtTK"
$RegPSAppMgmtTKValue = "BaseDirectory"
$BaseDirectory = Get-ItemPropertyValue -path $RegPSAppMgmtTKKey $RegPSAppMgmtTKValue
. "${BaseDirectory}\_Lib\PSAppMgmtLib\ApplicationDeploymentStatusReport.ps1"
. "${BaseDirectory}\_Lib\PSAppMgmtLib\ReplaceApplicationInTaskSequences.ps1"


push-location
Set-Location "C:\"
$GeneralSettings = Get-Content -Path (join-path $BaseDirectory "_ComputerAppMgmt\Generalsettings.json") | ConvertFrom-Json
$AppSettings = Get-Content -Path (join-path $PathToApp AppSettings.json) | ConvertFrom-Json
$VersionedAppSettings = Get-Content -Path (join-path $PathToAppPackage VersionedAppSettings.json) | ConvertFrom-Json

$ScriptStartDateTime = get-date -format yyyy-MM-ddTHH-mm-ss




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

    #Update depenants
    if($ReplaceOtherVersionsDependents){
        write-host "Todo - Add depenedencies found in other versions." -ForegroundColor "Magenta"
        <#
          #$ApplicationName = (Get-WmiObject -Class SMS_ApplicationLatest `
            #-Namespace root/SMS/site_$($SiteCode) -ComputerName $SiteServer `
            #-Filter "CI_ID='$ApplicationCIID'").LocalizedDisplayName
            ##tesing ITS_FileAssociationDefaults_1.1.0_R1

        #this is wrong and finds dependancies
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
        #>
    }
    if ($ReplaceOtherVersionsInTSs){
        foreach($previousproductionPackageStr in $AppSettings.ProductionPackages){
            if ($previousproductionPackageStr -eq "$CMAPPName"){continue}

            #Record status of retiring app deployments.
            $previousproductionPackage = Get-CMApplication -Name "$previousproductionPackageStr" -ea SilentlyContinue
            ReplaceApplicationInTaskSequences -OldApplication $previousproductionPackage -NewApplication $CMAPP
        }
    }

    if ($RetireOtherVersions){
        $previousPackagesArray = $AppSettings.ProductionPackages + $AppSettings.EarlyAdopterPackages
        $AppSettings.ProductionPackages 
        $AppSettingsEarlyAdopterPackages
        $previousPackagesArray
        foreach($previousproductionPackageStr in $previousPackagesArray){
            if ($previousproductionPackageStr -eq "$CMAPPName"){continue}

            #Record status of retiring app deployments.
            $previousproductionPackage = Get-CMApplication -Name "$previousproductionPackageStr" -ea SilentlyContinue
            $PreviousDeployments = $previousproductionPackage   | get-cmApplicationdeployment  -ea SilentlyContinue
            Foreach ($PreviousDeployment in $PreviousDeployments) {
                #Make record of previous deployment
                $AppDeploymentReportObj = Get-CMAppDeploymentReport -DetailLevel Both -OutputType Object -AssignmentID $PreviousDeployment.AssignmentID -Namespace "root\sms\site_$($server.SiteCode)" -Server $server.FQDN
                $ReportFileName = "${ScriptStartDateTime}_$($AppDeploymentReportObj.SummaryResults.SoftwareName)_$($AppDeploymentReportObj.SummaryResults.CollectionName.replace("-${publisher}_${app}", """" ))_S$($AppDeploymentReportObj.SummaryResults.NumberSuccess)_F$($AppDeploymentReportObj.SummaryResults.NumberErrors)"
                if (($AppDeploymentReportObj.SummaryResults.NumberSuccess -eq 0) -and `
                    ($AppDeploymentReportObj.SummaryResults.NumberInProgress -eq 0) -and `
                    ($AppDeploymentReportObj.SummaryResults.NumberUnknown -eq 0) -and `
                    ($AppDeploymentReportObj.SummaryResults.NumberErrors -eq 0)
                ){
                    write-host "No data for: $ReportFileName" #don't document deployments without any targets
                } else {
                    Set-Location "C:\"
                    $ReportDirectory = "${BaseDirectory}\_ComputerAppMgmt\_Logs"
                    If(!(test-path $ReportDirectory )){
                        New-Item -ItemType Directory -Force -Path $ReportDirectory 
                    }

                    
                    $AppDeploymentReportObj.SummaryResults
                    $AppDeploymentReportObj.SummaryResults | Export-CSV "$ReportDirectory\${ReportFileName}-Summary.csv"
                    $AppDeploymentReportObj.DetailResults  | Export-CSV "$ReportDirectory\${ReportFileName}.csv"

                }
                
                #Remove deployment
                # https://docs.microsoft.com/en-us/powershell/module/configurationmanager/remove-cmdeployment?view=sccm-ps
                Set-Location "$($server.SiteCode):\"
                Remove-CMDeployment -InputObject $PreviousDeployment
            }
            

            

            
            

            #Remove dependencies
            #https://docs.microsoft.com/en-us/powershell/module/configurationmanager/remove-cmdeploymenttypedependency?view=sccm-ps



            #superseded apps.
            #https://docs.microsoft.com/en-us/powershell/module/configurationmanager/remove-cmdeploymenttypesupersedence?view=sccm-ps
            
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