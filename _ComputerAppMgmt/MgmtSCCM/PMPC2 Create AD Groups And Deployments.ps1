[CmdletBinding()]
Param (
	[Parameter(Mandatory=$false)]
	[System.IO.DirectoryInfo]$baseDirectory = (get-item $PSScriptRoot).parent.parent,
    [Parameter(Mandatory=$false)]
	$PMPCAppFolder="\\mecm\SOURCES\PMPC-Sources\Applications"
)

push-location
Set-Location C:\

foreach ($AppDir in $baseDirectory.GetDirectories() ) {
    #Skip directories that start with an underscore
    if ( $AppDir.Name.StartsWith("_") ) { continue }
    #Ensure AppSettings Exists
    $AppSettingsPath = Join-Path $AppDir "AppSettings.json"
    if(-not (Test-path $AppSettingsPath)) { continue }

    $AppSettings = get-content $AppSettingsPath | ConvertFrom-Json
    if("MECM-PMPC" -ne $AppSettings.ComputerAppMgmt.AppType) { continue }
    write-host "Working on $($AppDir.name)"

    #uncomment each of these in order & run script again. Reminder to Run discovery after AD groups created.
    #& (join-path $PSScriptRoot "3.0 GenerateADGroups.ps1") -PathToApp $AppDir.FullName
    #& (join-path $PSScriptRoot "3.1 GenerateMECMCollections.ps1")  -PathToApp $AppDir.FullName
    & (join-path $PSScriptRoot "7.0 Deploy Production.ps1")  -PathToApp $AppDir.FullName
    Set-Location C:\
}
pop-Location

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
        #if(-not (test-path $AppMgmtJsonPath)){
        if($true){
            $AppSettings = get-content (Join-Path $baseDirectory "__Template_Vendor_AppName\AppSettings.json") | ConvertFrom-Json
            $AppSettings.ComputerAppMgmt.AppType = "MECM-PMPC"
            $PMPCJson = "{`"PMPC`":{`"Vendor`":`"$($VendorDir.Name)`",`"AppName`":`"$($AppDir.Name)`"}}" | ConvertFrom-Json
            Add-Member -inputObject $AppSettings -NotePropertyName "PMPC" -NotePropertyValue $PMPCJson.PMPC
            $AppJson
            ConvertTo-Json $AppSettings -Depth 50  | Out-file $AppMgmtJsonPath
        }
        


    }
}
#>