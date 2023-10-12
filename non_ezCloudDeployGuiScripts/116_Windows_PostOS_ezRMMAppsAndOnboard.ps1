Write-Host -ForegroundColor Cyan "========================================================================================="
Write-Host -ForegroundColor Cyan "             ezRMM Apps and Onboard - Post OS Deployment - ezRMM Probe"
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

# Disable sleep and disk sleep
Write-Host -ForegroundColor Gray "========================================================================================="
Write-Host -ForegroundColor Gray "Z> Disabling sleep and disk sleep"
powercfg.exe -change -standby-timeout-ac 0
powercfg.exe -change -disk-timeout-ac 0
powercfg.exe -change -monitor-timeout-ac 480

Write-Host -ForegroundColor Cyan "========================================================================================="
write-host -ForegroundColor Cyan "Z> User configuration"
Write-Host -ForegroundColor Cyan "========================================================================================="
Write-Host -ForegroundColor Gray "Z> Setting ezadminlocal's password to never expire "
Set-LocalUser -Name "ezAdminLocal" -PasswordNeverExpires $true
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
    Write-Host -ForegroundColor Gray "Z> Downloading ezRmmInstaller.msi from $ezRmmUrl"
    Invoke-WebRequest -Uri $ezRmmUrl -OutFile "C:\ezNetworking\ezRMM\ezRmmInstaller.msi"
    Start-Process -FilePath "C:\ezNetworking\ezRMM\ezRmmInstaller.msi" -ArgumentList "/quiet" -Wait
    
}
catch {
    Write-Error "Z> ezRmm is already installed or had an error $($_.Exception.Message)"
}

Write-Host -ForegroundColor Gray "========================================================================================="
try {
    $ezRsUrl = 'https://customdesignservice.teamviewer.com/download/windows/v15/q6epc32/TeamViewer_Host_Setup.exe'
    Invoke-WebRequest -Uri $ezRsUrl -OutFile "C:\ezNetworking\ezRS\ezRsInstaller.exe"
    Start-Process -FilePath "C:\ezNetworking\ezRS\ezRsInstaller.exe" -ArgumentList "/S" -Wait
}
catch {
    Write-Error "Z> ezRS is already installed or had an error $($_.Exception.Message)"
}

# Download the DownloadSupportFolder script, run and schedule it
Write-Host -ForegroundColor Gray "========================================================================================="
Write-Host -ForegroundColor Gray "Z> Downloading the DownloadSupportFolder Script, runing and scheduling it"
try {
    $DownloadSupportFolderResponse = Invoke-WebRequest -Uri "https://raw.githubusercontent.com/ezNetworking/ezCloudDeploy/master/non_ezCloudDeployGuiScripts/140_Windows_PostOS_DownloadSupportFolders.ps1" -UseBasicParsing 
    $DownloadSupportFolderScript = $DownloadSupportFolderResponse.content
    Write-Host -ForegroundColor Gray "Z> Saving the Onboard script to c:\ezNetworking\DownloadSupportFolder.ps1"
    $DownloadSupportFolderScriptPath = "c:\ezNetworking\DownloadSupportFolder.ps1"
    $DownloadSupportFolderScript | Out-File -FilePath $DownloadSupportFolderScriptPath -Encoding UTF8

    Write-Host -ForegroundColor Gray "Z> Running the DownloadSupportFolder script"
    . $DownloadSupportFolderScriptPath -remoteDirectory 'SupportFolderServers'

    Write-Host -ForegroundColor Gray "Z> Scheduling the DownloadSupportFolder script to run every Sunday at 14:00"

    # Create a new scheduled task
    $action = New-ScheduledTaskAction -Execute "powershell.exe" -Argument "-File $DownloadSupportFolderScriptPath -remoteDirectory 'SupportFolderServers'"
    $trigger = New-ScheduledTaskTrigger -Weekly -DaysOfWeek Sunday -At 14:00
    $settings = New-ScheduledTaskSettingsSet
    $principal = New-ScheduledTaskPrincipal -UserId "SYSTEM"
    Register-ScheduledTask -TaskName "ezDownloadSupportFolder" -Action $action -Trigger $trigger -Settings $settings -Principal $principal

}
catch {
    Write-Error " Z> I was unable to download the DownloadSupportFolder script."
}

