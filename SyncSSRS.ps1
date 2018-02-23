function Sync-SSRSSubscriptionJobs {
    <#
        .SYNOPSIS
            It validates and removes SSRS Subscription Jobs from Secondary Servers
        .DESCRIPTION
            It validates and removes SSRS Subscription Jobs from Secondary Servers
        .PARAMETER SqlInstance
            Listener Name representing the SQL Server to connect to. This can be a collection of listeners, usually pointing to different environments
        
        .NOTES
            Tags: SSRS, Subscriptions
            Author: Marcos Freccia
            Website: http://marcosfreccia.wordpress.com
            License: GNU GPL v3 https://opensource.org/licenses/GPL-3.0
        
        .EXAMPLE
            Sync-SSRSSubscriptionJobs -SqlInstance MyListener001
            It compares and syncs the SSRS Subscription Jobs in the primary and secondary replicas of MyListener001.


    #>
    [cmdletbinding(DefaultParametersetName = 'None')]
    param
    (
        [Parameter(Mandatory = $true, ValueFromPipeline = $true)][object[]]$SQLInstance,
        [Parameter(Position = 1, Mandatory = $false)][switch]$Report
    )

    try {
    

        foreach ($SQL in $SQLInstance) {

            # The Failover always happens from the secondary initiating. So this command returns the secondary server at the moment.
            $SecondaryReplica = Get-DbaAgReplica -SqlInstance $SQL | Where-Object {$_.Role -eq "Secondary" } | Select-Object -Expand Name


            $SSRSJobs = (Invoke-Sqlcmd2 -ServerInstance $SecondaryReplica -Database msdb -Query "SELECT job.name FROM dbo.sysjobs AS job
                JOIN dbo.syscategories AS cat ON cat.category_id = job.category_id WHERE cat.name IN ('Report Server')")

            if ($SSRSJobs.Count) {
                Write-Host "Number of jobs found in the ${SecondaryReplica}:"$SSRSJobs.Count -ForegroundColor Yellow

                foreach ($SSRSJob in $SSRSJobs.name) {
                    if ($Report) {
                        Write-Host "Job [$SSRSJob] removed successfully from $SecondaryReplica" -ForegroundColor Green
                    }
                    else {
                        Remove-DbaAgentJob -SqlInstance $SecondaryReplica -Job $SSRSJob -KeepHistory
                                    
                        Write-Host "Job [$SSRSJob] removed successfully from $SecondaryReplica" -ForegroundColor Green
                    }
                }

            }
            else {
                Write-Host "There are no jobs to be removed from the current secondary $SecondaryReplica" -ForegroundColor Green
            }

        }
    }
    catch {
        Write-Host -ForegroundColor Red $Error[0].Exception
    }
}

#Sync-SSRSSubscriptionJobs -SQLInstance contoso-listener -Report



