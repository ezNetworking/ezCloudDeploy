Write-Host -ForegroundColor Cyan "========================================================================================="
Write-Host -ForegroundColor Cyan "             Default Apps and Onboard Client - Post OS Deployment"
Write-Host -ForegroundColor Cyan "========================================================================================="
Write-Host -ForegroundColor Cyan ""
Write-Host -ForegroundColor Gray "========================================================================================="
Start-Transcript -Path "C:\ezNetworking\Automation\Logs\ezCloudDeploy_112_Windows_PostOS_DefaultAppsAndOnboard_LocalAD.log"
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
    # Disable Focus Assist by updating the registry
    Set-ItemProperty -Path "HKCU:\Software\Microsoft\Windows\CurrentVersion\Notifications\Settings" `
    -Name "NOC_GLOBAL_SETTING_TOASTS_ENABLED" `
    -Value 0

    # Confirm the change
    Get-ItemProperty -Path "HKCU:\Software\Microsoft\Windows\CurrentVersion\Notifications\Settings" `
    -Name "NOC_GLOBAL_SETTING_TOASTS_ENABLED"
    Write-Host -ForegroundColor Gray "Z> Focus Assist set to Off"
}

# Send the toast notification
$Time = Get-date -Format t
$Btn = New-BTButton -Content 'OK' -arguments 'ok'
$Splat = @{
    Text = 'Z> Starting Installs' , "Let's give this PC some apps and settings. Started $Time"
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
# choco install treesizefree -y --ignore-checksums
choco install dotnet-8.0-desktopruntime -y
Write-Host -ForegroundColor Gray "========================================================================================="



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

# Check if we're running in OOBE context or post-OS
$isInOOBE = $false
try {
    # Method 1: Check OOBE registry state
    $oobeStatus = Get-ItemProperty -Path "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Setup\State" -Name "ImageState" -ErrorAction SilentlyContinue
    if ($oobeStatus -and ($oobeStatus.ImageState -eq "IMAGE_STATE_GENERALIZE_RESEAL_TO_OOBE" -or $oobeStatus.ImageState -eq "IMAGE_STATE_SPECIALIZE_RESEAL_TO_OOBE")) {
        $isInOOBE = $true
    }
    
    # Method 2: Check if OOBE process is running
    $oobeProcess = Get-Process -Name "oobe" -ErrorAction SilentlyContinue
    if ($oobeProcess) {
        $isInOOBE = $true
    }
    
    # Method 3: Check if we're running as SYSTEM (common in OOBE Shift+F10)
    $currentUser = [System.Security.Principal.WindowsIdentity]::GetCurrent().Name
    if ($currentUser -eq "NT AUTHORITY\SYSTEM") {
        Write-Host -ForegroundColor Yellow "Z> Running as SYSTEM - likely OOBE context (Shift+F10)"
        $isInOOBE = $true
    }
    
    Write-Host -ForegroundColor Gray "Z> OOBE Detection Results:"
    Write-Host -ForegroundColor Gray "   Current User: $currentUser"
    Write-Host -ForegroundColor Gray "   ImageState: $($oobeStatus.ImageState)"
    Write-Host -ForegroundColor Gray "   OOBE Process Running: $(if($oobeProcess){'Yes'}else{'No'})"
    Write-Host -ForegroundColor Gray "   Detected OOBE Context: $(if($isInOOBE){'Yes'}else{'No'})"
    
} catch {
    Write-Host -ForegroundColor Yellow "Z> Could not determine OOBE status: $($_.Exception.Message)"
    Write-Host -ForegroundColor Yellow "Z> Assuming post-OOBE environment"
    $isInOOBE = $false
}

if ($isInOOBE) {
    Write-Host -ForegroundColor Green "Z> OOBE Mode Detected - Using Start-OOBEDeploy method"
    Write-Host -ForegroundColor Gray "Z> Removing apps: CommunicationsApps,OfficeHub,People,Skype,Solitaire,Xbox,ZuneMusic,ZuneVideo"
    $Params = @{
        Autopilot = $false
        RemoveAppx = "CommunicationsApps","OfficeHub","People","Skype","Solitaire","Xbox","ZuneMusic","ZuneVideo"
        UpdateDrivers = $true
        UpdateWindows = $true
    }
    try {
        Start-OOBEDeploy @Params
        Write-Host -ForegroundColor Green "Z> Start-OOBEDeploy completed successfully"
    } catch {
        Write-Host -ForegroundColor Red "Z> Start-OOBEDeploy failed: $($_.Exception.Message)"
        Write-Host -ForegroundColor Yellow "Z> Falling back to alternative app removal method"
        # Fall back to post-OOBE method
        Invoke-PostOOBEAppRemoval
    }
} else {
    Write-Host -ForegroundColor Green "Z> Post-OOBE Mode Detected - Using alternative app removal method"
    Invoke-PostOOBEAppRemoval
}

# Function for post-OOBE app removal and updates
function Invoke-PostOOBEAppRemoval {
    Write-Host -ForegroundColor Gray "Z> Removing unwanted apps using Get-AppxPackage method"
    
    $appsToRemove = @(
        "*Microsoft.BingNews*",
        "*Microsoft.GetHelp*",
        "*Microsoft.Getstarted*",
        "*Microsoft.Messaging*",
        "*Microsoft.Microsoft3DViewer*",
        "*Microsoft.MicrosoftOfficeHub*",
        "*Microsoft.MicrosoftSolitaireCollection*",
        "*Microsoft.Office.OneNote*",
        "*Microsoft.People*",
        "*Microsoft.Print3D*",
        "*Microsoft.SkypeApp*",
        "*Microsoft.Wallet*",
        "*Microsoft.Xbox.TCUI*",
        "*Microsoft.XboxApp*",
        "*Microsoft.XboxGameOverlay*",
        "*Microsoft.XboxGamingOverlay*",
        "*Microsoft.XboxIdentityProvider*",
        "*Microsoft.XboxSpeechToTextOverlay*",
        "*Microsoft.ZuneMusic*",
        "*Microsoft.ZuneVideo*",
        "*Microsoft.YourPhone*",
        "*Microsoft.WindowsCommunicationsApps*"
    )
    
    foreach ($app in $appsToRemove) {
        try {
            $packages = Get-AppxPackage -Name $app -AllUsers -ErrorAction SilentlyContinue
            if ($packages) {
                $packages | Remove-AppxPackage -ErrorAction SilentlyContinue
                Write-Host -ForegroundColor Gray "Z> Removed package: $app"
            }
            
            $provisionedPackages = Get-AppxProvisionedPackage -Online | Where-Object DisplayName -like $app -ErrorAction SilentlyContinue
            if ($provisionedPackages) {
                $provisionedPackages | Remove-AppxProvisionedPackage -Online -ErrorAction SilentlyContinue
                Write-Host -ForegroundColor Gray "Z> Removed provisioned package: $app"
            }
        } catch {
            Write-Host -ForegroundColor Yellow "Z> Could not remove $app : $($_.Exception.Message)"
        }
    }
    
    # Handle Windows Updates separately for post-OOBE
    Write-Host -ForegroundColor Gray "Z> Checking for Windows Updates..."
    try {
        if (-not (Get-Module -ListAvailable -Name PSWindowsUpdate)) {
            Install-Module PSWindowsUpdate -Force -Scope CurrentUser -ErrorAction SilentlyContinue
        }
        Import-Module PSWindowsUpdate -ErrorAction SilentlyContinue
        
        $updates = Get-WindowsUpdate -ErrorAction SilentlyContinue
        if ($updates) {
            Write-Host -ForegroundColor Gray "Z> Installing $($updates.Count) Windows Updates..."
            Install-WindowsUpdate -AcceptAll -IgnoreReboot -ErrorAction SilentlyContinue
        } else {
            Write-Host -ForegroundColor Gray "Z> No Windows Updates available"
        }
    } catch {
        Write-Host -ForegroundColor Yellow "Z> Windows Update check failed: $($_.Exception.Message)"
        Write-Host -ForegroundColor Gray "Z> Updates can be installed manually later"
    }
}

#Region Synch ez Client Folders from FTP
Write-Host ""
Write-Host -ForegroundColor Cyan "========================================================================================="
write-host -ForegroundColor Cyan "Z> Synching ez Client Folders"
Write-Host -ForegroundColor Cyan "========================================================================================="

# Define function to handle SFTP file download
function Process-SFTPItems {
    param(
        $SftpSession,
        [string]$LocalPath,
        [string]$RemotePath
    )
    
    $remoteItems = Get-SFTPChildItem -SFTPSession $SftpSession -Path $RemotePath
    Write-Host "Found $($remoteItems.Count) items in the remote path: $RemotePath"
    
    foreach ($remoteItem in $remoteItems) {
        $localDir = $LocalPath

        if ($remoteItem.IsDirectory) {
            $localDir = Join-Path -Path $LocalPath -ChildPath $remoteItem.Name
            if (!(Test-Path $localDir)) {
                Write-Host "Creating local directory: $localDir"
                New-Item -ItemType Directory -Path $localDir | Out-Null
            }
            Process-SFTPItems -SftpSession $SftpSession -LocalPath $localDir -RemotePath $remoteItem.FullName
        } elseif ($remoteItem.IsRegularFile) {
            Write-Host "Downloading file: $($remoteItem.FullName) to $localDir"
            Get-SFTPItem -SFTPSession $SftpSession -Path $remoteItem.FullName -Destination $localDir -Force
        }
    }
}

# 1.0 Set the security protocol to TLS 1.2
Write-Host "Z> 1.0 Setting Security Protocol to TLS 1.2..."
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12

# 1.1 Install the NuGet provider if it's not installed
Write-Host "Z> 1.1 Checking and installing the NuGet provider if necessary..."
try {
    Install-PackageProvider -Name NuGet -Force -Scope CurrentUser -ForceBootstrap -ErrorAction Stop
    Write-Host "Z> 1.1.1 NuGet provider installed or already present."
} catch {
    Write-Host "Z> 1.1.2 Error: Failed to install the NuGet provider. Exception: $($_.Exception.Message)"
    Stop-TranscriptSafely
    return
}

# 1.1 Ensure the PSGallery repository is trusted
Write-Host "Z> 1.2 Ensuring the PSGallery repository is trusted..."
Set-PSRepository -Name PSGallery -InstallationPolicy Trusted

# 1.3 Setup Execution Policy
Write-Host "Z> 1.3 Setting Execution Policy to RemoteSigned for the current session..."
Set-ExecutionPolicy -ExecutionPolicy RemoteSigned -Scope Process -Force

# 1.4 Install and import the Posh-SSH module
Write-Host "Z> 1.4 Installing and importing the Posh-SSH module"
$moduleInstalled = Get-Module -ListAvailable -Name 'Posh-SSH'

if (-not $moduleInstalled) {
    Write-Host "Z> 1.4.1 Posh-SSH module not found. Attempting to install..."
    try {
        Install-Module -Name 'Posh-SSH' -AllowClobber -Force -ErrorAction Stop
        Write-Host "Z> 1.4.2 Posh-SSH module installed successfully."
    } catch {
        Write-Host "Z> 1.4.2 Error: Failed to install the Posh-SSH module. Exception: $($_.Exception.Message)"
        Stop-Transcript
        return
    }
} else {
    Write-Host "Z> 1.4.1 Posh-SSH module is already installed."
}

# 1.5 Import the Posh-SSH module
try {
    Import-Module -Name 'Posh-SSH' -ErrorAction Stop
    Write-Host "Z> 1.4.3 Posh-SSH module imported successfully."
} catch {
    Write-Host "Z> 1.4.3 Error: Failed to import the Posh-SSH module. Exception: $($_.Exception.Message)"
    Stop-Transcript
    return
}

Write-Host "Z> 1.4.1 Posh-SSH module is already installed."

# 2. Define file and directory locations
$localDirectory = "C:\ezNetworking\"
$ftpRemoteDirectory = "/SupportFolderClients"


# 2.2 Check if local directory exists, if not create it
if (-not (Test-Path $localDirectory)) {
    Write-Host "Z> 2.2.1 Local directory $localDirectory does not exist. Creating directory..."
    try {
        New-Item -ItemType Directory -Path $localDirectory -Force
        Write-Host "Z> 2.2.2 Directory created successfully."
    } catch {
        Write-Host "Z> 2.2.2 Error: Failed to create local directory. Exception: $($_.Exception.Message)"
        Stop-Transcript
        return
    }
} else {
    Write-Host "Z> 2.2.1 Local directory $localDirectory already exists."
}

# 2.3 Connect to the SFTP server and download the file
Write-Host "Z> 2.3 Connecting to SFTP server at ftp.driveHQ.com..."
try {
    $SftpSession = New-SFTPSession -ComputerName "ftp.driveHQ.com" -Credential (New-Object -TypeName System.Management.Automation.PSCredential -ArgumentList "ezpublic", (ConvertTo-SecureString "MakesYourNetWork" -AsPlainText -Force)) -Port 22 -AcceptKey -ErrorAction Stop
    
    # Call the Process-SFTPItems function to download files
    Process-SFTPItems -SftpSession $SftpSession -LocalPath $localDirectory -RemotePath $ftpRemoteDirectory
    
    Write-Host "Z> 2.3.1 Download completed. Disconnecting from SFTP server..."
    Remove-SFTPSession -SFTPSession $SftpSession
} catch {
    Write-Host "Z> 2.3.2 Error: Failed to connect to SFTP server. Exception: $($_.Exception.Message)"
    Stop-Transcript
    return
}
#EndRegion Synch ez Client Folders from FTP

#Region Install ez Support Companion
Write-Host ""
Write-Host -ForegroundColor Cyan "========================================================================================="
write-host -ForegroundColor Cyan "Z> Installing ez Support Companion"
Write-Host -ForegroundColor Cyan "========================================================================================="
$installerPath = "C:\ezNetworking\ez Support Companion\ez Support Companion Setup.msi"

# 2.4 Check if the file was downloaded successfully
if (!(Test-Path $installerPath)) {
    Write-Host "Z> 2.4 Error: Installer file still not found after FTP download. skipping install."
} else {
    Write-Host "Z> 2.4 Installer file downloaded successfully. Proceeding with installation."
}


# 2.5 Proceed with the installation of the .msi file
Write-Host "Z> 2.5 Starting installation of ez Support Companion using the MSI installer..."
try {
    $installResult = Start-Process -FilePath "msiexec.exe" -ArgumentList "/i `"$installerPath`" /qn" -Wait -PassThru
    
    if ($installResult.ExitCode -eq 0) {
        Write-Host "Z> 2.5.1 MSI Installation completed successfully."
    } else {
        Write-Host "Z> 2.5.1 MSI Installation failed with exit code $($installResult.ExitCode). Please check logs for details."
        Stop-Transcript
        return
    }
} catch {
    Write-Host "Z> 2.5.2 Error during installation. Exception: $($_.Exception.Message)"
    Stop-Transcript
    return
}

