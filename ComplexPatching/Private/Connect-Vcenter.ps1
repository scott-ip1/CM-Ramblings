function Connect-Vcenter {
    param
    (
        [parameter(Mandatory = $true)]
        [array]$Servers
    )
    $VICreds = Get-StoredCredential -Purpose PowerCLI
    Connect-VIServer -Server $Servers -Credential $VICreds
}