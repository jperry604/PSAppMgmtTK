# https://www.joseespitia.com/2020/05/08/automatically-update-or-remove-an-application-in-all-of-your-configmgr-task-sequences/
# Jose Espitia
# May 8th 2020



Function ReplaceApplicationInTaskSequences {

    [CmdletBinding()]

    param (
        $OldApplication, #= Get-CMApplication "$OldApplicationName"
        $NewApplication #Get-CMApplication "$NewApplicationName"
    )
    $Remove=$false
  
    # Get all task sequences that have the old application as a reference
    $TaskSequences = Get-CMTaskSequence | Where-Object { $_.References.Package -eq $OldApplication.ModelName }
    
    If($TaskSequences) {
    
        ForEach ($TaskSequence in $TaskSequences) {
    
            Write-Host "Updating $($TaskSequence.Name)"
    
            # Get all install application steps
            $InstallApplicationSteps = (Get-CMTSStepInstallApplication -InputObject (Get-CMTaskSequence -Name $TaskSequence.Name)).Name
    
            ForEach($InstallApplicationStep in $InstallApplicationSteps) {
                
                # Get a list of applications that are in the install application step
                $ApplicationList = (Get-CMTSStepInstallApplication -InputObject $TaskSequence -StepName "$InstallApplicationStep").ApplicationName.Split(",")
    
                # Get application steps that reference the old application
                If($OldApplication.ModelName -in $ApplicationList) {
                    "found"
                    $OldApplication.ModelName
    
                    # Try to replace the old application with the new application
                    Try {   
                        If($Remove -eq $False) {
                            $ModelNames = $ApplicationList.Replace($OldApplication.ModelName,$NewApplication.ModelName)
                        }
                        Else {
    
                            $ModelNames = $ApplicationList | Where-Object { $_ -ne $OldApplication.ModelName }
    
                        }
                    }
                    Catch {
    
                        Write-Host "Failed to replace or remove old app"
                        Break
    
                    }
    
                    # Add the new application to the application step
                    Write-Host "- Updating Step $InstallApplicationStep"
                    Set-CMTSStepInstallApplication -InputObject $TaskSequence -StepName "$InstallApplicationStep" -Application ($ModelNames | ForEach { Get-CMApplication -ModelName $_ })
    
                }
    
            }
    
        }
    
    }
    Else {
    
        Write-Host "Could not locate the application in any task sequence!"
    
    }
}