Write-Host "Z> 2.6 ez Support Companion MSI client installed and configured successfully."
#EndRegion Install ez Support Companion

#Region Install ezRmm and ezRS
Write-Host -ForegroundColor Cyan "========================================================================================="
write-host -ForegroundColor Cyan "Z> Installing ez RMM for customer $($ezClientConfig.ezRmmId)"
Write-Host -ForegroundColor Cyan "========================================================================================="

$Splat = @{
    Text = 'Z> Installing ez RMM' , "Downloading and installing... Started $Time"
    Applogo = 'https://iili.io/H8B8JtI.png'
    Sound = 'IM'
}
New-BurntToastNotification @splat 

try {
    $installer = "C:\ezNetworking\ezRMM\ezRmmInstaller.msi"
    $ezRmmUrl = "http://support.ez.be/GetAgent/Windows/?cid=$($ezClientConfig.ezRmmId)" + '&aid=0013z00002YbbGCAAZ'
    
    # Ensure directory exists
    $installerDir = Split-Path -Path $installer -Parent
    if (!(Test-Path -Path $installerDir)) {
        New-Item -ItemType Directory -Path $installerDir -Force | Out-Null
    }
    
    Write-Host -ForegroundColor Gray "Z> Downloading ezRmmInstaller.msi from $ezRmmUrl"
    Invoke-WebRequest -Uri $ezRmmUrl -OutFile $installer -UseBasicParsing
    
    # Verify download succeeded
    if (!(Test-Path -Path $installer)) {
        throw "Failed to download installer"
    }
    
    $currentUser = [System.Security.Principal.WindowsIdentity]::GetCurrent().Name
    Write-Host -ForegroundColor Gray "Z> Running as: $currentUser"
    
    if ($currentUser -eq 'NT AUTHORITY\SYSTEM') {
        # Already running as SYSTEM, install directly
        Write-Host -ForegroundColor Gray "Z> Installing as SYSTEM directly"
        $process = Start-Process -FilePath "msiexec.exe" -ArgumentList "/i `"$installer`" /qn /norestart" -Wait -PassThru
        
        if ($process.ExitCode -ne 0 -and $process.ExitCode -ne 3010) {
            throw "ezRMM installer failed with exit code $($process.ExitCode)"
        }
        Write-Host -ForegroundColor Green "Z> ezRMM installed successfully (Exit code: $($process.ExitCode))"
    } else {
        # Not running as SYSTEM, create scheduled task
        Write-Host -ForegroundColor Gray "Z> Creating scheduled task to run as SYSTEM"
        $taskName = "Install_ezRmm_$([guid]::NewGuid())"
        $action   = New-ScheduledTaskAction -Execute "msiexec.exe" -Argument "/i `"$installer`" /qn /norestart"
        $trigger  = New-ScheduledTaskTrigger -Once -At (Get-Date).AddSeconds(10)
        $settings = New-ScheduledTaskSettingsSet -AllowStartIfOnBatteries -DontStopIfGoingOnBatteries -StartWhenAvailable
        
        Register-ScheduledTask -TaskName $taskName -Action $action -Trigger $trigger -User "SYSTEM" -RunLevel Highest -Settings $settings | Out-Null
        
        Write-Host -ForegroundColor Gray "Z> Starting scheduled task"
        Start-ScheduledTask -TaskName $taskName
        
        # Wait for task to complete
        $timeout = 300 # 5 minutes
        $elapsed = 0
        do {
            Start-Sleep -Seconds 5
            $elapsed += 5
            $task = Get-ScheduledTask -TaskName $taskName -ErrorAction SilentlyContinue
            $info = Get-ScheduledTaskInfo -TaskName $taskName -ErrorAction SilentlyContinue
            
            if ($elapsed -gt $timeout) {
                Unregister-ScheduledTask -TaskName $taskName -Confirm:$false -ErrorAction SilentlyContinue
                throw "Installation timed out after $timeout seconds"
            }
        } while ($task.State -eq 'Running' -or $info.LastRunTime -eq [datetime]::MinValue)
        
        # Clean up task
        Unregister-ScheduledTask -TaskName $taskName -Confirm:$false -ErrorAction SilentlyContinue
        
        # Check result (0 = success, 3010 = success but reboot required)
        if ($info.LastTaskResult -ne 0 -and $info.LastTaskResult -ne 3010) {
            throw "ezRMM installer task failed with exit code $($info.LastTaskResult)"
        }
        Write-Host -ForegroundColor Green "Z> ezRMM installed successfully via scheduled task (Exit code: $($info.LastTaskResult))"
    }
    
    # Cleanup installer file
    if (Test-Path -Path $installer) {
        Remove-Item -Path $installer -Force -ErrorAction SilentlyContinue
    }
}
catch {
    Write-Error "Z> ezRmm installation failed: $($_.Exception.Message)"
    # Cleanup on error
    if (Test-Path -Path $installer) {
        Remove-Item -Path $installer -Force -ErrorAction SilentlyContinue
    }
    throw
}
#EndRegion Install ezRmm and ezRS





