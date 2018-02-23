function Restore-Database {

    [cmdletbinding(DefaultParametersetName = 'None')]
    param
    (
        [Parameter(Mandatory = $true)][string]$SQLInstance,
        [Parameter(Mandatory = $true)][string]$DatabaseName,
        [Parameter(Mandatory = $true)][string]$BackupPath,
        [Parameter(ParameterSetName = 'PointInTime', Mandatory = $false)][switch]$PerformPointInTime,
        [Parameter(ParameterSetName = 'PointInTime', Mandatory = $true)][DateTime]$RestoreTime,
        [Parameter(ParameterSetName = 'ScriptOut', Mandatory = $false)][switch]$ScriptOutUser,
        [Parameter(ParameterSetName = 'ScriptOut', Mandatory = $true)][string]$PathToScriptOutUser,
        [Parameter(Mandatory = $false)][switch]$AddSqlAvailabilityDatabase,
        [Parameter(Mandatory = $false)][switch]$ReApplySourcePermissions
    )

    [System.Reflection.Assembly]::LoadWithPartialName("Microsoft.SqlServer.SMO") | Out-Null
    [System.Reflection.Assembly]::LoadWithPartialName("Microsoft.SqlServer.SmoExtended") | Out-Null


    $TargetDatabaseName = $DatabaseName

    $FullBackupPath = $BackupPath + $TargetDatabaseName


    $PrimaryReplica = Get-DbaAgReplica -SqlInstance $SQLInstance | Where-Object {$_.Role -eq "Primary" } | Select-Object -ExpandProperty Name
    $SecondaryReplica = Get-DbaAgReplica -SqlInstance $SQLInstance | Where-Object {$_.Role -eq "Secondary" } | Select-Object -ExpandProperty Name

    $AgName = Get-DbaAvailabilityGroup -SqlInstance $SQLInstance | Select-Object -ExpandProperty AvailabilityGroup 

    $AGPath = "SQLSERVER:\SQL\$PrimaryReplica\DEFAULT\AvailabilityGroups\$AgName\AvailabilityDatabases\$TargetDatabaseName"


    # Check if DB is on AG
    $IsAgDatabaseEnabled = Get-DbaAgDatabase -SqlInstance $SQLInstance -Database $TargetDatabaseName

    if ($IsAgDatabaseEnabled) {
        Remove-SQLAvailabilityDatabase -Path $AGPath
        Write-Host "Database [$TargetDatabaseName] removed from Availability Group [$AgName]" -ForegroundColor Yellow

        Remove-DbaDatabase -SqlInstance $SecondaryReplica -Database $TargetDatabaseName -Confirm:$false
        Write-Host "Database [$TargetDatabaseName] removed from Secondary Server [$SecondaryReplica]" -ForegroundColor Yellow

    }


    if ($ScriptOutUser) {

        if (!(Test-Path -Path $PathToScriptOutUser)) {
            New-Item -ItemType Directory -Path $PathToScriptOutUser -Force
        }

        Export-DBAUser -SqlInstance $SQLInstance -Database $TargetDatabaseName | Out-File "$PathToScriptOutUser\$TargetDatabaseName-permissions.sql"

        Write-Host "Logins and Users for the Database [$TargetDatabaseName] successfully exported to $PathToScriptOutUser\$TargetDatabaseName-permissions.sql" -ForegroundColor Yellow  
    }


    if ($PerformPointInTime) {
        $StopAt = $RestoreTime
        Restore-DbaDatabase -SqlServer $PrimaryReplica -Path $FullBackupPath -DatabaseName $TargetDatabaseName -ReuseSourceFolderStructure -MaintenanceSolutionBackup -WithReplace -RestoreTime $StopAt

    }
    else {
        Restore-DbaDatabase -SqlServer $PrimaryReplica -Path $FullBackupPath -DatabaseName $TargetDatabaseName -ReuseSourceFolderStructure -MaintenanceSolutionBackup -WithReplace
    }


    if ($AddSqlAvailabilityDatabase){
            Add-SqlAvailabilityDatabase -Path "SQLSERVER:\SQL\$PrimaryReplica\DEFAULT\AvailabilityGroups\$AgName" -Database $TargetDatabaseName

            Add-SqlAvailabilityDatabase -Path "SQLSERVER:\SQL\$PrimaryReplica\DEFAULT\AvailabilityGroups\$AgName" -Database $TargetDatabaseName -Script 

            }


            if($ReApplySourcePermissions){
                Get-DbaDatabaseUser $SQLInstance -Database $TargetDatabaseName -ExcludeSystemUser |  Remove-DbaDbUser
                
                Invoke-Sqlcmd2 -SqlInstance $SQLInstance -Database $TargetDatabaseName -InputFile "$PathToScriptOutUser\$TargetDatabaseName-permissions.sql" -ParseGO

                Write-Host "Source Permissions re-applied successfully" -ForegroundColor Green



            }

}


$BackupPath = '\\SQLSERVER-0\Backup\aodns-fc$Contoso-ag\'

#Restore-Database -SQLInstance 'contoso-listener' -DatabaseName 'AutoHa-sample' -BackupPath $BackupPath -ScriptOutUser -PathToScriptOutUser F:\Scripts


# Apply Permissions
#F:\Scripts\SQL_Scripts\permissions_autoha_sample.txt
#Restore-Database -SQLInstance 'contoso-listener' -DatabaseName 'AutoHa-sample' -BackupPath $BackupPath -ScriptOutUser -PathToScriptOutUser F:\Scripts -ReApplySourcePermissions -AddSqlAvailabilityDatabase


#$RestoreTime = Get-Date("02/22/2018 16:30")
#Restore-Database -SQLInstance 'contoso-listener' -DatabaseName 'AdventureWorks2014' -BackupPath $BackupPath -PerformPointInTime -RestoreTime $RestoreTime

