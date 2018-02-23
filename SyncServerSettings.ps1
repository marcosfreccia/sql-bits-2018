function Sync-SpConfigure {
    <#
        .SYNOPSIS
            It validates and syncs all server level system configuration (sys.configuration/sp_configure) among replicas in the Availability Groups Cluster.
        .DESCRIPTION
            It validates and syncs all server level system configuration (sys.configuration/sp_configure) among replicas in the Availability Groups Cluster.
        .PARAMETER SqlInstances
            Listener Name representing the SQL Server to connect to. This can be a collection of listeners, usually pointing to different environments
        .PARAMETER ConfigName
            Return only specific configurations -- auto-populated from source server
        
        .NOTES
            Tags: SpConfigure, Configuration
            Author: Marcos Freccia
            Website: http://marcosfreccia.wordpress.com
            License: GNU GPL v3 https://opensource.org/licenses/GPL-3.0
        
        .EXAMPLE
            Sync-SpConfigure -SqlInstances MyListener001 -ConfigName MaxServerMemory
            It compares and syncs the MaxServerMemory setting in the primary and secondary replicas of MyListener001.
        .EXAMPLE
            foreach ($SpSetting in Get-DbaSpConfigure -SqlInstance MyListener001  | Select-Object  -ExpandProperty ConfigName) {
                    Sync-SpConfigure -SQLInstances MyListener001 -ConfigName $SpSetting
            }
            It goes through all Server Level Settings and syncs for the primary and secondary replicas of MyListener001.

    #>
    [cmdletbinding(DefaultParametersetName = 'None')]
    param
    (
        [Parameter(Mandatory = $true, ValueFromPipeline = $true)][object[]]$SQLInstance,
        [Parameter(Mandatory = $true)][string]$ConfigName,
        [Parameter(Mandatory = $false)][switch]$Report
    )
    
    try {
        foreach ($SQL in $SQLInstance) {

            # The Failover always happens from the secondary initiating. So this command returns the secondary server at the moment.
            $PrimaryReplica = Get-DbaAgReplica -SqlInstance $SQL | Where-Object {$_.Role -eq "Primary" } | Select-Object -Expand Name


            # The Failover always happens from the secondary initiating. So this command returns the secondary server at the moment.
            $SecondaryReplica = Get-DbaAgReplica -SqlInstance $SQL | Where-Object {$_.Role -eq "Secondary" } | Select-Object -Expand Name

            $PrimaryConfiguration = Get-DbaSpConfigure -SqlInstance $PrimaryReplica -ConfigName $ConfigName | Select-Object ConfigName, RunningValue

            $SecondaryConfiguration = Get-DbaSpConfigure -SqlInstance $SecondaryReplica -ConfigName $ConfigName | Select-Object ConfigName, RunningValue
         

            # Symbol == means that it exists in both sides
            # Symbol <= means that it exists in the PrimaryNode but not in the SecondaryNode
            # Symbol => means that it exists in the SecondaryNode but not in the PrimaryNode

            $Results = Compare-Object -ReferenceObject $PrimaryConfiguration -DifferenceObject $SecondaryConfiguration -IncludeEqual -Property "RunningValue"
            
            if ($Results.SideIndicator -eq "<=") {
                if ($Report) {
                    Write-Host "The following change is going to be applied in $SecondayReplica" $ConfigName " - "$PrimaryConfiguration.RunningValue -ForegroundColor Yellow
                }
                else {
                    Set-DbaSpConfigure -SqlInstance $SecondaryReplica -ConfigName $PrimaryConfiguration.ConfigName -Value $PrimaryConfiguration.RunningValue
                    Write-Host "The following change is going to be applied in $SecondayReplica "$ConfigName " - "$PrimaryConfiguration.RunningValue -ForegroundColor Yellow
                }
            }
        

        
        }


    }
    catch {
        Write-Host -ForegroundColor Red $Error[0].Exception
    }
}



$AG = "contoso-listener"

foreach ($SpSetting in Get-DbaSpConfigure -SqlInstance $AG | Select-Object -ExpandProperty ConfigName) {
    Sync-SpConfigure -SQLInstance $AG -ConfigName $SpSetting -Report
}