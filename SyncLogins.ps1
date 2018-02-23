function  Sync-Logins {
    <#
        .SYNOPSIS
            Syncs Windows and SQL Server logins for each Availability Groups of SQL Server.
        .DESCRIPTION
            It validates SQL and Windows logins on each replica of the Availability Groups. It can create or drop logins depending where the object is placed.
        .PARAMETER SqlInstance
            Listener Name representing the SQL Server to connect to. This can be a collection of listeners
        .PARAMETER Report
            Switch will only report which logins are not in sync. 
        .NOTES
            Tags: Logins, Windows, SQL
            Author: Marcos Freccia
            Website: http://marcosfreccia.wordpress.com
            License: GNU GPL v3 https://opensource.org/licenses/GPL-3.0
        
        .EXAMPLE
            Sync-Logins -SqlInstance MyListener001
            It syncs all Windows and SQL Servers logins for the primary and secondary replicas of MyListener001.
        .EXAMPLE
            Sync-Logins -SqlInstance MyListener001, MyListener002
            It syncs all Windows and SQL Servers logins for the primary and secondary replicas of MyListener001 and MyListener002
        .EXAMPLE
            Sync-Logins -SqlInstance MyListener001 -Report
            It reports all Windows and SQL Servers logins that are not in sync for the primary and secondary replicas of MyListener001.
    #>
    
    [cmdletbinding(DefaultParametersetName = 'None')]
    param
    (
        
        [Parameter(Mandatory = $true, ValueFromPipeline = $true)][object[]]$SQLInstance,
        [Parameter(Mandatory = $false)][switch]$Report
    )

    try {

        foreach ($SQL in $SQLInstance) {

            $PrimaryLogins = @()
            $SecondaryLogins = @()
            $Results = @()

            
            $PrimaryReplica = Get-DbaAgReplica -SqlInstance $SQL | Where-Object {$_.Role -eq "Primary" } | Select-Object -Expand Name


            
            $SecondaryReplica = Get-DbaAgReplica -SqlInstance $SQL | Where-Object {$_.Role -eq "Secondary" } | Select-Object -Expand Name



            $PrimaryLogins = Get-DbaLogin -SqlInstance $PrimaryReplica -ExcludeFilter "##*", "NT *" | Select-Object -ExpandProperty name
            


            $SecondaryLogins = Get-DbaLogin -SqlInstance $SecondaryReplica -ExcludeFilter "*##*", "NT *" | Select-Object -ExpandProperty name

            # Symbol == means that it exists in both sides
            # Symbol <= means that it exists in the PrimaryNode but not in the SecondaryNode
            # Symbol => means that it exists in the SecondaryNode but not in the PrimaryNode

            $Results = Compare-Object -ReferenceObject $PrimaryLogins -DifferenceObject $SecondaryLogins | Select-Object InputObject, SideIndicator
     

            foreach ($login in $Results) {
                $DBLogin = $login.InputObject
                if ($login.SideIndicator -eq "<=") {
                    if ($Report) {
                        Write-Host "Login [$DBLogin] is being copied from [$PrimaryReplica] to [$SecondaryReplica]:" -ForegroundColor Yellow

                    }
                    else {
                        Write-Host "Login [$DBLogin] is being copied from [$PrimaryReplica] to [$SecondaryReplica]:" -ForegroundColor Yellow
                        Copy-DbaLogin -Source $PrimaryReplica -Destination $SecondaryReplica -Login $DBLogin
                    }
                }
                if ($login.SideIndicator -eq "=>") {
                    if ($Report) {
                        Write-Host "Removing login [$DBLogin] from [$SecondaryReplica]: " -ForegroundColor Yellow
                    } 
                    else {
                        Write-Host "Removing login  [$DBLogin] from [$SecondaryReplica]: " -ForegroundColor Yellow
                        Remove-DbaLogin -SqlInstance $SecondaryReplica -Login $DBLogin -Confirm:$false
                    }
                        
                }
            }
 
        }

    }
    catch {
        Write-Host -ForegroundColor Red $Error[0].Exception
    }

}

#Sync-Logins -SQLInstance contoso-listener