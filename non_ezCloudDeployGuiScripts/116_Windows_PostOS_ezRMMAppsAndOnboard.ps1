Write-Host -ForegroundColor Cyan "========================================================================================="
Write-Host -ForegroundColor Cyan "             ezRMM Apps and Onboard - Post OS Deployment - ezRMM PRTG Probe"
Write-Host -ForegroundColor Cyan "========================================================================================="
Write-Host -ForegroundColor Cyan ""
Write-Host -ForegroundColor Gray "========================================================================================="
Start-Transcript -Path "C:\ezNetworking\Automation\Logs\ezCloudDeploy_116_Windows_PostOS_ezRMMAppsAndOnboard.log"
Write-Host -ForegroundColor Gray "========================================================================================="
Write-Host -ForegroundColor Gray "Z> Installing Modules."
Set-ExecutionPolicy -ExecutionPolicy Bypass -Scope Process -Force
# Ensure PSGallery is registered and trusted
if (-not (Get-PSRepository -Name 'PSGallery' -ErrorAction SilentlyContinue)) {
    Write-Host -ForegroundColor Yellow "Z> PSGallery not found, registering it..."
    Register-PSRepository -Default
}
Set-PSRepository -Name PSGallery -InstallationPolicy Trusted
Install-Module OSD -Force -Verbose
Import-Module OSD -Force
Install-Module -Name 'Posh-SSH' -Scope AllUsers -Force
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
    "C:\ezNetworking\ezRS",
    "C:\ezNetworking\ezRmon"
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


# Disable sleep and disk sleep
Write-Host -ForegroundColor Gray "========================================================================================="
Write-Host -ForegroundColor Gray "Z> Disabling sleep and disk sleep"
powercfg.exe -change -standby-timeout-ac 0
powercfg.exe -change -disk-timeout-ac 0
powercfg.exe -change -monitor-timeout-ac 480

Write-Host -ForegroundColor Cyan "========================================================================================="
write-host -ForegroundColor Cyan "   User configuration"
Write-Host -ForegroundColor Cyan "========================================================================================="
Write-Host -ForegroundColor Gray "Z> Setting ezadminlocal's password to never expire "
Set-LocalUser -Name "ezAdminLocal" -PasswordNeverExpires $true
Write-Host -ForegroundColor Cyan "========================================================================================="
write-host -ForegroundColor Cyan "   Installing apps and onboarding client to ezRmm"
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


try {
    $ezRmmUrl = "http://support.ez.be/GetAgent/Windows/?cid=$($ezClientConfig.ezRmmId)" + '&aid=0013z00002YbbGCAAZ'
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
write-host -ForegroundColor Cyan "   Removing apps and updating Windows"
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

Stop-Transcript
Write-host ""
Write-host ""
write-host -ForegroundColor Gray "========================================================================================="

# ASCII Art Banner - Customize this section with your own ASCII art
$asciiBanner = @"
                  ___ ____                                            
                 / _ \_  /  _                      _    _             
                |  __// /  | |                    | |  (_)            
                 \___/___|_| |___      _____  _ __| | ___ _ __   __ _ 
                | '_ \ / _ \ __\ \ /\ / / _ \| '__| |/ / | '_ \ / _` |
                | | | |  __/ |_ \ V  V / (_) | |  |   <| | | | | (_| |
                |_| |_|\___|\__| \_/\_/ \___/|_|  |_|\_\_|_| |_|\__, |     
                                                                 __/ |
                                                                |___/ 

            ┏━╸╺━┓   ┏━╸╻  ┏━┓╻ ╻╺┳┓   ╺┳┓┏━╸┏━┓╻  ┏━┓╻ ╻  ┏━╸╻┏┓╻╻┏━┓╻ ╻┏━╸╺┳┓    
            ┣╸ ┏━┛   ┃  ┃  ┃ ┃┃ ┃ ┃┃    ┃┃┣╸ ┣━┛┃  ┃ ┃┗┳┛  ┣╸ ┃┃┗┫┃┗━┓┣━┫┣╸  ┃┃    
            ┗━╸┗━╸   ┗━╸┗━╸┗━┛┗━┛╺┻┛   ╺┻┛┗━╸╹  ┗━╸┗━┛ ╹   ╹  ╹╹ ╹╹┗━┛╹ ╹┗━╸╺┻┛    


"@                                                                                                                        

Write-Host -ForegroundColor Cyan $asciiBanner
write-host -ForegroundColor White "    ez Networking | ezRMM Apps and Onboard - Post OS Deployment - ezRMM PRTG Probe"
write-host -ForegroundColor Gray "========================================================================================="
Write-Host ""
write-host -ForegroundColor Yellow "            Installing Probe Finished." 
write-host -ForegroundColor Yellow "            You can deliver the Probe to the client now."
Write-Host ""

Write-Host ""
write-host -ForegroundColor Gray "            What would you like to do next?`n            [1] Shut down the computer`n            [2] Just close the script`n            [3] Restart the computer`n"


$finishAction = Read-Host -Prompt "            Enter your choice (1-3)"
switch ($finishAction) {
    "1" {
        write-host -ForegroundColor Cyan "   Shutting down the computer in 10 seconds..."
        Start-Sleep -Seconds 5
        Stop-Computer -Force
    }
    "2" {
        write-host -ForegroundColor Cyan "   Exiting the script. Goodbye!"
        Exit
    }
    "3" {
        write-host -ForegroundColor Cyan "   Restarting the computer in 10 seconds..."
        Start-Sleep -Seconds 5
        Restart-Computer -Force
    }
    default {
        Write-Host -ForegroundColor Yellow "Z> Invalid choice. Script will exit without additional actions."
        Exit
    }
}
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