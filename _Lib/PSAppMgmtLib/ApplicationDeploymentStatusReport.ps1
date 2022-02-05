# https://model-technology.com/blog/reporting-on-sccm-application-deployment-progress-with-powershell/
# December 19, 2018
# Reporting on SCCM Application Deployment Progress with Powershell
# by steve bowman

#Modified to accept WMI namespace parameter

Function Get-WindowsErrorMessage {

    [CmdletBinding()]

    param (
        $ErrorCode ,
        $ErrorSource = "Windows",
        $SimpleOutput
    )

    #This error code was generated from the Windows Exception Library
    If ($ErrorSource -eq "Windows") {
        $ErrorMessage = [ComponentModel.Win32Exception]$ErrorCode
    }


    #Write Output of Function
    If ($SimpleOutput) {
        Write-Output $ErrorMessage
    }
    Else {
        Write-Output "$ErrorSource Error $($ErrorCode): $($ErrorMessage.Message)"

    }
}

Function Get-CMAppDeploymentReport {

    param(
        [ValidateSet("Summary","Detail","Both")]
        $DetailLevel,
        [ValidateSet("Object","Text")]
        $OutputType,
        $AssignmentID,
        $ChooseFromGrid,
        $Server="localhost",
        [String]$Namespace
        
    )
    Push-Location
    cd C:\

    #Select Deployment to Report on
    if($ChooseFromGrid) {

        $DeploymentList = Get-WMIObject -Computer $Server -Namespace $Namespace -class SMS_DeploymentSummary -Filter "FeatureType = 1"

        $SelectedDeployment = $DeploymentList | Select-Object AssignmentID, CollectionName, SoftwareName, @{Name="DeploymentTime";Expression={$([Management.ManagementDateTimeConverter]::toDateTime($_.DeploymentTime))}},@{Name="DeploymentIntent";Expression={If ($_.DeploymentIntent -eq 1){"Required"}elseif($_.DeploymentIntent -eq 2){"Available"}else{"Unknown"}}},@{Name="EnforcementDeadline";Expression={$([Management.ManagementDateTimeConverter]::toDateTime($_.EnforcementDeadline))}} | Out-GridView -OutputMode Single -Title "Select a Deployment to Report on"


        $AssignmentID = $SelectedDeployment.AssignmentID

    }

    #Get Summary Data
    $Summary = Get-WMIObject -Computer $Server -Namespace $Namespace -class SMS_DeploymentSummary -Filter "AssignmentID = $AssignmentID and FeatureType = 1"

    $CollectionInfo = Get-WMIObject -Computer $Server -Namespace $Namespace -Class SMS_Collection -Filter "CollectionID = ""$($Summary.CollectionID)"""

    If ($CollectionInfo.CollectionType -eq 2) {$CollectionType = "User"}elseif($CollectionInfo.CollectionType -eq 1){$CollectionType = "Device"}else{$CollectionType = "Other"}

    $SummaryTable = $Summary |Select-Object AssignmentID, CollectionID, CollectionName, SoftwareName, @{Name="DeploymentTime";Expression={$([Management.ManagementDateTimeConverter]::toDateTime($_.DeploymentTime))}},@{Name="DeploymentIntent";Expression={If ($_.DeploymentIntent -eq 1){"Required"}elseif($_.DeploymentIntent -eq 2){"Available"}else{"Unknown"}}},@{Name="EnforcementDeadline";Expression={$([Management.ManagementDateTimeConverter]::toDateTime($_.EnforcementDeadline))}}, NumberSuccess, NumberInProgress, NumberErrors, NumberUnknown, NumberTotal, PackageID

    $SummaryTitle = "Summary of Deployment for $($Summary.SoftwareName) to $($CollectionInfo.MemberCount) $($CollectionType)(s)"

    $DetailTitle = "Detail for Deployment of $($Summary.SoftwareName) to $($CollectionInfo.MemberCount) $($CollectionType)(s)"

    $OutputReport = New-Object -TypeName PSObject

    If ($DetailLevel -eq "Summary" -or $DetailLevel -eq "Both") {

        $OutputReport | Add-Member -MemberType NoteProperty -Name "SummaryTitle" -Value $SummaryTitle
        $OutputReport | Add-Member -MemberType NoteProperty -Name "SummaryResults" -Value $SummaryTable

    }

    If ($DetailLevel -eq "Detail" -or $DetailLevel -eq "Both") {

        $States = Get-WMIObject -Computer $Server -Namespace $Namespace -Class "SMS_StateInformation"
        #Get Detail Data

        $Detail = Get-WMIObject -Computer $Server -Namespace $Namespace -class SMS_AppDeploymentAssetDetails -Filter "AssignmentID = $AssignmentID"

        $Devices = @()

        Foreach ($Target in $Detail) {

            If ($Target.AppStatusType -eq 5) {
            $ErrorCode = $(Get-WMIObject -Computer $Server -Namespace $Namespace -class SMS_AppDeploymentErrorAssetDetails -Filter "MachineID = $($Target.MachineID) and AssignmentID = $AssignmentID").ErrorCode
            $ErrorMessage = Get-WindowsErrorMessage -ErrorCode $ErrorCode
            }
            Else {
            $ErrorCode = ""
            $ErrorMessage = ""
            }

            $CIComplianceInfo = Get-WmiObject -Computer $Server -Namespace $Namespace -Class SMS_CI_ComplianceHistory -Filter "ResourceID = $($Target.MachineID) and CI_ID = $($Target.AppCI)"

            $Device = New-Object -TypeName PSObject
            #$Device | Add-Member -MemberType NoteProperty -Name "ComplianceState" -Value "$(If ($Target.ComplianceState -eq 1){"Compliant"}elseif($Target.ComplianceState -eq 2){"Non-Compliant"}else{"Unknown"})"
            $Device | Add-Member -MemberType NoteProperty -Name "Name" -Value "$($Target.MachineName)"
            $Device | Add-Member -MemberType NoteProperty -Name "State" -Value "$(if ($Target.AppStatusType -eq 1) {"Success"} elseif ($Target.AppStatusType -eq 2) {"In Progress"} elseif ($Target.AppStatusType -eq 3){"Requirements Not Met"} elseif ($Target.AppStatusType -eq 4) {"Unknown"} elseif($target.AppStatusType -eq 5) {"Error"})"
            #If($Device.State -eq "
                   
            $Device | Add-Member -MemberType NoteProperty -Name "ErrorCode" -Value "$ErrorCode"
            $Device | Add-Member -MemberType NoteProperty -Name "ErrorMessage" -Value "$ErrorMessage"
        
            Try {

            $CIComplianceInfo = $CIComplianceInfo | Sort-Object -Property ComplianceStartDate -Descending | Select * -First 1
        
            $Device | Add-Member -MemberType NoteProperty -Name "LastComplianceStateChange" -Value "$([Management.ManagementDateTimeConverter]::toDateTime($($CIComplianceInfo.ComplianceStartDate)))"
            }
            Catch {
              $Device | Add-Member -MemberType NoteProperty -Name "LastComplianceStateChange" -Value ""
              }

        
            $Devices += $Device


        }

        $OutputReport | Add-Member -MemberType NoteProperty -Name "DetailTitle" -Value $DetailTitle

         $OutputReport | Add-Member -MemberType NoteProperty -Name "DetailResults" -Value $Devices

    }
     
     
     If ($OutputType -eq "Object") {
          Write-Output $OutputReport
    }
    elseif ($OutputType -eq "Text") {
        
        If ($DetailLevel -eq "Summary" -or $DetailLevel -eq "Both"){
            Write-Host ""
            $OutputReport.SummaryTitle
            Write-Host ""
            $($OutputReport.SummaryResults | ft -AutoSize)

        }

        If ($DetailLevel -eq "Detail" -or $DetailLevel -eq "Both"){

            Write-Host ""
            $OutputReport.DetailTitle
            Write-Host ""
            $($OutputReport.DetailResults | Select Name, State, ErrorCode, ErrorMessage, LastComplianceStateChange -Unique | Sort-Object -Property Name | ft -AutoSize)
        }
    }
    pop-location

}