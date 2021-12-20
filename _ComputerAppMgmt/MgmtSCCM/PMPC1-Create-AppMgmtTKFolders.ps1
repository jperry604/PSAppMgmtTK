[CmdletBinding()]
Param (
	[Parameter(Mandatory=$false)]
	[string]$baseDirectory = (get-item $PSScriptRoot).parent.parentFullName
)


# Requires Configuration manager console installed.
import-module (join-path "$env:SMS_ADMIN_UI_PATH\..\" ConfigurationManager.psd1)

push-location
Set-Location "C:\"
$RegPSAppMgmtTKKey = "HKLM:\Software\ITS\PSAppMgmtTK"
$RegPSAppMgmtTKValue = "BaseDirectory"
$BaseDirectory = Get-ItemPropertyValue -path $RegPSAppMgmtTKKey $RegPSAppMgmtTKValue


$GeneralSettings = Get-Content -Path (join-path $baseDirectory "_ComputerAppMgmt\Generalsettings.json") | ConvertFrom-Json


foreach($server in $GeneralSettings.MECM.Servers){
    #Enter MECM Console
    if($null -eq (Get-PSDrive -Name $server.SiteCode -PSProvider CMSite -ErrorAction SilentlyContinue)) {
        New-PSDrive -name $server.SiteCode -psprovider CMSite  -Root $server.FQDN
    }
    
    Set-Location "$($server.SiteCode):\"

    write-host "Seaching all Apps on $($server.SiteCode):\ for those with source in $($server.PatchMyPC.SourceFolder)"

    foreach($CMAPP in (Get-CMApplication)){
        foreach($CMAPPType in ($CMAPP | Get-CMDeploymentType )){
            foreach($Apptype2 in (([xml]$CMAPPType.SDMPackageXML).AppMgmtDigest.DeploymentType)){
                Set-Location "$($server.SiteCode):\"
                $contentLocation = $Apptype2.Installer.Contents.Content.Location
                if(-not ($contentLocation.StartsWith($server.PatchMyPC.SourceFolder) )) {Continue}
                
                $VendorName = "$($CMAPP.Manufacturer)".replace(" Systems, Inc.", "").replace(", Inc.", "").replace(" LLC", "").replace(" Corporation", "").replace("_", "-")
                $AppName = "$($CMAPP.LocalizedDisplayName)".replace("_", "-")
                if($AppName.StartsWith($VendorName)){
                    $AppName = $AppName.Replace($VendorName, "", 1).Trim()
                }
                
                Set-Location "C:\"

                $GeneralContentLocation = split-path $contentLocation -parent
                $App="${VendorName}_${AppName}"
                Write-host "Working on $App ..."
                $AppMgmtDir = join-path $baseDirectory $App
                if(-not (Test-Path -Path $AppMgmtDir)){
                    Write-host "Creating Directory $AppMgmtDir"
                    New-Item -ItemType "directory" -Path $AppMgmtDir
                }
                
                
                $AppMgmtJsonPath = Join-Path $AppMgmtDir "AppSettings.json"
                #if(-not (test-path $AppMgmtJsonPath)){
                if($true){ #use to reset the PMCP AppSettingsFiles
                    $AppSettings = get-content (Join-Path $baseDirectory "__Template_Vendor_AppName\AppSettings.json") | ConvertFrom-Json
                    $AppSettings.ComputerAppMgmt.AppType = "MECM-PMPC"

                    #No Early Adopter Collections (New versions are tested/handled through Updates)
                    $AppSettings.MECM.CollectionTypes.APPie.CreateDeploymentDeviceCollection = $false
                    $AppSettings.MECM.CollectionTypes.APPie.CreateDeploymentUserCollection = $false
                    
                    $PMPCJson = "{`"PMPC`":{`"Vendor`":`"$($CMAPP.Manufacturer)`",`"AppName`":`"$($CMAPP.LocalizedDisplayName)`", `"ContentLocation`":`"$($GeneralContentLocation.replace("\","\\"))`"}}" | ConvertFrom-Json
                    Add-Member -inputObject $AppSettings -NotePropertyName "PMPC" -NotePropertyValue $PMPCJson.PMPC
                    
                    ConvertTo-Json $AppSettings -Depth 50  | Out-file $AppMgmtJsonPath
                }
                Set-Location "$($server.SiteCode):\"
            }
        }
    }
}

pop-location

<#
foreach($VendorDir in (Get-ChildItem -path $PMPCAppFolder)) {
    foreach($AppDir in (Get-ChildItem -path $VendorDir)) {
        $VendorName = "$($VendorDir.Name)".replace(", Inc_", "").replace(" LLC", "").replace(" Corporation", "").replace("_", "-")
        $AppName ="$($AppDir.Name)".replace(", Inc_", "").replace(" LLC", "").replace("_", "-").replace(" - MSI Install", "").trim()
        if($AppName.StartsWith($VendorName)){
            $AppName = $AppName.Replace($VendorName, "", 1).Trim()
         }
        $App="${VendorName}_${AppName}"
        Write-host "Working on $App ..."
        $AppMgmtDir = join-path $baseDirectory $App
        if(-not (Test-Path -Path $AppMgmtDir)){
            New-Item -ItemType "directory" -Path $AppMgmtDir
        }
        $AppMgmtJsonPath = Join-Path $AppMgmtDir "AppSettings.json"
        if(-not (test-path $AppMgmtJsonPath)){
        #if($true){ #use to reset the PMCP AppSettingsFiles
            $AppSettings = get-content (Join-Path $baseDirectory "__Template_Vendor_AppName\AppSettings.json") | ConvertFrom-Json
            $AppSettings.ComputerAppMgmt.AppType = "MECM-PMPC"
            
            #No Early Adopter Collections (New versions are tested/handled through Updates)
            $AppSettings.MECM.CollectionTypes.APPie.CreateDeploymentDeviceCollection = $false
            $AppSettings.MECM.CollectionTypes.APPie.CreateDeploymentUserCollection = $false
            
            $PMPCJson = "{`"PMPC`":{`"Vendor`":`"$($VendorDir.Name)`",`"AppName`":`"$($AppDir.Name)`"}}" | ConvertFrom-Json
            Add-Member -inputObject $AppSettings -NotePropertyName "PMPC" -NotePropertyValue $PMPCJson.PMPC
            ConvertTo-Json $AppSettings -Depth 50  | Out-file $AppMgmtJsonPath
        }
    }
}
#>