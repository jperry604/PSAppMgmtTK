# Create registry for $baseDirectory
# Create CM folders
[CmdletBinding()]
Param (
	[Parameter(Mandatory=$false)]
	[string]$baseDirectory = (get-item $PSScriptRoot).parent.parent.FullName
)
# Requires Configuration manager console installed.
import-module (join-path "$env:SMS_ADMIN_UI_PATH\..\" ConfigurationManager.psd1)

function Write-Regisry {
    [CmdletBinding()]
        Param(
            [parameter(Mandatory=$true)]
            [String]$registryPath,
            [parameter(Mandatory=$true)]
            [String]$Name,
            [parameter(Mandatory=$true)]
            [AllowEmptyString()]
            $Data,
            [parameter(Mandatory=$true)]
            ## https://docs.microsoft.com/en-us/powershell/module/microsoft.powershell.management/new-itemproperty?view=powershell-7.1
            [ValidateSet("String", "ExpandString", "Binary", "DWord", "MultiString", "Qword", "Unknown" )] 
            [String]$Type
    )                        

    IF(!(Test-Path $registryPath)) {
        New-Item -Path $registryPath -Force | Out-Null
        New-ItemProperty -Path $registryPath -Name $name -Value $Data `
        -PropertyType $Type -Force | Out-Null}
     ELSE {
        New-ItemProperty -Path $registryPath -Name $name -Value $Data `
        -PropertyType $Type -Force | Out-Null}
}



$RegPSAppMgmtTKKey = "HKLM:\Software\ITS\PSAppMgmtTK"
$RegPSAppMgmtTKValue = "BaseDirectory"
$RegPSAppMgmtTKData = $baseDirectory
write-host "Setting ${RegPSAppMgmtTKKey}\${BaseDirectory}  -> $RegPSAppMgmtTKData" -ForegroundColor "Yellow"
Write-Regisry -registryPath $RegPSAppMgmtTKKey -Name $RegPSAppMgmtTKValue -Data $RegPSAppMgmtTKData -Type "String"
$BaseDirectory = Get-ItemPropertyValue -path $RegPSAppMgmtTKKey $RegPSAppMgmtTKValue

push-location
Set-Location "C:\"
$GeneralSettings = Get-Content -Path (join-path $BaseDirectory "_ComputerAppMgmt\Generalsettings.json") | ConvertFrom-Json
pop-location

foreach($server in $GeneralSettings.MECM.Servers){
    #Enter MECM Console
    if($null -eq (Get-PSDrive -Name $server.SiteCode -PSProvider CMSite -ErrorAction SilentlyContinue)) {
        New-PSDrive -name $server.SiteCode -psprovider CMSite  -Root $server.FQDN
    }
    push-location
    Set-Location "$($server.SiteCode):\"

    #Todo - Fix Slow & Bad (hard-coded)
    
    #$folder = Get-CimInstance -ComputerName $server.FQDN -Namespace "root\sms\site_$($server.SiteCode)"  -class SMS_ObjectContainernode -filter "ObjectType = $ObjectType AND NAme = 'PSAppMgmtTK'"
    write-host "Creating folders (Recomend using -skipFolderCreation param to skip this)"
    if( -not (get-Item  -Path "$($server.SiteCode):\DeviceCollection\PSAppMgmtTK" -ea SilentlyContinue)){
        New-Item -Name 'PSAppMgmtTK' -Path "$($server.SiteCode):\DeviceCollection" -verbose
    }
    if( -not (get-Item  -Path "$($server.SiteCode):\DeviceCollection\PSAppMgmtTK\ADGroupMemships" -ea SilentlyContinue)){
        New-Item -Name 'ADGroupMemships' -Path "$($server.SiteCode):\DeviceCollection\PSAppMgmtTK" -verbose
    }
    if( -not (get-Item  -Path "$($server.SiteCode):\DeviceCollection\PSAppMgmtTK\Deployments" -ea SilentlyContinue)){
        New-Item -Name 'Deployments' -Path "$($server.SiteCode):\DeviceCollection\PSAppMgmtTK" -verbose
    }

    if( -not (get-Item  -Path "$($server.SiteCode):\UserCollection\PSAppMgmtTK" -ea SilentlyContinue)){
        New-Item -Name 'PSAppMgmtTK' -Path "$($server.SiteCode):\UserCollection" -verbose
    }
    if( -not (get-Item  -Path "$($server.SiteCode):\UserCollection\PSAppMgmtTK\ADGroupMemships" -ea SilentlyContinue)){
        New-Item -Name 'ADGroupMemships' -Path "$($server.SiteCode):\UserCollection\PSAppMgmtTK" -verbose
    }
    if( -not (get-Item  -Path "$($server.SiteCode):\UserCollection\PSAppMgmtTK\Deployments" -ea SilentlyContinue)){
        New-Item -Name 'Deployments' -Path "$($server.SiteCode):\UserCollection\PSAppMgmtTK" -verbose
    }

    if( -not (get-Item  -Path "$($server.SiteCode):\Application\PSAppMgmtTK" -ea SilentlyContinue)){
        New-Item -Name 'PSAppMgmtTK' -Path "$($server.SiteCode):\Application" -verbose
    }

    write-host "Done Creating folders"

    foreach( $DPG in ("DPG-PSAppMgmtTK-Testing", "DPG-PSAppMgmtTK")){
        $DPG_obj = Get-CMDistributionPointGroup -Name $DPG
        if(-not $DPG_obj){
            $DPG_obj = New-CMDistributionPointGroup -Name $DPG
        }
    }
    

    pop-location
}