Write-Host -ForegroundColor Gray "========================================================================================="
# Download the JoinDomainAtFirstLogin.ps1 script from github
Write-Host -ForegroundColor Gray " Z> Downloading and shortcutting the JoinDomainAtFirstLogin GUI."
try {
    $JoinDomainAtFirstLoginResponse = Invoke-WebRequest -Uri "https://raw.githubusercontent.com/ezNetworking/ezCloudDeploy/master/non_ezCloudDeployGuiScripts/101_Windows_PostOOBE_JoinDomainAtFirstLogin.ps1" -UseBasicParsing 
    $JoinDomainAtFirstLoginScript = $JoinDomainAtFirstLoginResponse.content
    Write-Host -ForegroundColor Gray " Z> Saving the AD Join script to c:\ezNetworking\Automation\ezCloudDeploy\Scripts"
    $JoinDomainAtFirstLoginScriptPath = "c:\ezNetworking\Automation\ezCloudDeploy\Scripts\JoinDomainAtFirstLogin.ps1"
    $JoinDomainAtFirstLoginScript | Out-File -FilePath $JoinDomainAtFirstLoginScriptPath -Encoding UTF8
    }
catch {
    Write-Error " Z> I was unable to download the JoinDomainAtFirstLogin script from github"
}

try {
    $shortcutPath = "$([Environment]::GetFolderPath('CommonDesktopDirectory'))\Join Domain.lnk"
    $iconPath = "C:\Windows\System32\shell32.dll,217"
    $shell = New-Object -ComObject WScript.Shell
    $shortcut = $shell.CreateShortcut($shortcutPath)
    $shortcut.TargetPath = "powershell.exe"
    $shortcut.Arguments = "-ExecutionPolicy Bypass -File `"$JoinDomainAtFirstLoginScriptPath`""
    $shortcut.IconLocation = $iconPath
    $shortcut.Save()
    
}
catch {
    Write-Error " Z> I was unable to create a shortcut for the JoinDomainAtFirstLogin script."
}

Write-Host -ForegroundColor Gray "========================================================================================="
# Download the InstallEzRmonProbe.ps1
Write-Host -ForegroundColor Gray " Z> Downloading and shortcutting the InstallEzRmonProbe script."
try {
    $ScriptResponse = Invoke-WebRequest -Uri "https://raw.githubusercontent.com/ezNetworking/ezCloudDeploy/master/non_ezCloudDeployGuiScripts/141_Windows_PostOS_InstallezRMonProbe.ps1" -UseBasicParsing 
    $Script = $ScriptResponse.content
    Write-Host -ForegroundColor Gray " Z> Saving the InstallEzRmonProbe script to c:\ezNetworking\Automation\ezCloudDeploy\Scripts"
    $ScriptPath = "c:\ezNetworking\Automation\ezCloudDeploy\Scripts\InstallEzRmonProbe.ps1"
    $Script | Out-File -FilePath $ScriptPath -Encoding UTF8
    }
catch {
    Write-Error " Z> I was unable to download the InstallEzRmonProbe script from github"
}

try {
    $shortcutPath = "$([Environment]::GetFolderPath('CommonDesktopDirectory'))\Install ezRMon Probe.lnk"
    $iconPath = "C:\Windows\System32\shell32.dll,217"
    $shell = New-Object -ComObject WScript.Shell
    $shortcut = $shell.CreateShortcut($shortcutPath)
    $shortcut.TargetPath = "powershell.exe"
    $shortcut.Arguments = "-ExecutionPolicy Bypass -File `"$ScriptPath`""
    $shortcut.IconLocation = $iconPath
    $shortcut.Save()
    
}
catch {
    Write-Error " Z> I was unable to create a shortcut for the InstallEzRmonProbe script."
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
write-host -ForegroundColor Cyan "Z> Installing Probe Finished." 
write-host -ForegroundColor Cyan "Z> You can deliver the Probe to the client now."
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