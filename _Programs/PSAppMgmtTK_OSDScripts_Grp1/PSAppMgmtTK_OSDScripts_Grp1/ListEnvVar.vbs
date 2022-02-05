Dim oTSEnv 
Dim oVar

Set oTSEnv = CreateObject("Microsoft.SMS.TSEnvironment") 

For Each oVar In oTSEnv.GetVariables
	WScript.Echo " "
	WScript.Echo "  "& oVar & vbTab & oTSEnv(oVar) & vbTab
Next