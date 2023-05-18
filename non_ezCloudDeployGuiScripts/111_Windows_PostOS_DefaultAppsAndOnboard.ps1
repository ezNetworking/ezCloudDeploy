Set-PSRepository -Name 'PSGallery' -InstallationPolicy Trusted
Install-Module OSD
Install-Module burnttoast
Import-Module burnttoast

# Disable "Do Not Disturb" mode (Quiet Hours)
Set-ItemProperty -Path "HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\QuietHours" -Name "Enabled" -Value 0

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


Write-Host -ForegroundColor Gray "========================================================================================="
Start-Transcript -Path "C:\ezNetworking\Automation\Logs\ezCloudDeploy_111_Windows_PostOS_DefaultAppsAndOnboard.log"
Write-Host -ForegroundColor Gray "========================================================================================="

# Use Start-OOBEDeploy to remove the following apps
Write-Host -ForegroundColor Cyan "  Zed says: Use Start-OOBEDeploy to remove apps and update Windows "
Write-Host -ForegroundColor Cyan "            CommunicationsApps,MicrosoftTeams,OfficeHub,People,Skype,Solitaire,Xbox,ZuneMusic,ZuneVideo"
$Params = @{
    Autopilot = $false
    RemoveAppx = "CommunicationsApps","OfficeHub","People","Skype","Solitaire","Xbox","ZuneMusic","ZuneVideo"
    UpdateDrivers = $true
    UpdateWindows = $true
}
Start-OOBEDeploy @Params

# Install Choco and minimal default packages
Write-Host -ForegroundColor Gray "========================================================================================="
write-host " Zed says: Installing Chocolatey"

try {
    Set-ExecutionPolicy Bypass -Scope Process -Force; [System.Net.ServicePointManager]::SecurityProtocol = [System.Net.ServicePointManager]::SecurityProtocol -bor 3072; Invoke-Expression ((New-Object System.Net.WebClient).DownloadString('https://community.chocolatey.org/install.ps1'))
    Start-Sleep -s 30
}
catch {
    Write-Error " Zed says: Chocolatey is already installed or had an error $($_.Exception.Message)"
}

# -y confirm yes for any prompt during the install process
write-host " Zed says: Installing Chocolatey packages"
choco install googlechrome -y
choco install treesizefree -y
choco install tailblazer -y
Write-Host -ForegroundColor Gray "========================================================================================="

# Install ezRmm and ezRS
write-host " Zed says: reading the ezClientConfig.json file"
$ezClientConfig = Get-Content -Path "C:\ezNetworking\Automation\ezCloudDeploy\ezClientConfig.json" | ConvertFrom-Json

write-host " Zed says: Downloading ezRmmInstaller.msi and installing it for customer $($ezClientConfig.ezRmmId)"
$Splat = @{
    Text = 'Zed: Installing ez RMM' , "Downloading and installing... Started $Time"
    Applogo = 'https://iili.io/H8B8JtI.png'
    Sound = 'IM'
}
New-BurntToastNotification @splat 

try {
    $ezRmmUrl = "http://support.ez.be/GetAgent/Msi/?customerId=$($ezClientConfig.ezRmmId)" + '&integratorLogin=jurgen.verhelst%40ez.be'
    write-host " Zed says: Downloading ezRmmInstaller.msi from $ezRmmUrl"
    Invoke-WebRequest -Uri $ezRmmUrl -OutFile "C:\ezNetworking\Automation\ezCloudDeploy\ezRmmInstaller.msi"
    Start-Process -FilePath "C:\ezNetworking\Automation\ezCloudDeploy\ezRmmInstaller.msi" -ArgumentList "/quiet" -Wait
    
}
catch {
    Write-Error " Zed says: ezRmm is already installed or had an error $($_.Exception.Message)"
}

Write-Host -ForegroundColor Gray "========================================================================================="
write-host " Zed says: Downloading and installing ezRS"
write-host " Zed says: Downloading ezRmmInstaller.msi and installing it"
$Splat = @{
    Text = 'Zed: Installing ez Remote Support' , "Downloading and installing... Started $Time"
    Applogo = 'https://iili.io/H8B8JtI.png'
    Sound = 'IM'
}
New-BurntToastNotification @splat 

try {
    $ezRsUrl = 'https://get.teamviewer.com/ezNetworkingHost'
    Invoke-WebRequest -Uri $ezRsUrl -OutFile "C:\ezNetworking\Automation\ezCloudDeploy\ezRsInstaller.exe"
    Start-Process -FilePath "C:\ezNetworking\Automation\ezCloudDeploy\ezRsInstaller.exe" -ArgumentList "/S" -Wait
}
catch {
    Write-Error " Zed says: ezRS is already installed or had an error $($_.Exception.Message)"
}
Write-Host -ForegroundColor Gray "========================================================================================="


$Time = Get-date -Format t
$Splat = @{
    Text = 'Zed: Default apps script finished' , "Installed Choco, ezRMM, ezRS. Finished $Time"
    Applogo = 'https://iili.io/H8B8JtI.png'
    Sound = 'IM'
}
New-BurntToastNotification @splat 
Stop-Transcript

<#
.SYNOPSIS
Installs Chocolatey and minimal default packages and onboards the computer to ezRmm.

.DESCRIPTION
This script installs Chocolatey and minimal default packages. It reads the ezClientConfig.json and onboards the computer to ezRmm.
It also removes Windows Consumer Apps and updates Windows.
.NOTES
Author: Jurgen Verhelst | ez Networking | www.ez.be
#>