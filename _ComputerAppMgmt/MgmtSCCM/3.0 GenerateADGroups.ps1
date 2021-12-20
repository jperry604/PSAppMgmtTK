# Requires Configuration manager console installed.
[CmdletBinding()]
Param (
	[Parameter(Mandatory=$false)]
	[string]$PathToApp="\\mecm\SOURCES\AppInstallersManaged\ITS_StartMenuLayout",
    [Parameter(Mandatory=$false)]
    [int]$RefreshType =2 ## 6 = Incremental and Scheduled Updates             # 4 = Incremental Updates Only             # 2 = Scheduled Updates only             # 1 = Manual Update only 
)
import-module (join-path "$env:SMS_ADMIN_UI_PATH\..\" ConfigurationManager.psd1)
Import-Module ActiveDirectory

$displayName = Split-Path $PathToApp -Leaf
$sections = $displayName.Split("_")
$publisher = $sections[0]
$app = $sections[1]

$PathToApp


$RegPSAppMgmtTKKey = "HKLM:\Software\ITS\PSAppMgmtTK"
$RegPSAppMgmtTKValue = "BaseDirectory"
$BaseDirectory = Get-ItemPropertyValue -path $RegPSAppMgmtTKKey $RegPSAppMgmtTKValue

push-location
Set-Location "C:\"
$GeneralSettings = Get-Content -Path (join-path $BaseDirectory "_ComputerAppMgmt\Generalsettings.json") | ConvertFrom-Json
$AppSettings = Get-Content -Path (join-path $PathToApp AppSettings.json) | ConvertFrom-Json
pop-location





foreach( $OUj in $AppSettings.CreateADGroups.OUs){
    $AppMgmtOU = Get-ADOrganizationalUnit  $OUj.OU
    if(-not $AppMgmtOU){continue}
    forEach ($group in $OUj.Groups){
        if($true -ne $group.Create) { continue }
        $ADGroupName = "$($group.Prefix)-$displayName"
        $SAMName = "$ADGroupName".replace("+","_")
        if ( -not (Get-ADGroup -SearchBase $AppMgmtOU -Filter "samAccountName -eq '$($SAMName)'" -verbose) ) {
            write-host "to create $ADGroupName"
            $Description = $group.Description
            if($Description -eq "" ) { 
                $Description = $AppSettings.ComputerAppMgmt.AppType
            }
            New-ADGroup -Path $AppMgmtOU -Name $ADGroupName -Description $Description -GroupScope DomainLocal -GroupCategory Security -SamAccountName $SAMName -Verbose 
            
        } else {
            Write-host "$ADGroupName already exists"
        }
    }
    

}



