Write-Host -ForegroundColor Cyan "========================================================================================="
Write-Host -ForegroundColor Cyan "             ezRMM Apps and Onboard - Post OS Deployment"
Write-Host -ForegroundColor Cyan "========================================================================================="
Write-Host -ForegroundColor Cyan ""
Write-Host -ForegroundColor Gray "========================================================================================="
Start-Transcript -Path "C:\ezNetworking\Automation\Logs\ezCloudDeploy_116_Windows_PostOS_ezRMMAppsAndOnboard.log"
Write-Host -ForegroundColor Gray "========================================================================================="
Write-Host -ForegroundColor Gray "Z> Installing Modules."
Set-ExecutionPolicy -ExecutionPolicy Bypass -Scope Process -Force
Set-PSRepository -Name PSGallery -InstallationPolicy Trusted
Install-Module OSD -Force -Verbose
Import-Module OSD -Force
Install-Module burnttoast
Import-Module burnttoast
Write-Host -ForegroundColor Gray "========================================================================================="
write-host "Z> reading the ezClientConfig.json file"
$ezClientConfig = Get-Content -Path "C:\ezNetworking\Automation\ezCloudDeploy\ezClientConfig.json" | ConvertFrom-Json

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
Set-LocalUser -Name "ezAdminLocal" -PasswordNeverExpires $true
Write-Host -ForegroundColor Cyan "========================================================================================="
write-host -ForegroundColor Cyan "Z> Installing apps and onboarding client to ezRmm"
Write-Host -ForegroundColor Cyan "========================================================================================="

# Install Choco and minimal default packages
Write-Host -ForegroundColor Gray "========================================================================================="
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
choco install googlechrome -y
choco install treesizefree -y
choco install tailblazer -y
choco install notepadplusplus -y
choco install advanced-ip-scanner -y
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
    write-host -ForegroundColor Gray "Z> Downloading ezRmmInstaller.msi from $ezRmmUrl"
    Invoke-WebRequest -Uri $ezRmmUrl -OutFile "C:\ezNetworking\Automation\ezCloudDeploy\ezRmmInstaller.msi"
    Start-Process -FilePath "C:\ezNetworking\Automation\ezCloudDeploy\ezRmmInstaller.msi" -ArgumentList "/quiet" -Wait
    
}
catch {
    Write-Error -ForegroundColor Gray "Z> ezRmm is already installed or had an error $($_.Exception.Message)"
}

Write-Host -ForegroundColor Gray "========================================================================================="
write-host -ForegroundColor Gray "Z> ezRS - Downloading and installing it"
$Splat = @{
    Text = 'Zed: Installing ez Remote Support' , "Downloading and installing... Started $Time"
    Applogo = 'https://iili.io/H8B8JtI.png'
    Sound = 'IM'
}
New-BurntToastNotification @splat 

# Need Fix ezRsInstaller is only 10kb big...
try {
    $ezRsUrl = 'https://get.teamviewer.com/ezNetworkingHost'
    Invoke-WebRequest -Uri $ezRsUrl -OutFile "C:\ezNetworking\Automation\ezCloudDeploy\ezRsInstaller.exe"
    Start-Process -FilePath "C:\ezNetworking\Automation\ezCloudDeploy\ezRsInstaller.exe" -ArgumentList "/S" -Wait
}
catch {
    Write-Error "Z> ezRS is already installed or had an error $($_.Exception.Message)"
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
write-host -ForegroundColor Cyan "Z> Please install TV manually C:\ezNetworking\Automation\ezCloudDeploy\ezRsInstaller.exe"
write-host -ForegroundColor Cyan "Z> You can deliver the computer to the client now."
Read-Host -Prompt "Z> Press any key to exit"
Write-Host -ForegroundColor Cyan "========================================================================================="

Stop-Transcript
Exit

<#
.SYNOPSIS
Installs Chocolatey and minimal default packages and onboards the computer to ezRmm.

.DESCRIPTION
This script installs Chocolatey and minimal default packages. It reads the ezClientConfig.json and onboards the computer to ezRmm.
It also removes Windows Consumer Apps and updates Windows.
.NOTES
Author: Jurgen Verhelst | ez Networking | www.ez.be
#>