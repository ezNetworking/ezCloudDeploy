Write-Host -ForegroundColor Cyan "========================================================================================="
Write-Host -ForegroundColor Cyan "             Default Apps and Onboard Client - Post OS Deployment"
Write-Host -ForegroundColor Cyan "========================================================================================="
Write-Host -ForegroundColor Cyan ""
Write-Host -ForegroundColor Gray "========================================================================================="
Start-Transcript -Path "C:\ezNetworking\Automation\Logs\ezCloudDeploy_111_Windows_PostOS_DefaultAppsAndOnboard.log"
Write-Host -ForegroundColor Gray "========================================================================================="
Write-Host -ForegroundColor Gray "Z> Setting up Powershell and Repo trusted."
Set-ExecutionPolicy -ExecutionPolicy Bypass -Scope Process -Force
Set-PSRepository -Name PSGallery -InstallationPolicy Trusted
Write-Host -ForegroundColor Gray "Z> Installing OSD Module."
Install-Module OSD -Force -Verbose
Import-Module OSD -Force
Write-Host -ForegroundColor Gray "Z> Installing Burned Toast Module."
Install-Module burnttoast
Import-Module burnttoast
Write-Host -ForegroundColor Gray "========================================================================================="
write-host "Z> reading the ezClientConfig.json file"
$ezClientConfig = Get-Content -Path "C:\ezNetworking\Automation\ezCloudDeploy\ezClientConfig.json" | ConvertFrom-Json

# Checking if the folders exist, if not create them
$foldersToCheck = @(
    "C:\ezNetworking\Automation\Logs",
    "C:\ezNetworking\Automation\Scripts",
    "C:\ezNetworking\Apps",
    "C:\ezNetworking\ezRMM",
    "C:\ezNetworking\ezRS"
)

foreach ($folder in $foldersToCheck) {
    $pathExists = Test-Path -Path $folder
    if ($pathExists) {
        Write-Output "Computer $env:COMPUTERNAME has the folder $folder"
    } else {
        Write-Output "Creating folder $folder on $env:COMPUTERNAME"
        New-Item -Path $folder -ItemType Directory
    }
}

# Set Do Not Disturb to Off (Dirty Way, not found a better one :) :)

if ($ezClientConfig.TaskSeqType -eq "AzureAD") {
    write-host "Z> AzureAD Task Sequence, skipping Focus Assist"
}  
else {
    write-host "Z> Setting Focus Assist to Off"
    Add-Type -AssemblyName System.Windows.Forms
    [System.Windows.Forms.SendKeys]::SendWait("(^{ESC})")   
    Start-Sleep -Milliseconds 500   
    [System.Windows.Forms.SendKeys]::SendWait("(Focus Assist)")   
    Start-Sleep -Milliseconds 200   
    [System.Windows.Forms.SendKeys]::SendWait("{ENTER}")   
    Start-Sleep -Milliseconds 700  
    [System.Windows.Forms.SendKeys]::SendWait("{TAB} ")   
    Start-Sleep -Milliseconds 700  
    [System.Windows.Forms.SendKeys]::SendWait("{TAB} ")   
    Start-Sleep -Milliseconds 700  
    [System.Windows.Forms.SendKeys]::SendWait("{TAB}{TAB}")   
    Start-Sleep -Milliseconds 200   
    [System.Windows.Forms.SendKeys]::SendWait("{ENTER}")   
    Start-Sleep -Milliseconds 700   
    [System.Windows.Forms.SendKeys]::SendWait("{TAB}{TAB} ")  
    Start-Sleep -Milliseconds 200   
    [System.Windows.Forms.SendKeys]::SendWait("{ENTER}") 
    Start-Sleep -Milliseconds 500     
    [System.Windows.Forms.SendKeys]::SendWait("(%{F4})")  
}

# Send the toast notification
$Time = Get-date -Format t
$Btn = New-BTButton -Content 'OK' -arguments 'ok'
$Splat = @{
    Text = 'Zed: Starting Installs' , "Let's give this PC some apps and settings. Started $Time"
    Applogo = 'https://iili.io/H8B8JtI.png'
    Sound = 'IM'
    Button = $Btn
    HeroImage = 'https://iili.io/HU77iLN.jpg'
}
New-BurntToastNotification @splat 


Write-Host -ForegroundColor Cyan "========================================================================================="
write-host -ForegroundColor Cyan "Z> User configuration"
Write-Host -ForegroundColor Cyan "========================================================================================="
Write-Host -ForegroundColor Gray "Z> Setting ezadminlocal's password to never expire "
if (Get-LocalUser -Name "ezAdminLocal" -ErrorAction SilentlyContinue) {
    Set-LocalUser -Name "ezAdminLocal" -PasswordNeverExpires $true
    Write-Host -ForegroundColor Gray "Z> ezAdminLocal user found and password set to never expire."
} else {
    Write-Host -ForegroundColor Yellow "Z> No ezAdminLocal user found, probably an AzureAD install."
}

