$BADUPDATEIDS=@("########-####-####-####-############")

# Script manipulated from <https://superuser.com/questions/1243011/how-to-automatically-update-all-devices-in-device-manager> 
# Credit Original Author harrymc
#


## Bypass WSUS (not necessary?)
#$currentWU = Get-ItemProperty -Path "HKLM:\SOFTWARE\Policies\Microsoft\Windows\WindowsUpdate\AU" -Name "UseWUServer" | select -ExpandProperty UseWUServer
#Set-ItemProperty -Path "HKLM:\SOFTWARE\Policies\Microsoft\Windows\WindowsUpdate\AU" -Name "UseWUServer" -Value 0
#Restart-Service wuauserv
## Revert
#Set-ItemProperty -Path "HKLM:\reg" -Name "UseWUServer" -Value $currentWU
#Restart-Service wuauserv

#HKEY_LOCAL_MACHINE\SOFTWARE\Policies\Microsoft\Windows\WindowsUpdate
#DisableWindowsUpdateAccess
#Dword 0

$serviceID = '7971f918-a847-4430-9279-4a52d1efe18d'

if( -not (get-item "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\WindowsUpdate\Services\$serviceID" -ea SilentlyContinue)) {
    $objServiceManager = New-Object -ComObject "Microsoft.Update.ServiceManager"
    $objService = $objServiceManager.AddService2($serviceID,7,"")
    $objService.PSTypeNames.Clear()
    $objService.PSTypeNames.Add('PSWindowsUpdate.WUServiceManager')
}

#restart service to pickup policies or start service and hopefully initialize database
stop-Service wuauserv
start-Service wuauserv


#search and list all missing Drivers
$Session = New-Object -ComObject Microsoft.Update.Session           
$Searcher = $Session.CreateUpdateSearcher() 
$Searcher.ServiceID = $serviceID
$Searcher.SearchScope =  1 # MachineOnly
$Searcher.ServerSelection = 3 # Third Party
$Criteria = "IsInstalled=0 and Type='Driver' and ISHidden=0"
Write-Host('Searching Driver-Updates...') -Fore Green  
$SearchResult = $Searcher.Search($Criteria)          
$Updates = $SearchResult.Updates
#Show available Drivers
$Updates | select Title, DriverModel, DriverVerDate, Driverclass, DriverManufacturer, LastDeploymentChangeTime | fl
#Download the Drivers from Microsoft
$UpdatesToDownload = New-Object -Com Microsoft.Update.UpdateColl
$updates | % { if($BADUPDATEIDS -contains $_.Identity.UpdateID ){ write-host "Skipping update identified as bad update: `"$($_.Title)`"" } else { $UpdatesToDownload.Add($_) | out-null } }
if( -not $UpdatesToDownload.Count) {
    Write-Host('No updates to download...')  -Fore Green  
} else {    
    Write-Host('Downloading Drivers...')  -Fore Green  
    $UpdateSession = New-Object -Com Microsoft.Update.Session
    $Downloader = $UpdateSession.CreateUpdateDownloader()
    $Downloader.Updates = $UpdatesToDownload
    $Downloader.Download()
    #Check if the Drivers are all downloaded and trigger the Installation
    $UpdatesToInstall = New-Object -Com Microsoft.Update.UpdateColl
    $updates | % { if($_.IsDownloaded) { $UpdatesToInstall.Add($_) | out-null } }
    Write-Host('Installing Drivers...')  -Fore Green  
    $Installer = $UpdateSession.CreateUpdateInstaller()
    $Installer.Updates = $UpdatesToInstall
    $InstallationResult = $Installer.Install()
    if($InstallationResult.RebootRequired) {  
    Write-Host('Reboot required! Rebooting…') -Fore Red  
	    #Suspend Bitlocker to allow BIOS/Firmware updates to go through
	    Suspend-BitLocker -MountPoint "C:" -RebootCount 1 -ErrorAction SilentlyContinue
	    #Shutdown /r /t 0 /d p:1:1
        exit 3010        
    } else { Write-Host('Done..') -Fore Green }
}
