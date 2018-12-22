function Get-PendingSCCMPatches {
    [cmdletbinding()]
    param(
        # Computername(s) to invoke updates on
        [parameter(Mandatory = $false, ValueFromPipelineByPropertyName)]
        [Alias('Computer', 'PSComputerName', 'IPAddress', 'ServerName', 'HostName')]
        [string[]]$ComputerName = $env:COMPUTERNAME,
        # switch to determine if Definition updates should be included
        [switch]$IncludeDefs,
        # Credential to use
        [parameter(Mandatory = $false, ValueFromPipelineByPropertyName)]
        [system.management.automation.pscredential]$Credential
    )
    begin {
        $UpdateStatus = @{
            "23" = "WaitForOrchestration";
            "22" = "WaitPresModeOff";
            "21" = "WaitingRetry";
            "20" = "PendingUpdate";
            "19" = "PendingUserLogoff";
            "18" = "WaitUserReconnect";
            "17" = "WaitJobUserLogon";
            "16" = "WaitUserLogoff";
            "15" = "WaitUserLogon";
            "14" = "WaitServiceWindow";
            "13" = "Error";
            "12" = "InstallComplete";
            "11" = "Verifying";
            "10" = "WaitReboot";
            "9"  = "PendingHardReboot";
            "8"  = "PendingSoftReboot";
            "7"  = "Installing";
            "6"  = "WaitInstall";
            "5"  = "Downloading";
            "4"  = "PreDownload";
            "3"  = "Detecting";
            "2"  = "Submitted";
            "1"  = "Available";
            "0"  = "None";
        }
        #$UpdateStatus.Get_Item("$EvaluationState")
        #endregion status type hashtable

        $Filter = switch ($IncludeDefs) {
            $true {
                "ComplianceState=0"
            }
            Default {
                "NOT Name LIKE '%Definition%' and ComplianceState=0"
            }
        }
    }
    process {
        foreach ($Computer in $ComputerName) {
            try {
                if (Test-Connection -ComputerName $Computer -Count 1 -Quiet) {
                    $getWmiObjectSplat = @{
                        Filter       = $Filter
                        ComputerName = $Computer
                        Namespace    = 'root\CCM\ClientSDK'
                        Class        = 'CCM_SoftwareUpdate'
                    }
                    if ($PSBoundParameters.ContainsKey('Credential')) {
                        $getWmiObjectSplat.Add('Credential', $Credential)
                    }
                    [System.Management.ManagementObject[]]$MissingUpdates = Get-WmiObject @getWmiObjectSplat
                    if ($MissingUpdates -is [Object] -and $MissingUpdates.Count -gt 0) {
                        $MissingUpdates
                    }
                    else {
                        Write-Verbose "No updates found for $Computer"
                    }
                }
                else {
                    Write-Warning "$Computer is not online"
                }
            }
            catch {
                $ErrorMessage = $_.Exception.Message
                Write-Error $ErrorMessage
            }
        }
    }
}