Write-Host -ForegroundColor Cyan "========================================================================================="
write-host -ForegroundColor Cyan "Z> Installing apps and onboarding client to ezRmm"
Write-Host -ForegroundColor Cyan "========================================================================================="

# Install Choco and minimal default packages
write-host -ForegroundColor White "Z> Installing Chocolatey"

try {
    Set-ExecutionPolicy Bypass -Scope Process -Force; [System.Net.ServicePointManager]::SecurityProtocol = [System.Net.ServicePointManager]::SecurityProtocol -bor 3072; Invoke-Expression ((New-Object System.Net.WebClient).DownloadString('https://community.chocolatey.org/install.ps1'))
    Start-Sleep -s 30
}
catch {
    Write-Error "Z> Chocolatey is already installed or had an error $($_.Exception.Message)"
}

# -y confirm yes for any prompt during the install process
write-host "Z> Installing Chocolatey packages"
choco install googlechrome -y --ignore-checksums
choco install treesizefree -y --ignore-checksums
Write-Host -ForegroundColor Gray "========================================================================================="


# Install ezRmm and ezRS
write-host -ForegroundColor White "Z> ezRMM - Downloading and installing it for customer $($ezClientConfig.ezRmmId)"

$Splat = @{
    Text = 'Zed: Installing ez RMM' , "Downloading and installing... Started $Time"
    Applogo = 'https://iili.io/H8B8JtI.png'
    Sound = 'IM'
}
New-BurntToastNotification @splat 

try {
    $ezRmmUrl = "http://support.ez.be/GetAgent/Msi/?customerId=$($ezClientConfig.ezRmmId)" + '&integratorLogin=jurgen.verhelst%40ez.be'
    Write-Host -ForegroundColor Gray "Z> Downloading ezRmmInstaller.msi from $ezRmmUrl"
    Invoke-WebRequest -Uri $ezRmmUrl -OutFile "C:\ezNetworking\ezRMM\ezRmmInstaller.msi"
    Start-Process -FilePath "C:\ezNetworking\ezRMM\ezRmmInstaller.msi" -ArgumentList "/quiet" -Wait
    
}
catch {
    Write-Error "Z> ezRmm is already installed or had an error $($_.Exception.Message)"
}

<#
 # {
Write-Host -ForegroundColor Gray "========================================================================================="
write-host -ForegroundColor White "Z> ezRS - Downloading and installing it. "
try {
$ConfigId = 'q6epc32'
$Version = 'v15'
[System.Net.ServicePointManager]::SecurityProtocol = 'Tls12'
$UrlDownload = "https://customdesignservice.teamviewer.com/download/windows/$Version/$ConfigId/TeamViewer_Host_Setup.exe"
$FileDownload = "C:\ezNetworking\ezRS\ezRsInstaller.exe"
( New-Object System.Net.WebClient ).DownloadFile( $UrlDownload , $FileDownload )
}
catch {
    Write-Error "Z> ezRS failed to download: $($_.Exception.Message)"
}

:Enter a comment or description}
#>
Write-Host -ForegroundColor Gray "========================================================================================="
# Download the Office uninstall script from github
Write-Host -ForegroundColor White "Z> Office uninstall."
try {
    $DefaultAppsAndOnboardResponse = Invoke-WebRequest -Uri "https://raw.githubusercontent.com/ezNetworking/ezCloudDeploy/master/non_ezCloudDeployGuiScripts/114_Windows_PostOS_UninstallOffice.ps1" -UseBasicParsing 
    $DefaultAppsAndOnboardScript = $DefaultAppsAndOnboardResponse.content
    Write-Host -ForegroundColor Gray "Z> Saving the script to c:\ezNetworking\Automation\ezCloudDeploy\Scripts\"
    $DefaultAppsAndOnboardScriptPath = "c:\ezNetworking\Automation\ezCloudDeploy\Scripts\UninstallOffice365.ps1"
    $DefaultAppsAndOnboardScript | Out-File -FilePath $DefaultAppsAndOnboardScriptPath -Encoding UTF8
}
catch {
    Write-Error " Z> I was unable to download the Office Uninstall script."
}

$scriptPath = "c:\ezNetworking\Automation\ezCloudDeploy\Scripts\UninstallOffice365.ps1"
# Running the Office uninstall script
Write-Host -ForegroundColor Gray "Z> Running the Office uninstall script."

