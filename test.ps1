[CmdletBinding()]
param(
    [Parameter(Mandatory=$true, HelpMessage="Enter the name of the application.")]
    [string]$Name,
    
    [Parameter(Mandatory=$true, HelpMessage="Choose an option from the list." )]
    [ValidateSet("Option1", "Option2", "Option3")]
    [string]$Option = "Option1",
    
    [Parameter(HelpMessage="Enter an array of values.")]
    [array]$Values,
    
    [Parameter(Mandatory=$true, HelpMessage="Enable the feature?", 
        ValueFromPipelineByPropertyName=$true)]
    [bool]$EnableFeature = $false,
    
    [Parameter(HelpMessage="Use the option?", ValueFromPipelineByPropertyName=$true)]
    [bool]$UseOption,
    
    [Parameter(Mandatory=$true, HelpMessage="Confirm the action?", 
        ValueFromPipelineByPropertyName=$true)]
    [bool]$Confirm = $false
)

Write-Host "Name: $Name"
Write-Host "Option: $Option"
if($Values) { Write-Host "Values: $($Values -join ', ')" }
Write-Host "EnableFeature: $EnableFeature"
if($UseOption) { Write-Host "Option is enabled." }
if($Confirm) { Write-Host "Confirmation received." }
