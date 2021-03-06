#region detection/remediation
#region define variables
$Remediate = $false
#endregion define variables

try {
    $WSUS_Server = Get-WsusServer -ErrorAction Stop
}
catch {
    # This is not a WSUS server, or it is in an error state. Return compliant.
    return $true
}

#region helper functions
function Get-WSUSPortNumbers {
    [CmdletBinding()]
    <#
    .SYNOPSIS
        Return the port numbers in use by WSUS
    .DESCRIPTION
        This function will automatically determine the ports in use by WSUS, and return them as a PSCustomObject.
        
        If WSUS is set to use any custom port other than 80/443 it 
            automatically determines the HTTP as noted in the link below
            https://docs.microsoft.com/en-us/windows-server/administration/windows-server-update-services/deploy/2-configure-wsus#configure-ssl-on-the-wsus-server
                ... if you use any port other than 443 for HTTPS traffic, 
                WSUS will send clear HTTP traffic over the port that numerically 
                comes before the port for HTTPS. For example, if you use port 8531 for HTTPS, 
                WSUS will use port 8530 for HTTP.
    .EXAMPLE
        PS C:\> Get-WSUSPortNumbers -WSUSServer (Get-WSUSServer)
    .INPUTS
        [Microsoft.UpdateServices.Internal.BaseApi.UpdateServer]
    .OUTPUTS
        [PSCustomerObject]
    .NOTES
        FileName: Get-WSUSPortNumbers.ps1
        Author:   Cody Mathis
        Contact:  @CodyMathis123
        Created:  6/29/2020
        Updated:  6/29/2020
    #>
    param (
        [Parameter(Mandatory = $true)]
        [object]$WSUSServer
    )
    #region Determine WSUS Port Numbers
    $WSUS_Port1 = $WSUSServer.PortNumber
    $WSUS_IsSSL = $WSUSServer.UseSecureConnection

    switch ($WSUS_IsSSL) {
        $true {
            switch ($WSUS_Port1) {
                443 {
                    $WSUS_Port2 = 80
                }
                default {
                    $WSUS_Port2 = $WSUS_Port1 - 1
                }
            }
        }
        $false {
            $Wsus_Port2 = $null
        }
    }
    #endregion Determine WSUS Port Numbers

    return [PSCustomObject]@{
        WSUSIsSSL = $WSUS_IsSSL
        WSUSPort1 = $WSUS_Port1
        WSUSPort2 = $WSUS_Port2
    }
}
#endregion

switch ($WSUS_Server -is [Microsoft.UpdateServices.Internal.BaseApi.UpdateServer]) {
    $true {
        $WSUSPorts = Get-WSUSPortNumbers -WSUSServer $WSUS_Server

        $WSUS_Port1 = $WSUSPorts.WSUSPort1
        $WSUS_Port2 = $WSUSPorts.WSUSPort2

        $LEDBAT_Enabled = [bool](Get-NetTCPSetting -SettingName InternetCustom -CongestionProvider LEDBAT -ErrorAction SilentlyContinue)
        $CustomPort1Set = [bool](Get-NetTransportFilter -LocalPortStart $WSUS_Port1 -LocalPortEnd $WSUS_Port1 -SettingName InternetCustom -RemotePortStart 0 -RemotePortEnd 65535 -ErrorAction SilentlyContinue)
        if ($null -ne $Wsus_Port2) {
            $CustomPort2Set = [bool](Get-NetTransportFilter -LocalPortStart $WSUS_Port2 -LocalPortEnd $WSUS_Port2 -SettingName InternetCustom -RemotePortStart 0 -RemotePortEnd 65535 -ErrorAction SilentlyContinue)
        }
        else {
            $CustomPort2Set = $true
        }
        switch ($LEDBAT_Enabled -and $CustomPort1Set -and $CustomPort2Set) {
            $true {
                return $true
            }
            $false {
                switch ($LEDBAT_Enabled) {
                    $false {
                        switch ($Remediate) {
                            $true {
                                try {
                                    Set-NetTCPSetting -SettingName InternetCustom -CongestionProvider LEDBAT -ErrorAction Stop
                                }
                                catch {
                                    return $false
                                }
                            }
                        }
                    }
                }
                switch ($CustomPort1Set) {
                    $false {
                        switch ($Remediate) {
                            $true {
                                try {
                                    New-NetTransportFilter -SettingName InternetCustom -LocalPortStart $WSUS_Port1 -LocalPortEnd $WSUS_Port1 -RemotePortStart 0 -RemotePortEnd 65535 -ErrorAction Stop
                                }
                                catch {
                                    return $false
                                }
                            }
                        }
                    }
                }
                switch ($CustomPort2Set) {
                    $false {
                        switch ($Remediate) {
                            $true {
                                try {
                                    New-NetTransportFilter -SettingName InternetCustom -LocalPortStart $WSUS_Port2 -LocalPortEnd $WSUS_Port2 -RemotePortStart 0 -RemotePortEnd 65535 -ErrorAction Stop
                                }
                                catch {
                                    return $false
                                }
                            }
                        }
                    }
                }
                return $Remediate
            }
        }
    }
    $false {
        return $true
    }
}
#endregion detection/remediation