$process = Start-Process -FilePath "powershell.exe" -ArgumentList "-NoProfile -ExecutionPolicy Bypass -File `"$scriptPath`"" -PassThru

# Wait for the process to complete
$process.WaitForExit()

# Check the exit code of the process
$exitCode = $process.ExitCode

if ($exitCode -eq 0) {
    # Process completed successfully
    Write-Host -ForegroundColor gray "Z> Office Uninstall Script execution finished."
} else {
    # Process encountered an error
    Write-Error "Z> Office Uninstall Script execution failed with exit code: $exitCode"
}

# Download the Office Install script from github
Write-Host -ForegroundColor White "Z> Office 365 Install."
try {
    $DefaultAppsAndOnboardResponse = Invoke-WebRequest -Uri "https://raw.githubusercontent.com/ezNetworking/ezCloudDeploy/master/non_ezCloudDeployGuiScripts/115_Windows_PostOS_InstallOffice.ps1" -UseBasicParsing 
    $DefaultAppsAndOnboardScript = $DefaultAppsAndOnboardResponse.content
    Write-Host -ForegroundColor Gray "Z> Saving the script to c:\ezNetworking\Automation\ezCloudDeploy\Scripts\"
    $DefaultAppsAndOnboardScriptPath = "c:\ezNetworking\Automation\ezCloudDeploy\Scripts\InstallOffice365.ps1"
    $DefaultAppsAndOnboardScript | Out-File -FilePath $DefaultAppsAndOnboardScriptPath -Encoding UTF8
}
catch {
    Write-Error "Z> I was unable to download the Office Install script."
}

# Running the Office Install script
$scriptPath = "c:\ezNetworking\Automation\ezCloudDeploy\Scripts\InstallOffice365.ps1"

Write-Host -ForegroundColor Gray "Z> Running the Office Install script."

$process = Start-Process -FilePath "powershell.exe" -ArgumentList "-NoProfile -ExecutionPolicy Bypass -File `"$scriptPath`"" -PassThru

# Wait for the process to complete
$process.WaitForExit()

# Check the exit code of the process
$exitCode = $process.ExitCode

if ($exitCode -eq 0) {
    # Process completed successfully
    Write-Host -ForegroundColor Gray "Z> Office 365 Install Script execution finished."
} else {
    # Process encountered an error
    Write-Error "Z> Office 365 Install Script execution failed with exit code: $exitCode"
}



Write-Host -ForegroundColor Cyan "========================================================================================="
write-host -ForegroundColor Cyan "Z> Removing apps and updating Windows"
Write-Host -ForegroundColor Cyan "========================================================================================="
Write-Host -ForegroundColor Gray "Z> Use Start-OOBEDeploy to remove apps and update Windows "
Write-Host -ForegroundColor Gray "   CommunicationsApps,MicrosoftTeams,OfficeHub,People,Skype,Solitaire,Xbox,ZuneMusic,ZuneVideo"
$Params = @{
    Autopilot = $false
    RemoveAppx = "CommunicationsApps","OfficeHub","People","Skype","Solitaire","Xbox","ZuneMusic","ZuneVideo"
    UpdateDrivers = $true
    UpdateWindows = $true
}
Start-OOBEDeploy @Params



$Time = Get-date -Format t
$Splat = @{
    Text = 'Zed: Default apps script finished' , "Installed Choco, ezRMM, Office 365, ezRS Finished $Time"
    Applogo = 'https://iili.io/H8B8JtI.png'
    Sound = 'IM'
}
New-BurntToastNotification @splat 

Write-Host -ForegroundColor Cyan "========================================================================================="
write-host -ForegroundColor Cyan "Z> Installing client Finished." 
write-host -ForegroundColor Cyan "Z> You can deliver the computer to the client now."

Stop-Transcript
$exitConfirmation = Read-Host -Prompt "Z> Are you ready to exit the script? (yes/no)"
if ($exitConfirmation -eq "yes") {
    Write-Host -ForegroundColor Cyan "Z> Exiting the script. Goodbye!"
} else {
    Write-Host -ForegroundColor Yellow "Z> Script will remain open. Perform any additional tasks as needed."
}
Exit
Write-Host -ForegroundColor Cyan "========================================================================================="


<#
.SYNOPSIS
Installs Chocolatey and minimal default packages and onboards the computer to ezRmm.

.DESCRIPTION
This script installs Chocolatey and minimal default packages. It reads the ezClientConfig.json and onboards the computer to ezRmm.
It also removes Windows Consumer Apps and updates Windows.
.NOTES
Author: Jurgen Verhelst | ez Networking | www.ez.be
#>