
Import-Module ActiveDirectory
$PSScriptRoot
$baseDirectory = (get-item $PSScriptRoot).parent.parent
$GeneralSettings = Get-Content -Path (join-path $baseDirectory.fullName "_ComputerAppMgmt\Generalsettings.json") | ConvertFrom-Json
$AppMgmtOU = Get-ADOrganizationalUnit $GeneralSettings.AppMgmtOU
echo "Using AppMgmtOU: $($AppMgmtOU.DistinguishedName)"
echo "Using Directory: $($baseDirectory.fullname)"

push-location
Set-Location "C:\"

foreach ($mydir in $baseDirectory.GetDirectories("*_*") ) {
    #Skip directories that start with an underscore
    if ( $mydir.Name.StartsWith("_") ) { continue }
    if ( $mydir.Name -eq ".git" ) { continue }
    if ( $GeneralSettings.AppMgmtExceptions.Contains($mydir.Name) )  { write-host "exclude $($mydir.Name)";continue }

    cd $PSScriptRoot

    & '.\3.0 GenerateADGroups.ps1' -PathToApp $mydir.FullName
}

foreach ($mydir in $baseDirectory.GetDirectories("*_*") ) {
    #Skip directories that start with an underscore
    if ( $mydir.Name.StartsWith("_") ) { continue }
    if ( $mydir.Name -eq ".git" ) { continue }
    if ( $GeneralSettings.AppMgmtExceptions.Contains($mydir.Name) )  { write-host "exclude $($mydir.Name)";continue }

    cd $PSScriptRoot
    & '.\3.1 GenerateMECMCollections.ps1' -PathToApp $mydir.FullName
}

write-host "Run AD group disovery in MECM and allow to complete."
timeout 3600

foreach ($mydir in $baseDirectory.GetDirectories() ) {
    if ( $mydir.Name.StartsWith("_") ) { continue }
    if ( $mydir.Name -eq ".git" ) { continue }
    if ( $GeneralSettings.AppMgmtExceptions.Contains($mydir.Name) )  { write-host "exclude $($mydir.Name)";continue }

    $VersionedApps = $mydir.GetDirectories('*_*_*')
    foreach($VersionedApp in $VersionedApps){
        
        if ($VersionedApp.name -eq "__Vendor_App_version_Revision") {continue}
        $VersionedApp.FullName
        #[string]$PathToApp="\\mecm\SOURCES\AppInstallersManaged\ITS_StartMenuLayout",
    	#[string]$PathToAppPackage="\\mecm\SOURCES\AppInstallersManaged\ITS_StartMenuLayout\ITS_StartMenuLayout_1.1.0_R1",
        cd $PSScriptRoot
        & '.\4 Create SCCM Application.ps1' -PathToApp $mydir.FullName -PathToAppPackage $VersionedApp.FullName
    }
}


write-host "Done creating apps"
timeout 60




foreach ($mydir in $baseDirectory.GetDirectories() ) {
    if ( $mydir.Name.StartsWith("_") ) { continue }
    if ( $mydir.Name -eq ".git" ) { continue }
    if ( $GeneralSettings.AppMgmtExceptions.Contains($mydir.Name) )  { write-host "exclude $($mydir.Name)";continue }

    $VersionedApps = $mydir.GetDirectories('*_*_*')
    foreach($VersionedApp in $VersionedApps){
        
        if ($VersionedApp.name -eq "__Vendor_App_version_Revision") {continue}
        $VersionedApp.FullName
        #[string]$PathToApp="\\mecm\SOURCES\AppInstallersManaged\ITS_StartMenuLayout",
    	#[string]$PathToAppPackage="\\mecm\SOURCES\AppInstallersManaged\ITS_StartMenuLayout\ITS_StartMenuLayout_1.1.0_R1",
        cd $PSScriptRoot
        & '.\5.0 Deploy to App Testers.ps1' -PathToApp $mydir.FullName -PathToAppPackage $VersionedApp.FullName
    }
}

write-host "Done 5.0 Deploy to App Testers.ps1"
timeout 60

<#
foreach ($mydir in $baseDirectory.GetDirectories() ) {
    if ( $mydir.Name.StartsWith("_") ) { continue }
    if ( $mydir.Name -eq ".git" ) { continue }
    if ( $GeneralSettings.AppMgmtExceptions.Contains($mydir.Name) )  { write-host "exclude $($mydir.Name)";continue }

    $VersionedApps = $mydir.GetDirectories('*_*_*')
    foreach($VersionedApp in $VersionedApps){
        
        if ($VersionedApp.name -eq "__Vendor_App_version_Revision") {continue}
        $VersionedApp.FullName
        #[string]$PathToApp="\\mecm\SOURCES\AppInstallersManaged\ITS_StartMenuLayout",
    	#[string]$PathToAppPackage="\\mecm\SOURCES\AppInstallersManaged\ITS_StartMenuLayout\ITS_StartMenuLayout_1.1.0_R1",
        cd $PSScriptRoot
        & '.\6.0 Deploy Early Adopters.ps1' -PathToApp $mydir.FullName -PathToAppPackage $VersionedApp.FullName
        pause
    }
}

write-host "Done 6.0 Deploy Early Adopters"
timeout 60
#>

foreach ($mydir in $baseDirectory.GetDirectories() ) {
    if ( $mydir.Name.StartsWith("_") ) { continue }
    if ( $mydir.Name -eq ".git" ) { continue }
    if ( $GeneralSettings.AppMgmtExceptions.Contains($mydir.Name) )  { write-host "exclude $($mydir.Name)";continue }

    $VersionedApps = $mydir.GetDirectories('*_*_*')
    foreach($VersionedApp in $VersionedApps){
        
        if ($VersionedApp.name -eq "__Vendor_App_version_Revision") {continue}
        $VersionedApp.FullName
        #[string]$PathToApp="\\mecm\SOURCES\AppInstallersManaged\ITS_StartMenuLayout",
    	#[string]$PathToAppPackage="\\mecm\SOURCES\AppInstallersManaged\ITS_StartMenuLayout\ITS_StartMenuLayout_1.1.0_R1",
        cd $PSScriptRoot
        & '.\7.0 Deploy Production.ps1' -PathToApp $mydir.FullName -PathToAppPackage $VersionedApp.FullName
    }
}

write-host "Done 7.0 Deploy Production"



pop-location