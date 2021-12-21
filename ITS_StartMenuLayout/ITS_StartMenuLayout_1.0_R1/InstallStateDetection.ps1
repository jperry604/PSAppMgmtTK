# Recommend creating detection scripts compatible with both Intune and SCCM

<# Intune App Detection Script Rules
    Exit code	Data read from STDOUT	Detection state
    0			Not empty				Detected <-- Match (installed)
    0			Empty					Not Detected <-- Match (not installed)
    Not zero	Empty					Not Detected
    Not zero	Not Empty				Not Detected
#>
<# SCCM App Detection Script Rules
    Script exit code	Data read from STDOUT	Data read from STDERR	Script result	Application detection state
    0	Not empty	Empty	Success	Installed   <-- Match
    0	Empty	Empty	Success	Not installed   <-- Match (not installed)
    0	Empty	Not empty	Failure	Unknown
    0	Not empty	Not empty	Success	Installed
    Non-zero value	Empty	Empty	Failure	Unknown
    Non-zero value	Empty	Not empty	Failure	Unknown
    Non-zero value	Not empty	Empty	Failure	Unknown
    Non-zero value	Not empty	Not empty	Failure	Unknown
#>



<# Source information
Get-ItemProperty -Path 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\*',
                    'HKLM:\SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall\*',
                    'HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\*',
                    'HKCU:\SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall\*' -ErrorAction Ignore |
Where-Object DisplayName |
Select-Object -Property DisplayName, DisplayVersion, UninstallString, InstallDate |
Sort-Object -Property DisplayName  | FT -AutoSize -wrap
#>

#Check ARP for Name
<#
$DisplayName = ""
$check = $false
Get-ChildItem -Path HKLM:\software\microsoft\windows\currentversion\uninstall -Recurse -ErrorAction SilentlyContinue | % {if ((Get-ItemProperty -Path $_.pspath).DisplayName -eq $DisplayName) {$check = $true }}
Get-ChildItem -Path HKLM:\software\wow6432node\microsoft\windows\currentversion\uninstall -Recurse -ErrorAction SilentlyContinue | % {if ((Get-ItemProperty -Path $_.pspath).DisplayName -eq $DisplayName) {$check = $true }}
if ($check) {Write-Host "Installed"}
else {}
#>

#Check ARP for GUID
<#
$GUID = "{00000000-0000-0000-0000-000000000000}"
$check = $false
Get-ChildItem -Path HKLM:\software\microsoft\windows\currentversion\uninstall -Recurse -ErrorAction SilentlyContinue | % {if ((Get-ItemProperty -Path $_.pspath).DisplayName -eq $DisplayName) {$check = $true }}
Get-ChildItem -Path HKLM:\software\wow6432node\microsoft\windows\currentversion\uninstall -Recurse -ErrorAction SilentlyContinue | % {if ((Get-ItemProperty -Path $_.pspath).DisplayName -eq $DisplayName) {$check = $true }}
if ($check) {Write-Host "Installed"}
else {}
#>



#Check Specific Version
<#
$DisplayName = ""
$Version = ""
$check = $false
Get-ChildItem -Path HKLM:\software\microsoft\windows\currentversion\uninstall -Recurse -ErrorAction SilentlyContinue | % {if (((Get-ItemProperty -Path $_.pspath).DisplayName -eq $DisplayName) -and ((Get-ItemProperty -Path $_.pspath).DisplayVersion -eq $Version)) {$check = $true}}
Get-ChildItem -Path HKLM:\software\wow6432node\microsoft\windows\currentversion\uninstall -Recurse -ErrorAction SilentlyContinue | % {if (((Get-ItemProperty -Path $_.pspath).DisplayName -eq $DisplayName) -and ((Get-ItemProperty -Path $_.pspath).DisplayVersion -eq $Version)) {$check = $true}}
if ($check) {Write-Host "Installed"}
else {}
#>

#Check ARP Version Equal to or greather than
<#
$DisplayName = ""
$Version = ""
$check = $false
Get-ChildItem -Path HKLM:\software\microsoft\windows\currentversion\uninstall -Recurse -ErrorAction SilentlyContinue | % {if (((Get-ItemProperty -Path $_.pspath).DisplayName -eq $DisplayName) -and (([version](Get-ItemProperty -Path $_.pspath).DisplayVersion) -ge [version]$Version)) {$check = $true}}
Get-ChildItem -Path HKLM:\software\wow6432node\microsoft\windows\currentversion\uninstall -Recurse -ErrorAction SilentlyContinue | % {if (((Get-ItemProperty -Path $_.pspath).DisplayName -eq $DisplayName) -and (([version](Get-ItemProperty -Path $_.pspath).DisplayVersion) -ge [version]$Version)) {$check = $true}}
if ($check) {Write-Host "Installed"}
#>

#Check ARP Version Equal to or greather than, with name LIKE
<#
$DisplayName = "Autodesk DWG TrueView 20* - English"
$Version = ""
$check = $false
Get-ChildItem -Path HKLM:\software\microsoft\windows\currentversion\uninstall -Recurse -ErrorAction SilentlyContinue | % {if (((Get-ItemProperty -Path $_.pspath).DisplayName -like $DisplayName) -and (([version](Get-ItemProperty -Path $_.pspath).DisplayVersion) -ge [version]$Version)) {$check = $true}}
Get-ChildItem -Path HKLM:\software\wow6432node\microsoft\windows\currentversion\uninstall -Recurse -ErrorAction SilentlyContinue | % {if (((Get-ItemProperty -Path $_.pspath).DisplayName -like $DisplayName) -and (([version](Get-ItemProperty -Path $_.pspath).DisplayVersion) -ge [version]$Version)) {$check = $true}}
if ($check) {Write-Host "Installed"}
#>


# Non-exact version comparing should not be done as a string comparason!
# "1.10.0" -gt "1.9.0" #False
<#
$targetVersion = '4.7.01076'
$Filepathx86 = "C:\Program Files (x86)\Cisco\Cisco AnyConnect Secure Mobility Client\vpnui.exe" 
$Filepath = "C:\Program Files\Cisco\Cisco AnyConnect Secure Mobility Client\vpnui.exe" 
if(Test-Path $Filepathx86 -PathType Leaf) {
    if(([System.Version]::Parse((Get-Item $FilePathx86 -ea SilentlyContinue).VersionInfo.ProductVersionRaw)) -gt ([System.Version]::Parse($targetVersion)) ) {Write-Host "Installed"}
}
if(Test-Path $Filepath -PathType Leaf) {
    if(([System.Version]::Parse((Get-Item $FilePath -ea SilentlyContinue).VersionInfo.ProductVersionRaw)) -gt ([System.Version]::Parse($targetVersion)) ) {Write-Host "Installed"}
}
#>

$Filepath = "C:\Program Files\ITS\StartMenuLayouts\StandardWorkstationLayout.xml" 
if(Test-Path $Filepath -PathType Leaf) {
    Write-Host "Installed"
}


#$targetVersion
#$version = [System.Version]::Parse("11.00.9600.17840")