$Time = Get-date -Format t
$Splat = @{
    Text = 'Z> Default apps script finished' , "Installed Choco, ezRMM, Office 365, ez Support Companion Finished $Time"
    Applogo = 'https://iili.io/H8B8JtI.png'
    Sound = 'IM'
}
New-BurntToastNotification @splat 

Write-host ""
Write-Host -ForegroundColor Cyan "========================================================================================="
write-host -ForegroundColor Cyan "Z> Installing client Finished." 
write-host -ForegroundColor Cyan "Z> You can deliver the computer to the client now."
Write-Host -ForegroundColor Cyan "Z> All script tasks have been completed, please check for additional powershell boxes."

Stop-Transcript
$finishAction = Read-Host -Prompt "Z> What would you like to do next?`n[1] Shut down the computer`n[2] Just close the script`n[3] Restart the computer`nEnter your choice (1-3)"

switch ($finishAction) {
    "1" {
        Write-Host -ForegroundColor Cyan "Z> Shutting down the computer in 10 seconds..."
        Start-Sleep -Seconds 5
        Stop-Computer -Force
    }
    "2" {
        Write-Host -ForegroundColor Cyan "Z> Exiting the script. Goodbye!"
        Exit
    }
    "3" {
        Write-Host -ForegroundColor Cyan "Z> Restarting the computer in 10 seconds..."
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