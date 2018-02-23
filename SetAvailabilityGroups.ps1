function Set-AvailabilityGroupsPrimaryReplica {
    <#
        .SYNOPSIS
            Failover Availability Groups
        .DESCRIPTION
            <>
        .PARAMETER SQLInstance
            Listener Name to failover from primary to secondary . This can be a collection of listeners.
        .NOTES
            Tags: Failover, Databases
            Author: Marcos Freccia
            Website: http://marcosfreccia.wordpress.com
            License: GNU GPL v3 https://opensource.org/licenses/GPL-3.0
        
        .EXAMPLE
            Set-AvailabilityGroupsPrimaryReplica -SQLInstance MyListener001
            Failover Databases of the listener MyListener001 from primary to secondary replica
    #>
    [cmdletbinding(DefaultParametersetName = 'None')]

    param
    (
        [Parameter(Mandatory = $true, ValueFromPipeline = $true)][object[]]$SQLInstance
    )

    try {

        foreach ($SQL in $SQLInstance) {

            $SecondaryReplica = Get-DbaAgReplica -SqlInstance $SQL | Where-Object {$_.Role -eq "Secondary" } | Select-Object -ExpandProperty Name

            $AvailabilityGroup = Get-DbaAvailabilityGroup -SqlInstance $SQL | Select-Object -ExpandProperty AvailabilityGroup

            $Path = "SQLSERVER:\SQL\$SecondaryReplica\DEFAULT\AvailabilityGroups\$AvailabilityGroup"

            if ($Path) {

                Switch-SqlAvailabilityGroup -Path $Path

            }
        }
    }
    catch {
        Write-Host -ForegroundColor Red $Error[0].Exception
    }
}

function Switch-AvailabilityMode {
    <#
        .SYNOPSIS
            It changes Availability Groups settings
        .DESCRIPTION
            This function allows the change of some Availability Group Settings such as: Availability Mode and Failover Mode. 
        .PARAMETER SQLInstance
            Listener Name to which settings will be changed. This can be a collection of listeners.
        .PARAMETER AvailabilityMode
            Availability Mode setting for the Availability Groups. It can be two possible values: AsynchronousCommit or SynchronousCommit
        .PARAMETER FailoverMode
            Failover Mode setting for the Availability Groups. It can be two possible values: Automatic or Manual
        .NOTES
            Tags: Failover, Databases
            Author: Marcos Freccia
            Website: http://marcosfreccia.wordpress.com
            License: GNU GPL v3 https://opensource.org/licenses/GPL-3.0
        
        .EXAMPLE
            Switch-AvailabilityMode -SQLInstance MyListener001 -AvailabilityMode AsynchronousCommit -FailoverMode Manual
            Change the Availability Groups Setting for the Availability Group of MyListener001
    #>
    [cmdletbinding(DefaultParametersetName = 'None')]
    param
    (
        [Parameter(Mandatory = $true, ValueFromPipeline = $true)][object[]]$SQLInstance,
        [Parameter(Mandatory = $true)][string]$AvailabilityMode,
        [Parameter(Mandatory = $true)][string]$FailoverMode
    )
    try {
        foreach ($SQL in $SQLInstance) {

            if ($AvailabilityMode -eq "AsynchronousCommit" -and $FailoverMode -eq "Automatic") {
                Write-Host "Asynchronous-commit availability mode does not support automatic failover. For automatic failover, use synchronous-commit mode." -ForegroundColor Red
                exit

            }

            $PrimaryReplica = Get-DbaAgReplica -SqlInstance $SQL | Where-Object {$_.Role -eq "Primary" } | Select-Object -ExpandProperty Name
            $SecondaryReplica = Get-DbaAgReplica -SqlInstance $SQL | Where-Object {$_.Role -eq "Secondary" } | Select-Object -ExpandProperty Name

            $AvailabilityGroup = Get-DbaAvailabilityGroup -SqlInstance $SQL | Select-Object -ExpandProperty AvailabilityGroup

            $Path = "SQLSERVER:\SQL\$PrimaryReplica\DEFAULT\AvailabilityGroups\$AvailabilityGroup\AvailabilityReplicas\$PrimaryReplica"
            Set-SqlAvailabilityReplica -AvailabilityMode $AvailabilityMode -FailoverMode $FailoverMode -Path $Path


            $Path = "SQLSERVER:\SQL\$PrimaryReplica\DEFAULT\AvailabilityGroups\$AvailabilityGroup\AvailabilityReplicas\$SecondaryReplica"

            Set-SqlAvailabilityReplica -AvailabilityMode $AvailabilityMode -FailoverMode $FailoverMode -Path $Path

        }
    }
    catch {
        Write-Host -ForegroundColor Red $Error[0].Exception
    }
}


function Switch-DataMovementMode {
    [cmdletbinding(DefaultParametersetName = 'None')]
    param
    (
        [Parameter(Mandatory = $true, ValueFromPipeline = $true)][object[]]$SQLInstance,
        [Parameter(Mandatory = $false)][switch]$Suspend,
        [Parameter(Mandatory = $false)][switch]$Resume
    )

    try {
        foreach ($SQL in $SQLInstance) {

            $PrimaryReplica = Get-DbaAgReplica -SqlInstance $SQL | Where-Object {$_.Role -eq "Primary" } | Select-Object -Expand Name
            $AvailabilityGroup = Get-DbaAvailabilityGroup -SqlInstance $SQL | Select-Object -ExpandProperty AvailabilityGroup

            $Path = "SQLSERVER:\SQL\$PrimaryReplica\DEFAULT\AvailabilityGroups\$AvailabilityGroup\AvailabilityDatabases"

            if ($Suspend) {
                Get-ChildItem -Path $Path | Suspend-SqlAvailabilityDatabase
            }
            elseif ($Resume) {
                Get-ChildItem -Path $Path | Resume-SqlAvailabilityDatabase
            }

        }
    }

    catch {
        Write-Host -ForegroundColor Red $Error[0].Exception
    }
}

#Switch-AvailabilityMode -SQLInstance contoso-listener -AvailabilityMode SynchronousCommit -FailoverMode automatic


#Switch-AvailabilityMode -SQLInstance contoso-listener -AvailabilityMode ASynchronousCommit -FailoverMode manual


#Set-AvailabilityGroupsPrimaryReplica -SQLInstance contoso-listener


#Switch-DataMovementMode -SQLInstance contoso-listener -Resume
