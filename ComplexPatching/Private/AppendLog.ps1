function AppendLog {
    param (
        [parameter(Mandatory = $true)]
        [string]$Message
    )
    $global:CurrentAction = $Message
    $global:TraceLog += ((Get-Date).ToString() + "`t" + $Message + " `r`n")
}