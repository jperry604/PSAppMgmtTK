#Intended to be used as part of an sccm OSD task sequence
[CmdletBinding()]
param (
    [string]$Reportfolder="C:\Windows\Logs\TSSummaries",
    [string]$Reportfilename="OSDLogSummary",
    [switch]$AddRunOnce
)

# Credit to: Ansgar Wiechers
# https://stackoverflow.com/questions/23066783/how-to-strip-illegal-characters-before-trying-to-save-filenames
Function Remove-InvalidFileNameChars {
    param(
      [Parameter(Mandatory=$true,
        Position=0,
        ValueFromPipeline=$true,
        ValueFromPipelineByPropertyName=$true)]
      [String]$Name
    )
  
    $invalidChars = [IO.Path]::GetInvalidFileNameChars() -join ''
    $re = "[{0}]" -f [RegEx]::Escape($invalidChars)
    return ($Name -replace $re)
}
$Reportfilename = Remove-InvalidFileNameChars $Reportfilename


$files = @( Get-ChildItem -Path x:\windows\temp\smstslog\*smsts*.log -Recurse -ErrorAction SilentlyContinue)
$files += @( Get-ChildItem -Path x:\smstslog\*smsts*.log -Recurse  -ErrorAction SilentlyContinue) 
$files += @( Get-ChildItem -Path C:\_SMSTaskSequence\Logs\*smsts*.log -Recurse  -ErrorAction SilentlyContinue) 
$files += @( Get-ChildItem -Path $env:WINDIR\ccm\logs\*smsts*.log -Recurse  -ErrorAction SilentlyContinue) 
$files



$lines = @()
foreach ( $file1 in $files ){
    $file = [System.io.File]::Open($file1, 'Open', 'Read', 'ReadWrite')
    $reader = New-Object System.IO.StreamReader($file)
    if ($reader -ne $null) {
        while (!$reader.EndOfStream) {
            $line = $reader.ReadLine()
            if ($line.Contains(" the action")) {
                $lines += $line
            }
        }
    }
    $reader.Close()
}

#$lines

foreach ($line in $lines){
    if ($line.Contains("The execution engine ignored the failure of the action")) {
        Write-Host $line -ForegroundColor Yellow
    } elseif ($line.Contains("Successfully completed the action")) {
        Write-Host $line -ForegroundColor Green
    } elseif ($line.Contains("Failed to run the action")) {
        Write-Host $line -ForegroundColor Red
    } elseif (($line.ToString()) -like "*The condition for the action * is evaluated to be true*") {
        Write-Host $line -ForegroundColor Gray
    } else {
        Write-Host $line
    }
}

#newest at top
[array]::Reverse($lines)

#https://gist.github.com/crshnbrn66/de8fe487a66814ee35c6318d9a41a28b#file-get-ccmlog-ps1
$parsedLines = New-Object System.Collections.Generic.List[System.Object]
ForEach($l in $lines ){
    $l -match '\<\!\[LOG\[(?<Message>.*)?\]LOG\]\!\>\<time=\"(?<Time>.+)(?<TZAdjust>[+|-])(?<TZOffset>\d{2,3})\"\s+date=\"(?<Date>.+)?\"\s+component=\"(?<Component>.+)?\"\s+context="(?<Context>.*)?\"\s+type=\"(?<Type>\d)?\"\s+thread=\"(?<TID>\d+)?\"\s+file=\"(?<Reference>.+)?\"\>' | Out-Null
    if($matches)
    {
        $UTCTime = [datetime]::ParseExact($("$($matches.date) $($matches.time)$($matches.TZAdjust)$($matches.TZOffset/60)"),"MM-dd-yyyy HH:mm:ss.fffz", $null, "AdjustToUniversal")
        $LocalTime = [datetime]::ParseExact($("$($matches.date) $($matches.time)"),"MM-dd-yyyy HH:mm:ss.fff", $null)
    }
    $parsedLines.add([pscustomobject]@{
        #UTCTime = $UTCTime
        #LocalTime = $LocalTime
        DateTime = $UTCTime
        Component = $matches.component
        Message = $matches.message
        #FileName = $FileName
        #Context = $matches.context
        Type = switch ($matches.type) { 3 {"Error"}; 2 {"Warning"}; 1 {"Informational"}; default {$matches.type} }
        #TID = $matches.TI
        #Reference = $matches.reference
        
    })
}

$ReportFullPath = "$(join-path $Reportfolder $Reportfilename).html"
mkdir "$Reportfolder" -ErrorAction SilentlyContinue
"File Path: $ReportFullPath"

$myHTML = $parsedLines | convertto-html -title "OSD $(get-date -format yyyy-MM-ddTHH-mm-ss-ff)"
$myHTML | foreach {
    if ($PSItem.Contains("<td>Warning</td>")) {
        $PSItem -replace "<tr>", "<tr  style=`"background-color:Orange`">" #Yellow
    } elseif ($PSItem.Contains("Successfully completed the action")) {
        $PSItem -replace "<tr>", "<tr  style=`"background-color:#c2d2a3`">" #Green
    } elseif ($PSItem.Contains("<td>Error</td>")) {
        $PSItem -replace "<tr>", "<tr  style=`"background-color:#FF2A00`">" #Red
    } elseif ($PSItem.Contains("<td>Informational</td>")) {
        $PSItem -replace "<tr>", "<tr  style=`"background-color:LightGray`">" #Gray
    } else {
        $PSItem 
    }
} | Out-File $ReportFullPath

#Add-RunOnce to open once, but un-elevate command
    if($AddRunOnce) {
    $mydate = get-date -format yyyy-MM-ddTHH-mm-ss-ff
    $regPath = "HKLM:\Software\Microsoft\Windows\CurrentVersion\RunOnce"
    $regKey = "OpenTSLogSummary${mydate}"
    $regValue = "runas /trustlevel:0x20000 `"explorer.exe \`"$ReportFullPath\`"`""

    IF(!(Test-Path $regPath)){
        New-Item -Path $regPath -Force | Out-Null
        New-ItemProperty -Path $regPath -Name $regKey -Value $regValue -PropertyType STRING -Force | Out-Null
    } ELSE { 
        New-ItemProperty -Path $regPath -Name $regKey -Value $regValue -PropertyType STRING -Force | Out-Null
    }
}