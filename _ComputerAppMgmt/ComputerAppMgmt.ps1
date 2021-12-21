Try {
    Import-Module ActiveDirectory -erroraction stop
} catch {
    write-host "Error 'Import-Module ActiveDirectory' Suggest installing RSAT. " -ForegroundColor "red"
    timeout 10
    throw $_
    return 1
}

function Write-log {
    [CmdletBinding()]
    Param(

          [parameter(Mandatory=$true)]
          [String]$Message,

          [parameter(Mandatory=$false)]
          [String]$Component = "Default",

          [parameter(Mandatory=$false)]
          [String]$Path = (join-path (Join-path (get-item $PSScriptRoot).parent.FullName "_Logs") ([io.path]::GetFileNameWithoutExtension($PSCommandPath)  + ".log")),

          [Parameter(Mandatory=$false)]
          [ValidateSet("Info", "Warning", "Error")]
          [String]$Type = "Info",

          [Parameter(Mandatory=$false)]
          [int]$MaxSize = 100MB
    )
    write-host "Writing to $Path" -ForegroundColor "Yellow"


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




# Computer AD Groups.

#Read Multi-line input
#https://blog.danskingdom.com/powershell-multi-line-input-box-dialog-open-file-dialog-folder-browser-dialog-input-box-and-message-box/


function Get-UserInputGui([string]$Message, [string]$WindowTitle, [string]$DefaultText)
{
    Add-Type -AssemblyName System.Drawing
    Add-Type -AssemblyName System.Windows.Forms

    $GuiSizing = @' 
    {
        Buffer:10,
        HeadderHeight:20,
        InputHeight:500,
        Column1Width:150,
        Column2Width:400,
        Column3Width:300,
        ButtonHeight:25
    }
'@ | ConvertFrom-Json

    # Create the Computer Label.
    $computerLabel = New-Object System.Windows.Forms.Label
    $computerLabel.Location = New-Object System.Drawing.Size($GuiSizing.Buffer,$GuiSizing.Buffer)
    $computerLabel.Size = New-Object System.Drawing.Size($GuiSizing.Column1Width, $GuiSizing.HeadderHeight)
    $computerLabel.AutoSize = $true
    $computerLabel.Text = "Computers"

    # Create the TextBox used to capture the computers list.
    $textBox = New-Object System.Windows.Forms.TextBox
    $textBox.Location = New-Object System.Drawing.Size($GuiSizing.Buffer,($GuiSizing.Buffer + $GuiSizing.HeadderHeight) )
    $textBox.Size = New-Object System.Drawing.Size($GuiSizing.Column1Width, $GuiSizing.InputHeight)
    $textBox.AcceptsReturn = $true
    $textBox.AcceptsTab = $false
    $textBox.Multiline = $true
    $textBox.ScrollBars = 'Both'
    $textBox.Text = ""


    #$DropDown = new-object System.Windows.Forms.ComboBox
    $DropDown = new-object System.Windows.Forms.ComboBox
    $DropDown.Location = new-object System.Drawing.Size( (2 * $GuiSizing.Buffer + $GuiSizing.Column1Width) ,$GuiSizing.Buffer)
    $DropDown.Size = new-object System.Drawing.Size($GuiSizing.Column2Width, $GuiSizing.HeadderHeight )

    $DropDown.Items.Add("Use Selection Below")
    [array]$DropDownArray = "Preselection 1 (Todo)", "Preselection 2 (Todo)", "Preselection 3 (Todo)"
    ForEach ($SoftwareGroup in $GeneralSettings.PredefinedGroups.PSObject.Properties) {
        $DropDown.Items.Add($SoftwareGroup.Name)
    }
    $DropDown.SelectedIndex = 0

    

    #Create Checkbox list of Software
    $SoftwareListBox = New-Object -TypeName System.Windows.Forms.CheckedListBox;
    $SoftwareListBox.Location = New-Object System.Drawing.Size((2 * $GuiSizing.Buffer + $GuiSizing.Column1Width),($GuiSizing.Buffer + $GuiSizing.HeadderHeight) )
    $SoftwareListBox.Size = New-Object System.Drawing.Size($GuiSizing.Column2Width, $GuiSizing.InputHeight)
    $SoftwareListBox.CheckOnClick = $true
    # Populate software list
    foreach ($dir in $baseDirectory.GetDirectories() ) {
        #Skip directories that start with an underscore
        if ( $dir.Name.StartsWith("_") ) { continue }
        if ( $dir.Name -eq ".git" ) { continue }
        #Skip if exception defined
        if ( $GeneralSettings.AppMgmtExceptions.Contains($dir.Name) )  { continue }
        #Add Software to Selectable list
        $SoftwareListBox.Items.Add($dir.Name)
    }
    

    # Clear all existing selections
    $SoftwareListBox.ClearSelected();
    # Define a list of items we want to be checked

    # Create the Settings Label.
    $settingsLabel = New-Object System.Windows.Forms.Label
    $settingsLabel.Location = New-Object System.Drawing.Size((3 * $GuiSizing.Buffer + $GuiSizing.Column1Width + $GuiSizing.Column2Width),($GuiSizing.Buffer) )
    $settingsLabel.Size = New-Object System.Drawing.Size($GuiSizing.Column1Width, $GuiSizing.HeadderHeight)
    $settingsLabel.AutoSize = $true
    $settingsLabel.Text = "Settings"

    #Action Dropdown (Install/Uninstall...)
    $ActionDropDown = new-object System.Windows.Forms.ComboBox
    $ActionDropDown.Location = New-Object System.Drawing.Size( (3 * $GuiSizing.Buffer + $GuiSizing.Column1Width + $GuiSizing.Column2Width),(1 * $GuiSizing.Buffer + 1 * $GuiSizing.HeadderHeight) )
    $ActionDropDown.Size = new-object System.Drawing.Size($GuiSizing.Column3Width, $GuiSizing.HeadderHeight )
    

    [array]$DropDownArray2 = "Install", "Uninstall", "Uninstall then Reinstall", "Repair"
    ForEach ($Item in $DropDownArray2) {
        $ActionDropDown.Items.Add($Item)
    }
    $ActionDropDown.SelectedIndex = 0

    #Verbosity Dropdown (Loud / Silent)
    $VerbosityDropDown = new-object System.Windows.Forms.ComboBox
    $VerbosityDropDown.Location = New-Object System.Drawing.Size( (3 * $GuiSizing.Buffer + $GuiSizing.Column1Width + $GuiSizing.Column2Width),(2 * $GuiSizing.Buffer + 2 * $GuiSizing.HeadderHeight) )
    $VerbosityDropDown.Size = new-object System.Drawing.Size($GuiSizing.Column3Width, $GuiSizing.HeadderHeight )
    

    [array]$DropDownArray2 = "Silent", "Interactive", "NonInteractive", "ServiceUI.exe (todo)."
    ForEach ($Item in $DropDownArray2) {
        $VerbosityDropDown.Items.Add($Item)
    }
    $VerbosityDropDown.SelectedIndex = 0

    #Create Checkbox list of Settings
    $SettingsListBox = New-Object -TypeName System.Windows.Forms.CheckedListBox;
    $SettingsListBox.Location = New-Object System.Drawing.Size((3 * $GuiSizing.Buffer + $GuiSizing.Column1Width + $GuiSizing.Column2Width),(3 * $GuiSizing.Buffer + 3 * $GuiSizing.HeadderHeight) )
    $SettingsListBox.Size = New-Object System.Drawing.Size($GuiSizing.Column3Width, ($GuiSizing.InputHeight - (3 * $GuiSizing.Buffer + 2 * $GuiSizing.HeadderHeight) - ($GuiSizing.ButtonHeight)) )
    $SettingsListBox.CheckOnClick = $true
    
    #Add Settings Options
    $SettingsListBox.Items.Add("Attempt Action Now");
    $SettingsListBox.SetItemChecked($SettingsListBox.Items.IndexOf("Attempt Action Now"), $true);
    $SettingsListBox.Items.Add("Skip Action On Existing Group Members");
    $SettingsListBox.SetItemChecked($SettingsListBox.Items.IndexOf("Skip Action On Existing Group Members"), $true);
    $SettingsListBox.Items.Add("Ignore Detection");
    
    

    # Create the OK button.
    $okButton = New-Object System.Windows.Forms.Button
    $okButton.Location = New-Object System.Drawing.Size((3 * $GuiSizing.Buffer + $GuiSizing.Column1Width + $GuiSizing.Column2Width),(( 2 * $GuiSizing.Buffer +  $GuiSizing.InputHeight + $GuiSizing.HeadderHeight) - (2 * $GuiSizing.Buffer + $GuiSizing.ButtonHeight)) )
    $okButton.Size = New-Object System.Drawing.Size( (($GuiSizing.Column3Width / 2) - ($GuiSizing.Buffer)) ,$GuiSizing.ButtonHeight)
    $okButton.Text = "OK"
    $okButton.Add_Click({ $form.Tag = $textBox.Text; $form.Close() })

    # Create the Cancel button.
    $cancelButton = New-Object System.Windows.Forms.Button
    $cancelButton.Location = New-Object System.Drawing.Size((4 * $GuiSizing.Buffer + $GuiSizing.Column1Width + $GuiSizing.Column2Width + (($GuiSizing.Column3Width / 2) )),(( 2 * $GuiSizing.Buffer +  $GuiSizing.InputHeight + $GuiSizing.HeadderHeight) - (2 * $GuiSizing.Buffer + $GuiSizing.ButtonHeight)) )
    $cancelButton.Size = New-Object System.Drawing.Size( (($GuiSizing.Column3Width / 2) - ($GuiSizing.Buffer)),$GuiSizing.ButtonHeight)
    $cancelButton.Text = "Cancel"
    $cancelButton.Add_Click({ $form.Tag = $null; $form.Close() })

    # Create the form.
    $form = New-Object System.Windows.Forms.Form
    $form.Text = $WindowTitle
    $form.Size = New-Object System.Drawing.Size((6 * $GuiSizing.Buffer + $GuiSizing.Column1Width + $GuiSizing.Column2Width + $GuiSizing.Column3Width), ( 6 * $GuiSizing.Buffer + $GuiSizing.InputHeight + $GuiSizing.HeadderHeight) )
    $form.FormBorderStyle = 'FixedSingle'
    $form.StartPosition = "CenterScreen"
    $form.AutoSizeMode = 'GrowAndShrink'
    $form.Topmost = $True
    $form.AcceptButton = $okButton
    $form.CancelButton = $cancelButton
    $form.ShowInTaskbar = $true

    # Add all of the controls to the form.
    $form.Controls.Add($computerLabel) #0
    $form.Controls.Add($textBox) #1
    $Form.Controls.Add($DropDown) #2
    $Form.Controls.Add($SoftwareListBox); #3
    $form.Controls.Add($settingsLabel) #4
    $form.Controls.Add($ActionDropDown) #5
    $form.Controls.Add($VerbosityDropDown) #6
    $form.Controls.Add($SettingsListBox) #7
    $form.Controls.Add($okButton) #8
    $form.Controls.Add($cancelButton) #9

    # Initialize and show the form.
    $form.Add_Shown({$form.Activate()})
    $form.ShowDialog() > $null  # Trash the text of the button that was clicked.

    # Return the text that the user entered.
    return $form
}



# ///////////////////////////////////////////////////////////////////////////////
# Start Main
# \\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\

$GeneralSettings = Get-Content -Path (join-path $PSScriptRoot Generalsettings.json) | ConvertFrom-Json
$baseDirectory = (get-item $PSScriptRoot).parent
$AppMgmtOU = Get-ADOrganizationalUnit $GeneralSettings.AppMgmtOU

$RegPSAppMgmtTKKey = "HKLM:\Software\ITS\PSAppMgmtTK"
$RegPSAppMgmtTKValue = "BaseDirectory"
$RegPSAppMgmtTKData = $baseDirectory.FullName.toString()
write-host "Setting ${RegPSAppMgmtTKKey}\${BaseDirectory}  -> $RegPSAppMgmtTKData" -ForegroundColor "Yellow"
Write-Regisry -registryPath $RegPSAppMgmtTKKey -Name $RegPSAppMgmtTKValue -Data $RegPSAppMgmtTKData -Type "String"




$multiLineText = Get-UserInputGui -Message "Please enter some text. It can be multiple lines" -WindowTitle "AppMgmt" -DefaultText ""
if ( $null -eq $multiLineText.Tag ) { 
    Write-Host "You clicked Cancel" 
    return
} 

$GuiInput = @{
    computers = $multiLineText.Controls[1].Lines;
    SoftwareGroup = $multiLineText.Controls[2].SelectedItem
    customSelectedSoftware = $multiLineText.Controls[3].CheckedItems
    Action = $multiLineText.Controls[5].SelectedItem
    Verbosity = $multiLineText.Controls[6].SelectedItem
    Settings = $multiLineText.Controls[7].CheckedItems
}

#debug
#$GuiInput #testing


#Locate all the computer objects in AD. Warn if not found.
$ADComputers = New-Object System.Collections.Generic.List[System.Object]
foreach ($comp in $GuiInput.computers){
    if ( [string]::IsNullOrEmpty( $comp) -or (-not $comp.Trim()) ) { continue } #ignore blank lines 
    $found=0
    foreach ($OU in $GeneralSettings.WorkstationOUs){
        try{
            $ADComp = Get-ADComputer -SearchBase (Get-ADOrganizationalUnit $OU) -filter "Name -eq '$($comp)'"
            if ($ADComp) {
                $found++
                $ADComputers.add($ADComp)
            }
        } catch {
            continue
        }
    }
    if ($found -ne 1 ) {
        write-host "Warning $comp found $found entries in AD." -ForegroundColor "Yellow"
    }
}
#$ADComputers #testing


#Resolve software group selection
$SoftwareList = New-Object System.Collections.Generic.List[System.Object]
if ($GuiInput.SoftwareGroup -eq "Use Selection Below") {
    $SoftwareList =  $GuiInput.customSelectedSoftware 
} else {
    $SoftwareList =  $GeneralSettings.PredefinedGroups.($GuiInput.SoftwareGroup)
}        
#IdentifyProduction Packages and versioins etc.
$ProductionPackage = @{}
foreach ($software in $SoftwareList) {
    try{
        
        $PathToApp = join-path $baseDirectory $software
        $AppSettings = Get-Content -Path (join-path $PathToApp "AppSettings.json") | ConvertFrom-Json
        
        if ( $AppSettings.ProductionPackages ) { 
            foreach($productionPackageJson in $AppSettings.ProductionPackages){
                
                $Package = get-item (join-path $PathToApp $productionPackageJson)
                
                $ProductionPackage.add($software, $Package)        
            }

        } else {
            throw "no packages found"
        }
    } catch {
        write-host "Warning no production package found for $software." -ForegroundColor "Yellow"
    }
    #Todo Identify pre-requiset software and warn. Don't add it to install... If two versions for two OS's / scenarios exist. The pre-reqs might also be scenario specific.
}
$ProductionPackage 


#Find the AD groups based on software Selection and Action. Warn if group does not exist.
$ADGroups = @{}
foreach ($software in $SoftwareList) {
    $ADGroup = @{
        install = Get-ADGroup -SearchBase $AppMgmtOU -Filter "Name -eq 'APPi-$($software)'"
        uninstall = Get-ADGroup -SearchBase $AppMgmtOU -Filter "Name -eq 'APPu-$($software)'"
        available = Get-ADGroup -SearchBase $AppMgmtOU -Filter "Name -eq 'APPa-$($software)'"
    }

    switch ($GuiInput.Action) {
        "Install" { if (-not $ADGroup.install) {write-host "Warning install group not found for $($software)" -ForegroundColor "Yellow"} }
        "Uninstall" { if (-not $ADGroup.uninstall) {write-host "Warning uninstall group not found for $($software)" -ForegroundColor "Yellow"} }
        "Uninstall then Reinstall" { if (-not $ADGroup.install) {write-host "Warning install group not found for $($software)" -ForegroundColor "Yellow"} }
        "Repair" { if (-not $ADGroup.install) {write-host "Warning install group not found for $($software)" -ForegroundColor "Yellow"} }
    }
    $ADGroups.add($software,$ADGroup)
}

#foreach ($softwares in $ADGroups) {$softwares} #testing


#Confirm Action
    #Action
    #settings
    #computers | Groups
    #OK | Cancel

#Log starting attempt


#For Each Software
foreach ($software in $SoftwareList) {
    $AppMgmtADGroup = $ADGroups[$software]
    switch ($GuiInput.Action) {
        "Install" { 
            if ((-not $AppMgmtADGroup.install) -and (-not $ProductionPackage[$software])) {
                write-host "$software has no production package and no AD group." -ForegroundColor "Red"
                continue
            }        
        } "Uninstall" { 
            if((-not$AppMgmtADGroup.uninstall) -and (-not $ProductionPackage[$software])) {
                write-host "$software has no production package and no AD group." -ForegroundColor "Red"
                continue
            }
        } "Uninstall then Reinstall" {
            if (-not $ProductionPackage[$software]) {
                write-host "$software has no production package." -ForegroundColor "Red"
                continue
            }        
        } "Repair" {
            if (-not $ProductionPackage[$software]) {
                write-host "$software has no production package." -ForegroundColor "Red"
                continue
            }
        }
    }

    Try { $Installmembers = Get-ADGroupMember -Identity $AppMgmtADGroup.install -Recursive
    } catch {$Installmembers = $null}
    Try { $Uninstallmembers = Get-ADGroupMember -Identity $AppMgmtADGroup.uninstall -Recursive
    } catch {$Uninstallmembers = $null}
    


    #For Each Computer
    foreach ($computer in $ADComputers){
        if ( $Installmembers ) { $computerIsMemberInstall = $Installmembers | Where-Object {$_.distinguishedName.tostring() -eq $computer.distinguishedName}    
        } else { $computerIsMemberInstall = $false }
        if ( $Uninstallmembers ) { $computerIsMemberUninstall = $Uninstallmembers | Where-Object {$_.distinguishedName.tostring() -eq $computer.distinguishedName}    
        } else { $computerIsMemberUninstall = $false }
        
        


        
        switch ($GuiInput.Action) {
            "Install" {
                if ($computerIsMemberUninstall) {
                    write-host "Warning computer in uninstall group $($computer.DistinguishedName)  skipping $software." -ForegroundColor "Yellow"
                    continue
                }

                if ($computerIsMemberInstall -and $GuiInput.Settings -contains "Skip Action On Existing Group Members" ) {
                    #write-host "Warning computer already in install group $($computer.DistinguishedName)  skipping $software." -ForegroundColor "Yellow"
                    continue
                } else {
                    #Add computer to group
                    if ($AppMgmtADGroup.install) {
                        Try {  
                            Add-AdGroupMember  $AppMgmtADGroup.install -members $computer
                        } catch { 
                            write-host "Warning failed to add computer $($computer.DistinguishedName) to group $($AppMgmtADGroup.install.DistinguishedName)   $($_.exception.message)" -ForegroundColor "Yellow" 
                        }
                    } 
                }

                
                if ($GuiInput.Settings -contains "Attempt Action Now") {
                    foreach ($package in  $ProductionPackage[$software] ) {
                        
                        #if Settings -> Checked items includes "Attempt Action Now"
                        #Powershell
                            #Todo check compatability
                            # [System.Environment]::OSVersion.Version
                            # https://docs.microsoft.com/en-US/windows/win32/api/sysinfoapi/nf-sysinfoapi-getproductinfo


                            # Skip if installation in progress reg already set?
                            # Robocopy C:\Windows\temp
                            # Try{} Run install and store exit code.
                            # Remove Copy
                        #can't robocopy as part of Invoke-Command because of the Dual Kerberose limitations.
                        # does mean that copy goes through admin's computer. (Recommend not running over vpn.)

                        
                        #$detectionScriptContent = get-content (join-path $package.FullName "InstallStateDetection.ps1") | Out-String

                        $src= $package.FullName 
                        $dst=Join-Path ("\\$($computer.DNSHostName)\C$\Windows\temp") $package.Name
                        Write-host "Copy Detection Script from $(${src}) to $(${dst})"
                        robocopy.exe "${src}" "${dst}" "InstallStateDetection.ps1" /R:1 /W:1 /NFL /NDL /nc /ns /np # /NJH /NJS
                        if ( $lastexitcode -ge 8) { #robocopy exit code 8 or above is error https://ss64.com/nt/robocopy-exit.html
                            Write-Error "Failed to copy files from $(${src}) to $(${dst}) $lastexitcode" 
                            continue
                        }

                        $script = { param($packagePath, $action, $verbosity)
                            # Call exe and combine all output streams so nothing is missed
                            $ReturnData= New-Object -TypeName PSCustomObject -Property @{StdOut=$null; StdErr=$null; ExitCode=$null}
                            
                            # Save lastexitcode right after call to exe completes
                            try {
                                $deploymentexe= "C:\windows\system32\WindowsPowerShell\v1.0\powershell.exe"
                                write-host "Running detection Script"
                                $deployargs = "-ExecutionPolicy", "bypass", "-File", "`"$(Join-Path $packagePath "InstallStateDetection.ps1")`""
                                <#$packageproc = start-process -FilePath $deploymentexe -ArgumentList $deployargs -Wait -PassThru
                                $ReturnData.add($packageproc.StandardError)
                                $ReturnData.add($packageproc.StandardOutput)
                                $ReturnData.add($packageproc.ExitCode)
                                #>
                                $pinfo = New-Object System.Diagnostics.ProcessStartInfo
                                $pinfo.FileName = $deploymentexe
                                $pinfo.RedirectStandardError = $true
                                $pinfo.RedirectStandardOutput = $true
                                $pinfo.UseShellExecute = $false
                                $pinfo.Arguments = $deployargs
                                $p = New-Object System.Diagnostics.Process
                                $p.StartInfo = $pinfo
                                $p.Start() | Out-Null
                                $p.WaitForExit()
                                $ReturnData.StdOut = $p.StandardOutput.ReadToEnd()
                                $ReturnData.StdErr = $p.StandardError.ReadToEnd()
                                $ReturnData.ExitCode = $p.ExitCode

                                #remove local copy of package
                                #Remove-Item -LiteralPath $packagePath -Force -Recurse

                            } catch {
                                Write-Host $_.exception.message
                                throw $_
                            }
                            # Return the output and the exitcode using a hashtable
                            New-Object -TypeName PSCustomObject -Property @{Host=$env:computername; ReturnData=$ReturnData}
                        }
                        # # --> End of section to run on remote computer


                        $results = Invoke-Command -ComputerName $computer.DNSHostName -ScriptBlock $script -ArgumentList (Join-Path "C:\Windows\temp" $package.Name), $GuiInput.Action, $GuiInput.Verbosity
                        $results | Select-Object Host, ReturnData | Format-List
                        if( $GuiInput.Settings -contains "Ignore Detection Results"){
                            write-host "Ignoring detection"
                        } elseif (($results.ReturnData.StdOut -eq "") -and ($results.ReturnData.StdErr -eq "") -and ($results.ReturnData.ExitCode -eq 0)) {
                            #write-host "Attempt install"
                        }elseif (($results.ReturnData.ExitCode -ne 0) -or ($results.ReturnData.StdErr -ne "")) {
                            Write-Error "Detection Script failed" 
                            continue
                        } else {
                            write-host "Detected as installed"
                            continue
                        }


                        $src=$package.FullName
                        $dst=Join-Path ("\\$($computer.DNSHostName)\C$\Windows\temp") $package.Name
                        Write-host "Copy files from $(${src}) to $(${dst})"
                        robocopy.exe "${src}" "${dst}" /E /Purge /R:3 /W:3 /NFL /NDL /nc /ns /np # /NJH /NJS
                        if ( $lastexitcode -ge 8) { #robocopy exit code 8 or above is error https://ss64.com/nt/robocopy-exit.html
                            Write-Error "Failed to copy files from $(${src}) to $(${dst}) $lastexitcode" 
                            continue
                        }

                        

                        # # --> Start of section to run on remote computer
                        $script = { param($packagePath, $action, $verbosity)
                            # Call exe and combine all output streams so nothing is missed
                            $exitCode = $null
                            $ReturnData= New-Object System.Collections.Generic.List[System.Object]
                            
                            # Save lastexitcode right after call to exe completes
                            try {
                                $deploymentexe=Join-Path $packagePath "ADTP\Deploy-Application.exe"
                                write-host "$deploymentexe -DeploymentType $action -DeployMode $verbosity"
                                $deployargs = "-DeploymentType", "$action", "-DeployMode", "$verbosity"
                                $packageproc = start-process -FilePath $deploymentexe -ArgumentList $deployargs -Wait -PassThru
                                $ReturnData.add($packageproc.StandardError)
                                $ReturnData.add($packageproc.StandardOutput)
                                $ReturnData.add($packageproc.ExitCode)

                                #remove local copy of package
                                Remove-Item -LiteralPath $packagePath -Force -Recurse

                            } catch {
                                Write-Host $_.exception.message
                                throw $_
                            }
                            # Return the output and the exitcode using a hashtable
                            New-Object -TypeName PSCustomObject -Property @{Host=$env:computername; ReturnData=$ReturnData; ExitCode=$packageproc.ExitCode}
                        }
                        # # --> End of section to run on remote computer


                        #Log Results
                        write-host $GuiInput.Action $package.FullName on $computer.DNSHostName
                        $results = Invoke-Command -ComputerName $computer.DNSHostName -ScriptBlock $script -ArgumentList (Join-Path "C:\Windows\temp" $package.Name), $GuiInput.Action, $GuiInput.Verbosity
                        $results | Select-Object Host, ReturnData, ExitCode | Format-List
                    }
                }
            } "Uninstall" {
                if ($computerIsMemberInstall) {
                    if ($AppMgmtADGroup.install) {
                        Try {  
                            Remove-AdGroupMember $AppMgmtADGroup.install -members $computer -Confirm:$false
                        } catch { 
                            write-host "Warning failed to remove computer $($computer.DistinguishedName) to group $($AppMgmtADGroup.install.DistinguishedName)   $($_.exception.message)" -ForegroundColor "Yellow" 
                        }
                    } 
                }

                if ($computerIsMemberUninstall -and $GuiInput.Settings -contains "Skip Action On Existing Group Members" ) {
                    #write-host "Warning computer already in install group $($computer.DistinguishedName)  skipping $software." -ForegroundColor "Yellow"
                    continue
                } else {
                    #Add computer to group
                    if ($AppMgmtADGroup.uninstall) {
                        Try {  
                            Add-AdGroupMember  $AppMgmtADGroup.uninstall -members $computer
                        } catch { 
                            write-host "Warning failed to add computer $($computer.DistinguishedName) to group $($AppMgmtADGroup.install.DistinguishedName)   $($_.exception.message)" -ForegroundColor "Yellow" 
                        }
                    } 
                }

                
                if ($GuiInput.Settings -contains "Attempt Action Now") {

                    foreach ($package in  $ProductionPackage[$software] ) {
                        
                        #if Settings -> Checked items includes "Attempt Action Now"
                        #Powershell
                            #Todo check compatability
                            # [System.Environment]::OSVersion.Version
                            # https://docs.microsoft.com/en-US/windows/win32/api/sysinfoapi/nf-sysinfoapi-getproductinfo


                            # Skip if installation in progress reg already set?
                            # Robocopy C:\Windows\temp
                            # Try{} Run install and store exit code.
                            # Remove Copy
                        #can't robocopy as part of Invoke-Command because of the Dual Kerberose limitations.
                        # does mean that copy goes through admin's computer. (Recommend not running over vpn.)
                        $src=$package.FullName
                        $dst=Join-Path ("\\$($computer.DNSHostName)\C$\Windows\temp") $package.Name
                        Write-host "Copy files from $(${src}) to $(${dst})"
                        robocopy.exe "${src}" "${dst}" /E /Purge /R:3 /W:1 /NFL /NDL /nc /ns /np # /NJH /NJS
                        if ( $lastexitcode -ge 8) { #robocopy exit code 8 or above is error https://ss64.com/nt/robocopy-exit.html
                            Write-Error "Failed to copy files from $(${src}) to $(${dst}) $lastexitcode" 
                            continue
                        }

                        # # --> Start of section to run on remote computer
                        $script = { param($packagePath, $action, $verbosity)
                            # Call exe and combine all output streams so nothing is missed
                            $exitCode = $null
                            $ReturnData= New-Object System.Collections.Generic.List[System.Object]
                            
                            # Save lastexitcode right after call to exe completes
                            try {
                                $deploymentexe=Join-Path $packagePath "ADTP\Deploy-Application.exe"
                                write-host "$deploymentexe -DeploymentType $action -DeployMode $verbosity"
                                $deployargs = "-DeploymentType", "$action", "-DeployMode", "$verbosity"
                                $packageproc = start-process -FilePath $deploymentexe -ArgumentList $deployargs -Wait -PassThru
                                $ReturnData.add($packageproc.StandardError)
                                $ReturnData.add($packageproc.StandardOutput)
                                $ReturnData.add($packageproc.ExitCode)
                                
                                #remove local copy of package
                                Remove-Item -LiteralPath $packagePath -Force -Recurse

                            } catch {
                                Write-Host $_.exception.message
                                throw $_
                            }
                            # Return the output and the exitcode using a hashtable
                            Return New-Object -TypeName PSCustomObject -Property @{Host=$env:computername; ReturnData=$ReturnData; ExitCode=$packageproc.ExitCode}
                        }
                        # # --> End of section to run on remote computer


                        #Log Results
                        write-host $GuiInput.Action $package.FullName on $computer.DNSHostName
                        $results = Invoke-Command -ComputerName $computer.DNSHostName -ScriptBlock $script -ArgumentList (Join-Path "C:\Windows\temp" $package.Name), $GuiInput.Action, $GuiInput.Verbosity
                        $results | Select-Object Host, ReturnData, ExitCode | Format-List
                    }
                }
            } "Repair" {
                #warn if not in install group
                if ($computerIsMemberUninstall) {
                    write-host "Warning computer in uninstall group $($computer.DistinguishedName)  skipping $software." -ForegroundColor "Yellow"
                    continue
                }

                
                if ($GuiInput.Settings -contains "Attempt Action Now") {
                    foreach ($package in  $ProductionPackage[$software] ) {
                        
                        #if Settings -> Checked items includes "Attempt Action Now"
                        #Powershell
                            #Todo check compatability
                            # [System.Environment]::OSVersion.Version
                            # https://docs.microsoft.com/en-US/windows/win32/api/sysinfoapi/nf-sysinfoapi-getproductinfo


                            # Skip if installation in progress reg already set?
                            # Robocopy C:\Windows\temp
                            # Try{} Run install and store exit code.
                            # Remove Copy
                        #can't robocopy as part of Invoke-Command because of the Dual Kerberose limitations.
                        # does mean that copy goes through admin's computer. (Recommend not running over vpn.)
                        $src=$package.FullName
                        $dst=Join-Path ("\\$($computer.DNSHostName)\C$\Windows\temp") $package.Name
                        Write-host "Copy files from $(${src}) to $(${dst})"
                        robocopy.exe "${src}" "${dst}" /E /Purge /R:3 /W:1 /NFL /NDL /nc /ns /np # /NJH /NJS
                        if ( $lastexitcode -ge 8) { #robocopy exit code 8 or above is error https://ss64.com/nt/robocopy-exit.html
                            Write-Error "Failed to copy files from $(${src}) to $(${dst}) $lastexitcode" 
                            continue
                        }

                        # # --> Start of section to run on remote computer
                        $script = { param($packagePath, $action, $verbosity)
                            # Call exe and combine all output streams so nothing is missed
                            $exitCode = $null
                            $ReturnData= New-Object System.Collections.Generic.List[System.Object]
                            
                            # Save lastexitcode right after call to exe completes
                            try {
                                $deploymentexe=Join-Path $packagePath "ADTP\Deploy-Application.exe"
                                write-host "$deploymentexe -DeploymentType $action -DeployMode $verbosity"
                                $deployargs = "-DeploymentType", "$action", "-DeployMode", "$verbosity"
                                $packageproc = start-process -FilePath $deploymentexe -ArgumentList $deployargs -Wait -PassThru
                                $ReturnData.add($packageproc.StandardError)
                                $ReturnData.add($packageproc.StandardOutput)
                                $ReturnData.add($packageproc.ExitCode)

                                #remove local copy of package
                                Remove-Item -LiteralPath $packagePath -Force -Recurse

                            } catch {
                                Write-Host $_.exception.message
                                throw $_
                            }
                            # Return the output and the exitcode using a hashtable
                            New-Object -TypeName PSCustomObject -Property @{Host=$env:computername; ReturnData=$ReturnData; ExitCode=$packageproc.ExitCode}
                        }
                        # # --> End of section to run on remote computer


                        #Log Results
                        write-host $GuiInput.Action $package.FullName on $computer.DNSHostName
                        $results = Invoke-Command -ComputerName $computer.DNSHostName -ScriptBlock $script -ArgumentList (Join-Path "C:\Windows\temp" $package.Name), $GuiInput.Action, $GuiInput.Verbosity
                        $results | Select-Object Host, ReturnData, ExitCode | Format-List
                    }
                }
            } "Uninstall then Reinstall" {
                #Add to install group
                #warn if not in install group
                if ($computerIsMemberUninstall) {
                    write-host "Warning computer in uninstall group $($computer.DistinguishedName)  skipping $software." -ForegroundColor "Yellow"
                    continue
                }

                if ($GuiInput.Settings -contains "Attempt Action Now") {
                    foreach ($package in  $ProductionPackage[$software] ) {
                        
                        #if Settings -> Checked items includes "Attempt Action Now"
                        #Powershell
                            #Todo check compatability
                            # [System.Environment]::OSVersion.Version
                            # https://docs.microsoft.com/en-US/windows/win32/api/sysinfoapi/nf-sysinfoapi-getproductinfo


                            # Skip if installation in progress reg already set?
                            # Robocopy C:\Windows\temp
                            # Try{} Run install and store exit code.
                            # Remove Copy
                        #can't robocopy as part of Invoke-Command because of the Dual Kerberose limitations.
                        # does mean that copy goes through admin's computer. (Recommend not running over vpn.)
                        $src=$package.FullName
                        $dst=Join-Path ("\\$($computer.DNSHostName)\C$\Windows\temp") $package.Name
                        Write-host "Copy files from $(${src}) to $(${dst})"
                        robocopy.exe "${src}" "${dst}" /E /Purge /R:3 /W:1 /NFL /NDL /nc /ns /np # /NJH /NJS
                        if ( $lastexitcode -ge 8) { #robocopy exit code 8 or above is error https://ss64.com/nt/robocopy-exit.html
                            Write-Error "Failed to copy files from $(${src}) to $(${dst}) $lastexitcode" 
                            continue
                        }

                        # # --> Start of section to run on remote computer
                        $script = { param($packagePath, $action, $verbosity)
                            # Call exe and combine all output streams so nothing is missed
                            $exitCode = $null
                            $ReturnData= New-Object System.Collections.Generic.List[System.Object]
                            
                            # Save lastexitcode right after call to exe completes
                            try {
                                $action = "uninstall"
                                $deploymentexe=Join-Path $packagePath "ADTP\Deploy-Application.exe"
                                write-host "$deploymentexe -DeploymentType $action -DeployMode $verbosity"
                                $deployargs = "-DeploymentType", "$action", "-DeployMode", "$verbosity"
                                $packageproc = start-process -FilePath $deploymentexe -ArgumentList $deployargs -Wait -PassThru
                                $ReturnData.add($packageproc.StandardError)
                                $ReturnData.add($packageproc.StandardOutput)
                                $ReturnData.add($packageproc.ExitCode)

                                $action = "install"
                                write-host "$deploymentexe -DeploymentType $action -DeployMode $verbosity"
                                $deployargs = "-DeploymentType", "$action", "-DeployMode", "$verbosity"
                                $packageproc = start-process -FilePath $deploymentexe -ArgumentList $deployargs -Wait -PassThru
                                $ReturnData.add($packageproc.StandardError)
                                $ReturnData.add($packageproc.StandardOutput)
                                $ReturnData.add($packageproc.ExitCode)

                                #remove local copy of package
                                Remove-Item -LiteralPath $packagePath -Force -Recurse

                            } catch {
                                Write-Host $_.exception.message
                                throw $_
                            }
                            # Return the output and the exitcode using a hashtable
                            New-Object -TypeName PSCustomObject -Property @{Host=$env:computername; ReturnData=$ReturnData; ExitCode=$packageproc.ExitCode}
                        }
                        # # --> End of section to run on remote computer


                        #Log Results
                        write-host $GuiInput.Action  $package.FullName on $computer.DNSHostName
                        $results = Invoke-Command -ComputerName $computer.DNSHostName -ScriptBlock $script -ArgumentList (Join-Path "C:\Windows\temp" $package.Name), $GuiInput.Action, $GuiInput.Verbosity
                        $results | Select-Object Host, ReturnData, ExitCode | Format-List
                        $results.ReturnData | Format-List
                    }
                }
            }
        }
    }
}



pause

