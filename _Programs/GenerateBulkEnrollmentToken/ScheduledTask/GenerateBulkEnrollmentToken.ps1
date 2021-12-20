param(
  [parameter(Mandatory=$true)]
  [string]$MP= "https://CONTOSO.CLOUDAPP.NET/CCM_Proxy_MutualAuth/72186325152220500",
  [parameter(Mandatory=$true)]
  [string]$CCMHOSTNAME= "CONTOSO.CLOUDAPP.NET/CCM_Proxy_MutualAuth/72186325152220500",
  [string]$CfgMgrPath = "C:\Program Files\Microsoft Configuration Manager",
  [string]$OutputLocation = "\\localhost\SOURCES\AppInstallersManaged\_Programs\GenerateBulkEnrollmentToken\Package"
)
[string]$ErrorActionPreference = "Stop"

function Write-log {
  [CmdletBinding()]
  Param(

        [parameter(Mandatory=$true)]
        [String]$Message,

        [parameter(Mandatory=$false)]
        [String]$Component = "Default",

        [parameter(Mandatory=$false)]
        [String]$Path = (join-path "$CfgMgrPath\logs\" ([io.path]::GetFileNameWithoutExtension($PSCommandPath)  + ".log")),

        [Parameter(Mandatory=$false)]
        [ValidateSet("Info", "Warning", "Error")]
        [String]$Type = "Info",

        [Parameter(Mandatory=$false)]
        [int]$MaxSize = 200KB
  )

  switch ($Type) {
      "Info" { [int]$Type = 1 }
      "Warning" { [int]$Type = 2 }
      "Error" { [int]$Type = 3 }
  }

  # Create a log entry
  $Content = "<![LOG[$Message]LOG]!>" +`
      "<time=`"$(Get-Date -Format "HH:mm:ss.ffffff")`" " +`
      "date=`"$(Get-Date -Format "M-d-yyyy")`" " +`
      "component=`"$Component`" " +`
      "context=`"$([System.Security.Principal.WindowsIdentity]::GetCurrent().Name)`" " +`
      "type=`"$Type`" " +`
      "thread=`"$([Threading.Thread]::CurrentThread.ManagedThreadId)`" " +`
      "file=`"`">"

  
  #Handle Rollover of size
  if((Test-Path -Path $Path)){
      $CurrentLog = Get-Item -Path $Path
      if($CurrentLog.Length -gt $MaxSize){
          $PathRollover = "${Path}.old"
          if(Test-Path -Path $PathRollover){
              Remove-Item -Path $PathRollover
          }
          Rename-Item -Path $Path -NewName $PathRollover
      }
  }
  # Write the line to the log file
  New-Item -path (Split-Path -Path $Path) -type directory -Force | Out-Null
  Add-Content -Path $Path -Value $Content    

}


Write-log -Message "Started using: $CfgMgrPath"


$Res = & "$(join-path $CfgMgrPath "bin\X64\bulkregistrationtokentool.exe")" /new 
$siteCode = Get-ItemPropertyValue "HKLM:\Software\Microsoft\SMS\Identification\" -name "Site Code"

Write-log -Message "Started using: $CfgMgrPath"



$Res | ForEach-Object {
  If ($_ -match '^[A-Za-z0-9-_=]+\.[A-Za-z0-9\-_=]+\.[A-Za-z0-9\-_=]+$') {
    $BulkRegistrationToken = $_
  }
}



$src=join-path $CfgMgrPath "Client"
$dst=$OutputLocation
Write-Log -Message "Copying files src: $src" -ErrorAction 'Continue'
Write-Log -Message "Copying files dst: $dst" -ErrorAction 'Continue'
robocopy.exe "${src}" "${dst}" ccmsetup.exe /E /Purge /R:2 /W:1
if ( $lastexitcode -ge 8) { #robocopy exit code 8 or above is error https://ss64.com/nt/robocopy-exit.html
    Write-Log -Message "Error: Failed to copy files from ${src} to ${dst}    Exited: $lastexitcode" -ErrorAction 'Continue'
    throw "Failed to copy files from $(${src}) to $(${dst}) $lastexitcode"
} else {
    Write-Log -Message "Successfully robocopied files to $src" -ErrorAction 'Continue'
}

$setupString = "`"%~dp0ccmsetup.exe`" /forceinstall SMSSiteCode=$siteCode /mp:$MP CCMHOSTNAME=$CCMHOSTNAME regtoken=$BulkRegistrationToken" 
$setupString | Out-File (Join-path $OutputLocation "ccmsetupInternetClient.bat") -Encoding ASCII


"#/mp:%CCMSETUP_MP% CCMHOSTNAME=%CCMSETUP_CCMHOSTNAME% /regtoken:%CCMSETUP_regtoken%
# Create an object to access the task sequence environment
`$tsenv = New-Object -ComObject Microsoft.SMS.TSEnvironment
`$tsenv.Value(`"CCMSETUP_MP`") = `"$MP`"
`$tsenv.Value(`"_SMSTSMP`") = `"$MP`"
`$tsenv.Value(`"CCMSETUP_CCMHOSTNAME`") = `"$CCMHOSTNAME`"
`$tsenv.Value(`"CCMSETUP_regtoken`") = `"$BulkRegistrationToken`"
"  | Out-File (Join-path $OutputLocation "SetEnvironmentVariablesForCCMSetupDuringTS.ps1")

Write-log -Message "Package has been updated at location: $OutputLocation"