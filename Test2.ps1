[CmdletBinding()]
param(
    [Parameter(Mandatory=$true)]
    [string]$Name,
    
    [Parameter()]
    [switch]$Verbose,
    
    [Parameter()]
    [bool]$Enabled
)

if($Verbose){
    Write-Output "Verbose mode is enabled."
}

if($Enabled){
    Write-Output "$Name is enabled."
} else {
    Write-Output "$Name is not enabled."
}
