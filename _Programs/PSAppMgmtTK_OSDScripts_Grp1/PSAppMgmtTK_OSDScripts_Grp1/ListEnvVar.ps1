$VarFile = "Z:\${env:computername}\TSVarsfromPowershell.json"
$TSEnv = New-Object -ComObject Microsoft.SMS.TSEnvironment

$Vars = $TSEnv.GetVariables()

$Output = @{}
foreach ($Var in $Vars)
{
    $Output.add( $Var, $TSEnv.Value($Var))
}
ConvertTo-Json $Output -Depth 50  | Out-File -FilePath $VarFile