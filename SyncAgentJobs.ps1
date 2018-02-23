function  Sync-AgentJobs {
    <#
        .SYNOPSIS
            Syncs SQL Server Agent Jobs among replicas in the Availability Groups Cluster 
        .DESCRIPTION
            It validates SQL Server Agent Jobs on each replica of the Availability Groups. It compares to a text level to see if something in the job like schedule, steps changed. SSRS and SSIS Jobs are not part of this script
        .PARAMETER SQLInstance
            Listener Name representing the SQL Server to connect to. This can be a collection of listeners, usually pointing to different environments
        .PARAMETER ExcludeJob
            The job(s) to exclude - this list is auto-populated from the server.
        .PARAMETER TempFolder
            Temporary Folder for placing the SQL Agent Job Script for text comparison

        .NOTES
            Tags: Jobs, Agent
            Author: Marcos Freccia
            Website: http://marcosfreccia.wordpress.com
            License: GNU GPL v3 https://opensource.org/licenses/GPL-3.0
        
        .EXAMPLE
            Sync-AgentJobs -SQLInstance MyListener001 -TempFolder 'D:\MSSQL\Automation\JobSync'
            It compares and syncs all SQL Agent Jobs for the primary and secondary replicas of MyListener001. It makes textual comparisson to make sure all details such as: steps, schedules and so on are included.
        .EXAMPLE
            Sync-AgentJobs -SQLInstance MyListener001, MyListener002 -TempFolder 'D:\MSSQL\Automation\JobSync'
            It compares and syncs all SQL Agent Jobs for the primary and secondary replicas of MyListener001 and MyListener002. It makes textual comparisson to make sure all details such as: steps, schedules and so on are included.
        .EXAMPLE
            Sync-AgentJobs -SQLInstance MyListener001 -ExcludeJob BackupDiff -TempFolder 'D:\MSSQL\Automation\JobSync'
            It compares and syncs all SQL Agent Jobs for the primary and secondary replicas of MyListener001 and MyListener002, excluding the BackupDiff Job. It makes textual comparisson to make sure all details such as: steps, schedules and so on are included.
    #>
    
    [cmdletbinding(DefaultParametersetName = 'None')]
    param
    (
        
        [Parameter(Mandatory = $true, ValueFromPipeline = $true)][object[]]$SQLInstance,
        [Parameter(Mandatory = $false)][object[]]$ExcludeJob,
        [Parameter(Mandatory = $true)][string]$TempFolder
    )

    try {
    
        foreach ($SQL in $SQLInstance) {

            $PrimaryJobs = @()
            $SecondaryJobs = @()
            $Results = @()

            if ($ExcludeJob) {
                $ExcludeJobs = $ExcludeJob
            }
           

            $ExcludeJobs += (Invoke-Sqlcmd2 -ServerInstance $SQL -Database msdb -Query "SELECT job.name FROM dbo.sysjobs AS job
        JOIN dbo.syscategories AS cat ON cat.category_id = job.category_id WHERE cat.name IN ('Report Server')
        UNION
        SELECT job.name FROM dbo.sysjobs AS job JOIN dbo.sysjobsteps AS jobs ON jobs.job_id = job.job_id
        WHERE jobs.subsystem IN ('SSIS')")


            # The Failover always happens from the secondary initiating. So this command returns the secondary server at the moment.
            $PrimaryReplica = Get-DbaAgReplica -SqlInstance $SQL | Where-Object {$_.Role -eq "Primary" } | Select-Object -Expand Name


            # The Failover always happens from the secondary initiating. So this command returns the secondary server at the moment.
            $SecondaryReplica = Get-DbaAgReplica -SqlInstance $SQL | Where-Object {$_.Role -eq "Secondary" } | Select-Object -Expand Name


            $PrimaryJobs = Get-DbaAgentJob -SqlInstance $PrimaryReplica -ExcludeJob $ExcludeJobs.name | Select-Object -ExpandProperty name
    
    
            $SecondaryJobs = Get-DbaAgentJob -SqlInstance $SecondaryReplica -ExcludeJob $ExcludeJobs.name | Select-Object -ExpandProperty name
                
 

            # Symbol == means that it exists in both sides
            # Symbol <= means that it exists in the PrimaryNode but not in the SecondaryNode
            # Symbol => means that it exists in the SecondaryNode but not in the PrimaryNode

            $Results = Compare-Object -ReferenceObject $PrimaryJobs -DifferenceObject $SecondaryJobs -IncludeEqual | Select-Object InputObject, SideIndicator


            foreach ($job in $Results) {
                $JobName = $job.InputObject
        
                if ($job.SideIndicator -eq "<=") {
                    Write-Host "Copying Job [$JobName] from [$PrimaryReplica] to [$SecondaryReplica]" -ForegroundColor Yellow
                
                    Copy-DbaAgentJob -Source $PrimaryReplica -Destination $SecondaryReplica -Job $JobName -Force
    
                }
                elseif ($job.SideIndicator -eq "==") {
                    Write-Host "Job [$JobName] exists in all nodes. Looking for differences." -ForegroundColor Yellow     
                    
                    Get-DbaAgentJob -SqlInstance $PrimaryReplica -Job $JobName | Export-DbaScript -Path ("$TempFolder\$PrimaryReplica-$JobName.txt").Replace("/", "_")
                    Get-DbaAgentJob -SqlInstance $SecondaryReplica -Job $JobName | Export-DbaScript -Path ("$TempFolder\$SecondaryReplica-$JobName.txt").Replace("/", "_")

                    $JobFromPrimary = Get-Content -Path "$TempFolder\$PrimaryReplica-$JobName.txt" | Select-Object -Skip 4
                    $JobFromSecondary = Get-Content -Path "$TempFolder\$SecondaryReplica-$JobName.txt"  | Select-Object -Skip 4

                    $JobTextComparison = Compare-Object -ReferenceObject $JobFromPrimary -DifferenceObject $JobFromSecondary -IncludeEqual | Select-Object InputObject, SideIndicator

                    if ($JobTextComparison.SideIndicator -eq "<=") {
                        Write-Host "Job [$JobName] in [$PrimaryReplica] is different of [$JobName] from [$SecondaryReplica]. Recreating Job on $SecondaryReplica" -ForegroundColor Yellow
                        Copy-DbaAgentJob -Source $PrimaryReplica -Destination $SecondaryReplica -Job $JobName -Force
                    }
                    elseif ($JobTextComparison.SideIndicator -eq "==") {
                        Write-Host "Job [$JobName] is synchronized in all replicas" -ForegroundColor Green
                    }
                }
                else {
                    Write-Host "Job [$JobName] found in [$SecondaryReplica] and not found in [$PrimaryReplica]. Removing it from [$SecondaryReplica]" -ForegroundColor Yellow
                    Remove-DbaAgentJob -SqlInstance $SecondaryReplica -Job $JobName -KeepHistory -Confirm:$false
                }
            }

        }
    }
    catch {
        Write-Host -ForegroundColor Red $Error[0].Exception
    }
  
}


#Sync-AgentJobs -SQLInstance contoso-listener -TempFolder F:\Scripts\Automation\JobSync