# Requires Configuration manager console installed.
[CmdletBinding()]
Param (
	[Parameter(Mandatory=$false)]
	[string]$PathToApp="\\mecm\SOURCES\AppInstallersManaged\ITS_StartMenuLayout",
    [Parameter(Mandatory=$false)]
    [int]$RefreshType =2 ## 6 = Incremental and Scheduled Updates             # 4 = Incremental Updates Only             # 2 = Scheduled Updates only             # 1 = Manual Update only 
)
import-module (join-path "$env:SMS_ADMIN_UI_PATH\..\" ConfigurationManager.psd1)


$displayName = Split-Path $PathToApp -Leaf
$sections = $displayName.Split("_")
$publisher = $sections[0]
$app = $sections[1]
$version = $sections[2]
$revision = $sections[3]

$PathToApp

$RegPSAppMgmtTKKey = "HKLM:\Software\ITS\PSAppMgmtTK"
$RegPSAppMgmtTKValue = "BaseDirectory"
$BaseDirectory = Get-ItemPropertyValue -path $RegPSAppMgmtTKKey $RegPSAppMgmtTKValue

push-location
Set-Location "C:\"
$GeneralSettings = Get-Content -Path (join-path $BaseDirectory "_ComputerAppMgmt\Generalsettings.json") | ConvertFrom-Json
$AppSettings = Get-Content -Path (join-path $PathToApp AppSettings.json) | ConvertFrom-Json
pop-location

foreach($server in $GeneralSettings.MECM.Servers){
    #Enter MECM Console
    if($null -eq (Get-PSDrive -Name $server.SiteCode -PSProvider CMSite -ErrorAction SilentlyContinue)) {
        New-PSDrive -name $server.SiteCode -psprovider CMSite  -Root $server.FQDN
    }
    push-location
    Set-Location "$($server.SiteCode):\"

    
    $TypesToLCNames = @{}
    $limitingCollectionTypeIDs= @{ device="SMS00001"; User="SMS00004"}
    foreach($type in $server.BaseCollections){
        $TypesToLCNames.($type.Type) = $type.BaseCollectionName
        foreach($CollectionType in ("User", "Device")) {
            $CollectionName = "$($type.BaseCollectionName)-$CollectionType"
            write-host "Checking ${CollectionType}Collection: $CollectionName on $($server.SiteCode)"
            $Collection = Get-CMCollection -Name $CollectionName -CollectionType $CollectionType
            if( -not $Collection ) {
                write-host "Creating ${CollectionType}Collection: $CollectionName on $($server.SiteCode)"
                if($CollectionType -eq "Device"){
                    $Collection = New-CMDeviceCollection  -LimitingCollectionID ($limitingCollectionTypeIDs[$CollectionType]) -Name $CollectionName -verbose
                }else {
                    $Collection = New-CMUserCollection  -LimitingCollectionID ($limitingCollectionTypeIDs[$CollectionType]) -Name $CollectionName -verbose
                }
                Move-CMObject -FolderPath ".\${CollectionType}Collection\PSAppMgmtTK" -InputObject $Collection
            }
        }
    }
    
    foreach($set in $AppSettings.MECM.CollectionTypes.PSObject.Properties){
        if($set.Name -eq "APPie") {continue}
        $setTypeString = "$($set.Name)-${publisher}_${app}"
        $ADGRPCollectionName = "ADGRP $setTypeString"
        $setTypeString
        
        #Create Device AD Collection
        if($AppSettings.MECM.CollectionTypes.($set.Name).CreateADDeviceCollection){
            $CollectionType="Device"
            $CollectionName="$ADGRPCollectionName-$CollectionType"
            $Collection = Get-CMCollection -Name $CollectionName -CollectionType $CollectionType -ea SilentlyContinue
            if( -not $Collection ) {
                #Avoiding a spike by coding to start between 8:00 PM and 10 PM (yesterday)
                $StartDateTime = (Get-Date -Hour (Get-Random -Minimum 20 -Maximum 22) -Minute (Get-Random -Minimum 0 -Maximum 60) -Second 0 ).AddDays(-1)
                #RecurInterval Accepted values:	Minutes, Hours, Days
                # Hard coding to 24 hours. Will update as per deployment collection as per Collection Evaluation Graph https://docs.microsoft.com/en-us/mem/configmgr/core/clients/manage/collections/collection-evaluation#collection-evaluation-graph
                $Schedule = New-CMSchedule -Start $StartDateTime -RecurInterval Days -RecurCount 1
                write-host "Creating ${CollectionType}Collection: $CollectionName on $($server.SiteCode)"
                $Collection = New-CMDeviceCollection  -LimitingCollectionName  "ADGRP-PSAppMgmtTK-LC-$CollectionType" -Name $CollectionName -RefreshSchedule $Schedule -RefreshType $RefreshType -verbose 
                Move-CMObject -FolderPath ".\${CollectionType}Collection\PSAppMgmtTK\ADGroupMemships" -InputObject $Collection
            }

            $RuleName = "$CollectionName"
            $QueryRule=Get-CMDeviceCollectionQueryMembershipRule -InputObject $Collection -RuleName $RuleName
            if(-not $QueryRule) {
                write-host "Creating Query Rule for Collection: $CollectionName on $($server.SiteCode)"
                $QueryExperssion = "select SMS_R_SYSTEM.ResourceID,SMS_R_SYSTEM.ResourceType,SMS_R_SYSTEM.Name,SMS_R_SYSTEM.SMSUniqueIdentifier,SMS_R_SYSTEM.ResourceDomainORWorkgroup,SMS_R_SYSTEM.Client from SMS_R_System where SMS_R_System.SecurityGroupName LIKE `"%\\${setTypeString}`""
                $QueryRule = Add-CMDeviceCollectionQueryMembershipRule -InputObject $Collection -PassThru -QueryExpression $QueryExperssion -RuleName $RuleName -verbose
            }
        }

        #Create Device Deployment Collection
        if($AppSettings.MECM.CollectionTypes.($set.Name).CreateDeploymentDeviceCollection){
            $CollectionType="Device"
            $CollectionName="$setTypeString-$CollectionType"
            $Collection = Get-CMCollection -Name $CollectionName -CollectionType $CollectionType -ea SilentlyContinue
            if( -not $Collection ) {
                #Avoiding a spike by coding to start between 8:00 PM and 10 PM (yesterday)
                $StartDateTime = (Get-Date -Hour (Get-Random -Minimum 20 -Maximum 22) -Minute (Get-Random -Minimum 0 -Maximum 60) -Second 0 ).AddDays(-1)
                $schedSettings = $AppSettings.MECM.CollectionTypes.($set.Name)."CollectionEvaluationSchedule".$CollectionType
                $Schedule = New-CMSchedule -Start $StartDateTime -RecurInterval $schedSettings.RecurInterval -RecurCount $schedSettings.RecurCount
                write-host "Creating ${CollectionType}Collection: $CollectionName on $($server.SiteCode)"
                $Collection = New-CMDeviceCollection  -LimitingCollectionName  "$($TypesToLCNames.($set.Name))-$CollectionType" -Name $CollectionName -RefreshSchedule $Schedule -RefreshType $RefreshType -verbose 
                Move-CMObject -FolderPath ".\${CollectionType}Collection\PSAppMgmtTK\Deployments" -InputObject $Collection

                #include
                $ADCollection= Get-CMCollection -Name "$ADGRPCollectionName-$CollectionType" -CollectionType $CollectionType -ea SilentlyContinue
                if($ADCollection){
                    Add-CMDeviceCollectionIncludeMembershipRule -InputObject $Collection -IncludeCollection $ADCollection -verbose
                }
                
            }
            #Also create early adopters.
            if($set.Name -eq "APPi" -and ($AppSettings.MECM.CollectionTypes.APPie."CreateDeployment${CollectionType}Collection")){
                $EarlyCollectionName="APPie-${publisher}_${app}-$CollectionType"
                $EarlyCollection = Get-CMCollection -Name $EarlyCollectionName -CollectionType $CollectionType -ea SilentlyContinue
                if( -not $EarlyCollection ) {
                    #Avoiding a spike by coding to start between 8:00 PM and 10 PM (yesterday)
                    $StartDateTime = (Get-Date -Hour (Get-Random -Minimum 20 -Maximum 22) -Minute (Get-Random -Minimum 0 -Maximum 60) -Second 0 ).AddDays(-1)
                    $Schedule = New-CMSchedule -Start $StartDateTime -RecurInterval Days -RecurCount 1
                    write-host "Creating ${CollectionType}Collection: $CollectionName on $($server.SiteCode)"
                    $EarlyCollection = New-CMDeviceCollection  -LimitingCollectionName  "$($TypesToLCNames.("APPie"))-$CollectionType" -Name $EarlyCollectionName -RefreshSchedule $Schedule -RefreshType $RefreshType -verbose 
                    Move-CMObject -FolderPath ".\${CollectionType}Collection\PSAppMgmtTK\Deployments" -InputObject $EarlyCollection

                    #include
                    Add-CMDeviceCollectionIncludeMembershipRule -InputObject $EarlyCollection -IncludeCollection $Collection -verbose
                }
            }
        }
        
        #Create User AD Collection
        if($AppSettings.MECM.CollectionTypes.($set.Name).CreateADUserCollection){
            $CollectionType="User"
            $CollectionName="$ADGRPCollectionName-$CollectionType"
            $Collection = Get-CMCollection -Name $CollectionName -CollectionType $CollectionType -ea SilentlyContinue
            if( -not $Collection ) {
                #Avoiding a spike by coding to start between 8:00 PM and 10 PM (yesterday)
                $StartDateTime = (Get-Date -Hour (Get-Random -Minimum 20 -Maximum 22) -Minute (Get-Random -Minimum 0 -Maximum 60) -Second 0 ).AddDays(-1)
                #RecurInterval Accepted values:	Minutes, Hours, Days
                # Hard coding to 24 hours. Will update as per deployment collection as per Collection Evaluation Graph https://docs.microsoft.com/en-us/mem/configmgr/core/clients/manage/collections/collection-evaluation#collection-evaluation-graph
                $Schedule = New-CMSchedule -Start $StartDateTime -RecurInterval Days -RecurCount 1
                write-host "Creating ${CollectionType}Collection: $CollectionName on $($server.SiteCode)"
                $Collection = New-CMUserCollection  -LimitingCollectionName  "ADGRP-PSAppMgmtTK-LC-$CollectionType" -Name $CollectionName -RefreshSchedule $Schedule -RefreshType $RefreshType -verbose 
                Move-CMObject -FolderPath ".\${CollectionType}Collection\PSAppMgmtTK\ADGroupMemships" -InputObject $Collection
            }

            $RuleName = "$CollectionName"
            $QueryRule=Get-CMDeviceCollectionQueryMembershipRule -InputObject $Collection -RuleName $RuleName
            if(-not $QueryRule) {
                write-host "Creating Query Rule for Collection: $CollectionName on $($server.SiteCode)"
                $QueryExperssion = "select SMS_R_USER.ResourceID,SMS_R_USER.ResourceType,SMS_R_USER.Name,SMS_R_USER.UniqueUserName,SMS_R_USER.WindowsNTDomain FROM SMS_R_User where SMS_R_User.UserGroupName LIKE `"%\\${setTypeString}`""
                $QueryRule = Add-CMUserCollectionQueryMembershipRule -InputObject $Collection -PassThru -QueryExpression $QueryExperssion -RuleName $RuleName -verbose
            }
            $SAMName = "*\$setTypeString".replace("+","_")
            $GRPResID=(Get-CMResource -ResourceType "UserGroup" -Fast | Where-Object {$_.Name -like $SAMName}).ResourceID
            if($GRPResID){
                Add-CMUserCollectionDirectMembershipRule -InputObject $Collection -ResourceID $GRPResID -verbose
            }else{
                write-host "AD group not found. No direct membership rule added to USER GROUP for ADGRP $setTypeString. Ensure group exists and SCCM has run ad group discovery." -ForegroundColor "Magenta"
            }
        }
        

        #Create User Deployment Collection
        if($AppSettings.MECM.CollectionTypes.($set.Name).CreateDeploymentUserCollection){
            $CollectionType="User"
            $CollectionName="$setTypeString-$CollectionType"
            $Collection = Get-CMCollection -Name $CollectionName -CollectionType $CollectionType -ea SilentlyContinue
            if( -not $Collection ) {
                #Avoiding a spike by coding to start between 8:00 PM and 10 PM (yesterday)
                $StartDateTime = (Get-Date -Hour (Get-Random -Minimum 20 -Maximum 22) -Minute (Get-Random -Minimum 0 -Maximum 60) -Second 0 ).AddDays(-1)
                $schedSettings = $AppSettings.MECM.CollectionTypes.($set.Name)."CollectionEvaluationSchedule".$CollectionType
                $Schedule = New-CMSchedule -Start $StartDateTime -RecurInterval $schedSettings.RecurInterval -RecurCount $schedSettings.RecurCount
                write-host "Creating ${CollectionType}Collection: $CollectionName on $($server.SiteCode)"
                $Collection = New-CMUserCollection  -LimitingCollectionName  "$($TypesToLCNames.($set.Name))-$CollectionType" -Name $CollectionName -RefreshSchedule $Schedule -RefreshType $RefreshType -verbose 
                Move-CMObject -FolderPath ".\${CollectionType}Collection\PSAppMgmtTK\Deployments" -InputObject $Collection

                #include
                $ADCollection= Get-CMCollection -Name "$ADGRPCollectionName-$CollectionType" -CollectionType $CollectionType -ea SilentlyContinue
                if($ADCollection){
                    Add-CMUserCollectionIncludeMembershipRule -InputObject $Collection -IncludeCollection $ADCollection -verbose
                }
                
            }
            #Also create early adopters.
            if($set.Name -eq "APPi" -and ($AppSettings.MECM.CollectionTypes.APPie."CreateDeployment${CollectionType}Collection")){
                $EarlyCollectionName="APPie-${publisher}_${app}-$CollectionType"
                $EarlyCollection = Get-CMCollection -Name $EarlyCollectionName -CollectionType $CollectionType -ea SilentlyContinue
                if( -not $EarlyCollection ) {
                    #Avoiding a spike by coding to start between 8:00 PM and 10 PM (yesterday)
                    $StartDateTime = (Get-Date -Hour (Get-Random -Minimum 20 -Maximum 22) -Minute (Get-Random -Minimum 0 -Maximum 60) -Second 0 ).AddDays(-1)
                    $Schedule = New-CMSchedule -Start $StartDateTime -RecurInterval Days -RecurCount 1
                    write-host "Creating ${CollectionType}Collection: $CollectionName on $($server.SiteCode)"
                    $EarlyCollection = New-CMUserCollection  -LimitingCollectionName  "$($TypesToLCNames.("APPie"))-$CollectionType" -Name $EarlyCollectionName -RefreshSchedule $Schedule -RefreshType $RefreshType -verbose 
                    Move-CMObject -FolderPath ".\${CollectionType}Collection\PSAppMgmtTK\Deployments" -InputObject $EarlyCollection

                    #include
                    Add-CMUserCollectionIncludeMembershipRule -InputObject $EarlyCollection -IncludeCollection $Collection -verbose
                }
            }
        }
    }
    pop-location
}
pop-location
