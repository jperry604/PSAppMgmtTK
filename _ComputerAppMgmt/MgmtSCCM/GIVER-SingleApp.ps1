
[CmdletBinding()]
Param (
	[Parameter(Mandatory=$false)]
	[string]$PathToApp="\\cdnv.dnv.ca\ITS\Endpts\AppInstallersManaged\DNV_Tempest And Tidemark",
    [Parameter(Mandatory=$false)]
	[string]$PathToAppPackage="\\cdnv.dnv.ca\ITS\Endpts\AppInstallersManaged\DNV_Tempest And Tidemark\DNV_Tempest And Tidemark_1.0_R1"
)

Import-Module ActiveDirectory
$PSScriptRoot
$baseDirectory = (get-item $PSScriptRoot).parent.parent
$GeneralSettings = Get-Content -Path (join-path $baseDirectory.fullName "_ComputerAppMgmt\Generalsettings.json") | ConvertFrom-Json
$AppMgmtOU = Get-ADOrganizationalUnit $GeneralSettings.AppMgmtOU
echo "Using AppMgmtOU: $($AppMgmtOU.DistinguishedName)"
echo "Using Directory: $($baseDirectory.fullname)"

push-location
Set-Location "C:\"


$mydir = get-item $PathToApp
$VersionedApp = get-item $PathToAppPackage

cd $PSScriptRoot
& '.\3.0 GenerateADGroups.ps1' -PathToApp $mydir.FullName



cd $PSScriptRoot
& '.\3.1 GenerateMECMCollections.ps1' -PathToApp $mydir.FullName


write-host "Run AD group disovery in MECM and allow to complete."
timeout 3600

cd $PSScriptRoot
& '.\4 Create SCCM Application.ps1' -PathToApp $mydir.FullName -PathToAppPackage $VersionedApp.FullName



write-host "Done creating apps"
timeout 60



cd $PSScriptRoot
& '.\5.0 Deploy to App Testers.ps1' -PathToApp $mydir.FullName -PathToAppPackage $VersionedApp.FullName

write-host "Done 5.0 Deploy to App Testers.ps1"
timeout 60

<#
cd $PSScriptRoot
& '.\6.0 Deploy Early Adopters.ps1' -PathToApp $mydir.FullName -PathToAppPackage $VersionedApp.FullName

write-host "Done 6.0 Deploy Early Adopters"
timeout 60
#>


cd $PSScriptRoot
& '.\7.0 Deploy Production.ps1' -PathToApp $mydir.FullName -PathToAppPackage $VersionedApp.FullName


write-host "Done 7.0 Deploy Production"



pop-location