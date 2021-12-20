if((Test-Path .\ServiceUI.exe -PathType Leaf) -and ("$env:COMPUTERNAME`$" -eq $env:USERNAME)) {
    $targetprocesses = @(Get-WmiObject -Query "Select * FROM Win32_Process WHERE Name='explorer.exe'" -ErrorAction SilentlyContinue)
    if ($targetprocesses.Count -eq 0) {
        Try {
            Write-Output "No user logged in, running without SerivuceUI"
            Start-Process Deploy-Application.exe -Wait -ArgumentList '-DeployMode "NonInteractive"'
        }
        Catch {
            $ErrorMessage = $_.Exception.Message
            $ErrorMessage
        }
    }
    else {
        Foreach ($targetprocess in $targetprocesses) {
            $Username = $targetprocesses.GetOwner().User
            Write-output "$Username logged in, running with SerivuceUI"
        }
        Try {
            .\ServiceUI.exe -Process:explorer.exe Deploy-Application.exe
        }
        Catch {
            $ErrorMessage = $_.Exception.Message
            $ErrorMessage
        }
    }
    Write-Output "Install Exit Code = $LASTEXITCODE"
    Exit $LASTEXITCODE
} else {
    & "$PSScriptRoot\Deploy-Application.ps1"
    Exit $LASTEXITCODE
}