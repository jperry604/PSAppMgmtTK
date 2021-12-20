param (
    [string]$PathToApp="\\mecm\SOURCES\AppInstallersManaged\ITS_StartMenuLayout"
)
#import-module (join-path "$env:SMS_ADMIN_UI_PATH\..\" ConfigurationManager.psd1)
Try {
    Import-Module ActiveDirectory -erroraction stop
} catch {
    write-host "Error 'Import-Module ActiveDirectory' Suggest installing RSAT. " -ForegroundColor "red"
    timeout 10
    throw $_
    return 1
}

$displayName = Split-Path $PathToApp -Leaf
$sections = $displayName.Split("_")
$publisher = $sections[0]
$app = $sections[1]
#$version = $sections[2]
#$revision = $sections[3]

$RegPSAppMgmtTKKey = "HKLM:\Software\ITS\PSAppMgmtTK"
$RegPSAppMgmtTKValue = "BaseDirectory"
$BaseDirectory = Get-ItemPropertyValue -path $RegPSAppMgmtTKKey $RegPSAppMgmtTKValue

#$GeneralSettings = Get-Content -Path (join-path $BaseDirectory "_ComputerAppMgmt\Generalsettings.json") | ConvertFrom-Json
$AppSettings = Get-Content -Path (join-path $PathToApp AppSettings.json) | ConvertFrom-Json

#$GeneralSettings
#$AppSettings


foreach ($OU in $AppSettings.CreateADGroups.OUs){
    $AppMgmtOU = Get-ADOrganizationalUnit -Identity $OU.OU
    foreach($group in $OU.Groups) {
        
        if($group.Create){
            $groupName = "$($group.Prefix)-$publisher-$app"
            if(-not (Get-ADGroup -SearchBase $AppMgmtOU -Filter "Name -eq '$groupName'")){
                write-host "creating $groupName under $($OU.OU)"
                New-ADGroup -Path $AppMgmtOU -Name $groupName -Description $group.Description -GroupScope DomainLocal -GroupCategory Security -Verbose 
            } else {
                write-host "$groupName already exists under $($OU.OU)"
            }
        }


    }
    #$OUString = $OU.PSObject.Properties.Name.toString()
    #$AppMgmtOU = Get-ADOrganizationalUnit -Identity $OUString
    #$AppMgmtOU.toString()

    #$OU.($OUString) | get-member -MemberType NoteProperty
    

    #foreach($groupType in $OU.($OUString)){
        #$groupType.PSObject.Properties.Name.toString()
    #    "Got" + $groupType
    #    $groupType.PSObject.Properties.Name.toString()
    #}

    <#
    $ADGroup = @{
        install = Get-ADGroup -SearchBase $AppMgmtOU -Filter "Name -eq 'APPi-$($software)'"
        uninstall = Get-ADGroup -SearchBase $AppMgmtOU -Filter "Name -eq 'APPu-$($software)'"
        available = Get-ADGroup -SearchBase $AppMgmtOU -Filter "Name -eq 'APPa-$($software)'"
    }#>
    

}
