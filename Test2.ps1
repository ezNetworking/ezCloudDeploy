[CmdletBinding()]
param(
    [Parameter(Mandatory=$true)]
    [string]$Name,
    
    [Parameter(Mandatory=$true)]
    [ValidateSet("Option1", "Option2", "Option3")]
    [string]$Option,
    
    [Parameter()]
    [array]$Values,
    
    [Parameter(Mandatory=$true)]
    [bool]$EnableFeature,
    
    [Parameter()]
    [bool]$UseOption,
    
    [Parameter(Mandatory=$true)]
    [bool]$Confirm
)

Write-Host "Name: $Name"
Write-Host "Option: $Option"
Write-Host "Values: $($Values -join ', ')"
Write-Host "EnableFeature: $EnableFeature"
Write-Host "UseOption: $UseOption"
Write-Host "Confirm: $Confirm"

if($UseOption){
    Write-Host "Option is enabled."
}

if($Confirm){
    Write-Host "Confirmation received."
}
