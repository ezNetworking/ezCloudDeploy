Write-Host -ForegroundColor Cyan "========================================================================================="
Write-Host -ForegroundColor Cyan "             Thinclient Deployment Client Customisations - Post OS Deployment"
Write-Host -ForegroundColor Cyan "========================================================================================="
Write-Host -ForegroundColor Cyan ""
Start-Transcript -Path "C:\ezNetworking\Automation\Logs\ezCloudDeploy_PostOS_ThinClientCustomisations.log"
Set-ExecutionPolicy -ExecutionPolicy Bypass -Scope Process -Force
Set-PSRepository -Name PSGallery -InstallationPolicy Trusted
Install-Module -Name 'Posh-SSH' -Scope AllUsers -Force
Import-Module Posh-SSH

# Checking if the folders exist, if not create them
$foldersToCheck = @(
    "C:\ezNetworking\Automation\Logs",
    "C:\ezNetworking\Automation\Scripts",
    "C:\ezNetworking\Apps",
    "C:\ezNetworking\Automation\ezCloudDeploy",
    "C:\ezNetworking\ezRS",
    "C:\ezNetworking\ezRMM"
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

# Define the Folder, Files and URL Variables
$jsonFilePath = 'C:\ezNetworking\Automation\ezCloudDeploy\ezClientConfig.json'
$SupportFolderScriptPath = "c:\ezNetworking\DownloadSupportFolder.ps1"
$SupportFolderSftpFolder = '/SupportFolderClients'
$LgpoSftpFolder = '/LGPO'
$lgpoLocalFolder = "C:\ezNetworking\Automation\ezCloudDeploy\LGPO"

# Run the Posh-SSH download helper in a separate process because it uses exit codes.
function Invoke-SFTPFolderDownload {
    param(
        [Parameter(Mandatory = $true)]
        [string]$RemoteDirectory
    )

    Write-Host -ForegroundColor Gray "Z> Downloading SFTP folder $RemoteDirectory"
    $arguments = "-NoProfile -ExecutionPolicy Bypass -File `"$SupportFolderScriptPath`" -remoteDirectory `"$RemoteDirectory`""
    $downloadProcess = Start-Process -FilePath 'powershell.exe' -ArgumentList $arguments -Wait -PassThru
    if ($downloadProcess.ExitCode -ne 0) {
        throw "SFTP download of $RemoteDirectory failed with exit code $($downloadProcess.ExitCode)."
    }
}

# Load the JSON file
Write-Host -ForegroundColor Gray "========================================================================================="
Write-Host -ForegroundColor Gray "Z> Loading the JSON file"
$ezClientConfig = Get-Content -Path $jsonFilePath | ConvertFrom-Json

# Disable sleep and disk sleep
Write-Host -ForegroundColor Gray "========================================================================================="
Write-Host -ForegroundColor Gray "Z> Disabling sleep and disk sleep"
powercfg.exe -change -standby-timeout-ac 0
powercfg.exe -change -disk-timeout-ac 0
powercfg.exe -change -monitor-timeout-ac 0


# Install ezRmm silently as SYSTEM
#region Install ezRmm
Write-Host -ForegroundColor Gray "========================================================================================="
write-host -ForegroundColor White "Z> ezRMM - Downloading and installing it for customer $($ezClientConfig.ezRmmId)"

$taskName = $null
try {
    $installer = "C:\ezNetworking\ezRMM\ezRmmInstaller.msi"
    $ezRmmUrl = "http://support.ez.be/api/utils/agent-install/windows/?cid=$($ezClientConfig.ezRmmId)" + '&aeid=34471983397d46c28df96262b7ad29a2'
    write-host -ForegroundColor Gray "Z> Downloading ezRmmInstaller.msi from $ezRmmUrl"
    Invoke-WebRequest -Uri $ezRmmUrl -OutFile $installer -UseBasicParsing -ErrorAction Stop

    if (!(Test-Path -Path $installer -PathType Leaf)) {
        throw "Failed to download the ezRMM installer."
    }

    $currentUser = [System.Security.Principal.WindowsIdentity]::GetCurrent().Name
    Write-Host -ForegroundColor Gray "Z> Running as $currentUser"

    if ($currentUser -eq 'NT AUTHORITY\SYSTEM') {
        Write-Host -ForegroundColor Gray "Z> Installing ezRMM silently as SYSTEM."
        $installProcess = Start-Process -FilePath 'msiexec.exe' -ArgumentList "/i `"$installer`" /qn /norestart" -Wait -PassThru
        $installExitCode = $installProcess.ExitCode
    } else {
        Write-Host -ForegroundColor Gray "Z> Creating a temporary SYSTEM task for the silent ezRMM installation."
        $taskName = "Install_ezRmm_$([guid]::NewGuid())"
        $action = New-ScheduledTaskAction -Execute 'msiexec.exe' -Argument "/i `"$installer`" /qn /norestart"
        $trigger = New-ScheduledTaskTrigger -Once -At (Get-Date).AddSeconds(5)
        $settings = New-ScheduledTaskSettingsSet -AllowStartIfOnBatteries -DontStopIfGoingOnBatteries -StartWhenAvailable
        Register-ScheduledTask -TaskName $taskName -Action $action -Trigger $trigger -User 'SYSTEM' -RunLevel Highest -Settings $settings | Out-Null
        Start-ScheduledTask -TaskName $taskName

        $timeout = 300
        $elapsed = 0
        do {
            Start-Sleep -Seconds 5
            $elapsed += 5
            $task = Get-ScheduledTask -TaskName $taskName -ErrorAction Stop
            $taskInfo = Get-ScheduledTaskInfo -TaskName $taskName -ErrorAction Stop

            if ($elapsed -ge $timeout) {
                throw "ezRMM installation timed out after $timeout seconds."
            }
        } while ($task.State -eq 'Running' -or $taskInfo.LastRunTime -eq [datetime]::MinValue)

        $installExitCode = $taskInfo.LastTaskResult
        Unregister-ScheduledTask -TaskName $taskName -Confirm:$false -ErrorAction SilentlyContinue
    }

    if ($installExitCode -ne 0 -and $installExitCode -ne 3010) {
        throw "ezRMM installer failed with exit code $installExitCode."
    }

    Write-Host -ForegroundColor Green "Z> ezRMM installed successfully (exit code $installExitCode)."
}
catch {
    if ($taskName) {
        Unregister-ScheduledTask -TaskName $taskName -Confirm:$false -ErrorAction SilentlyContinue
    }
    Write-Error "Z> ezRMM installation failed: $($_.Exception.Message)"
    throw
}
finally {
    if ($installer -and (Test-Path -Path $installer)) {
        Remove-Item -Path $installer -Force -ErrorAction SilentlyContinue
    }
}


# Write-Host -ForegroundColor Gray "========================================================================================="
# write-host -ForegroundColor Gray "Z> ezRS - Downloading and installing it"
# try {
# $ConfigId = 'q6epc32'
# $Version = 'v15'
# [System.Net.ServicePointManager]::SecurityProtocol = 'Tls12'
# $UrlDownload = "https://customdesignservice.teamviewer.com/download/windows/$Version/$ConfigId/TeamViewer_Host_Setup.exe"
# $FileDownload = "C:\ezNetworking\ezRS\ezRsInstaller.exe"
# ( New-Object System.Net.WebClient ).DownloadFile( $UrlDownload , $FileDownload )
# }
# catch {
#     Write-Error "Z> ezRS is already installed or had an error $($_.Exception.Message)"
# }
#endregion

# Download the DownloadSupportFolder script, run and schedule it
#region Download the DownloadSupportFolder script, run and schedule it
Write-Host -ForegroundColor Gray "========================================================================================="
Write-Host -ForegroundColor Gray "Z> Downloading the DownloadSupportFolder Script, running and scheduling it"
try {
    $DownloadSupportFolderResponse = Invoke-WebRequest -Uri "https://raw.githubusercontent.com/ezNetworking/ezCloudDeploy/master/non_ezCloudDeployGuiScripts/140_Windows_PostOS_DownloadSupportFolders.ps1" -UseBasicParsing 
    $DownloadSupportFolderScript = $DownloadSupportFolderResponse.content
    Write-Host -ForegroundColor Gray "Z> Saving the Onboard script to $SupportFolderScriptPath"
    $DownloadSupportFolderScript | Out-File -FilePath $SupportFolderScriptPath -Encoding UTF8

    Write-Host -ForegroundColor Gray "Z> Running the DownloadSupportFolder script in a separate PowerShell process"
    Invoke-SFTPFolderDownload -RemoteDirectory $SupportFolderSftpFolder

    # Create a new scheduled task for the same script
    Write-Host -ForegroundColor Gray ""
    Write-Host -ForegroundColor Gray "Z> Scheduling the DownloadSupportFolder script to run every Sunday at 14:00"
    $action = New-ScheduledTaskAction -Execute "powershell.exe" -Argument "-NoProfile -ExecutionPolicy Bypass -File `"$SupportFolderScriptPath`" -remoteDirectory `"$SupportFolderSftpFolder`""
    $trigger = New-ScheduledTaskTrigger -Weekly -DaysOfWeek Sunday -At 14:00
    $settings = New-ScheduledTaskSettingsSet
    $principal = New-ScheduledTaskPrincipal -UserId "SYSTEM"
    Register-ScheduledTask -TaskName "ezDownloadSupportFolder" -Action $action -Trigger $trigger -Settings $settings -Principal $principal

}
catch {
    Write-Error " Z> I was unable to download the DownloadSupportFolder script."
}

# Set BGinfo to run on startup
Write-Host -ForegroundColor Gray "Z> Configuring BGinfo to run on startup"

<#
 # {$registryPath = "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Run"
$propertyName = "BGinfo"
$propertyValue = "C:\\ezNetworking\\BGinfo\\PresetAndBgInfo.cmd"
New-ItemProperty -Path $registryPath -Name $propertyName -Value $propertyValue -PropertyType String -Force:Enter a comment or description}
#>

#Method 2
$registryPath = "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Run"
$propertyName = "BGinfo"
$propertyValue = "powershell.exe -ExecutionPolicy Bypass -File C:\\ezNetworking\\BGinfo\\PresetAndBgInfo.ps1"
New-ItemProperty -Path $registryPath -Name $propertyName -Value $propertyValue -PropertyType String -Force
#endregion

Write-Host -ForegroundColor White ""
Write-Host -ForegroundColor White "========================================================================================="
Write-Host -ForegroundColor White "Z> Importing Local Group Policies for non admins like the DigiSign user."
Write-Host -ForegroundColor White "========================================================================================="
#region Import Local Group Policies for non admins like the DigiSign user

# Download LGPO files through the same Posh-SSH helper
Write-Host -ForegroundColor White "Z> Downloading LGPO files through SFTP."
try {
    Invoke-SFTPFolderDownload -RemoteDirectory $LgpoSftpFolder
}
catch {
    Write-Error "Z> Failed to download LGPO files through SFTP: $($_.Exception.Message)"
    throw
}

# Import Registry.pol to non-administrator group
# The non-administrators Local GP is always saved in C:\Windows\System32\GroupPolicyUsers\S-1-5-32-545\User\Registry.pol 
# when updating is needed you can import the Registry.pol file on a clean PC as below, make changes via MMC/GroupPolEditor, non-Admins and copy it using lgpo /b c:\export and send it back to FTP
# More info: https://woshub.com/backupimport-local-group-policy-settings/ and https://woshub.com/apply-local-group-policy-non-admins-mlgpo/

write-host -ForegroundColor White "Z> Importing Registry.pol to non-administrator group."
$lgpoExe = Join-Path -Path $lgpoLocalFolder -ChildPath "lgpo.exe"
$unCommand = "/un"
$nonAdminPolicyFile = Join-Path -Path $lgpoLocalFolder -ChildPath "NonAdministratorPolicy\LgpoNonAdmins.pol"

# Run the command
Start-Process -FilePath $lgpoExe -ArgumentList $unCommand, $nonAdminPolicyFile -Wait

Write-Host -ForegroundColor White ""
Write-Host -ForegroundColor White "========================================================================================="
Write-Host -ForegroundColor White "Z> User and group creation."
Write-Host -ForegroundColor White "========================================================================================="

# Create non-admin user
Write-Host -ForegroundColor White "Z> Creating NonAdminUser 'User' with password 'user'."

<#
 # {$command = "net user 'User' 'user' /add /fullname:'DigiSign User' /comment:'User for Autologin'"
Invoke-Expression -Command $command
# Set password to never expire
Write-Host -ForegroundColor Gray "Z> Set password to never expire."
$command = "net user 'User' /expires:never"
Invoke-Expression -Command $command
:Enter a comment or description}
#>

# Create a secure password
$password = ConvertTo-SecureString 'user' -AsPlainText -Force
# Create the user using New-LocalUser
New-LocalUser -Name 'User' -Password $password -FullName 'DigiSign User' -Description 'User for Autologin' -PasswordNeverExpires -UserMayNotChangePassword -AccountNeverExpires
# Add the user to the "Users" group to make sure it's a non-admin account
Write-Host -ForegroundColor Gray "Z> Adding 'User' to the Users group."
Add-LocalGroupMember -Group 'Users' -Member 'User'
Write-Host -ForegroundColor Green "Z> User 'User' created successfully."


# Setup Autologin
Write-Host -ForegroundColor Gray "Z> Setting up Autologin."
$RegPath = "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Winlogon"
Set-ItemProperty $RegPath "AutoAdminLogon" -Value "1" -type String 
Set-ItemProperty $RegPath "DefaultUserName" -Value "User" -type String 
Set-ItemProperty $RegPath "DefaultPassword" -Value "user" -type String 

# Download and configure the EasySignage Windows player
Write-Host -ForegroundColor White ""
Write-Host -ForegroundColor White "========================================================================================="
Write-Host -ForegroundColor White "Z> Downloading and configuring the EasySignage Windows player."
Write-Host -ForegroundColor White "========================================================================================="

$easySignageUrl = 'https://download.easysignage.com/easysignage-ds-win64-amd64.exe.zip?utm_source=organic'
$easySignageFolder = 'C:\ezNetworking\Apps\EasySignage'
$easySignageZipPath = Join-Path -Path $easySignageFolder -ChildPath 'easysignage-ds-win64-amd64.exe.zip'
$easySignageExePath = Join-Path -Path $easySignageFolder -ChildPath 'easysignage-ds-win64.exe'
$easySignageConfigPath = Join-Path -Path $easySignageFolder -ChildPath 'conf.txt'
$easySignageAutostartPath = Join-Path -Path $easySignageFolder -ChildPath 'autostart.bat'
$easySignageTaskName = 'ezDigitalSignageAutoStart'

try {
    if (!(Test-Path -Path $easySignageFolder)) {
        New-Item -Path $easySignageFolder -ItemType Directory -Force | Out-Null
    }

    Write-Host -ForegroundColor Gray "Z> Downloading EasySignage from $easySignageUrl"
    Invoke-WebRequest -Uri $easySignageUrl -OutFile $easySignageZipPath -UseBasicParsing -ErrorAction Stop

    Write-Host -ForegroundColor Gray "Z> Extracting EasySignage to $easySignageFolder"
    Expand-Archive -Path $easySignageZipPath -DestinationPath $easySignageFolder -Force

    $requiredEasySignageFiles = @(
        $easySignageExePath,
        $easySignageConfigPath,
        $easySignageAutostartPath
    )
    foreach ($requiredFile in $requiredEasySignageFiles) {
        if (!(Test-Path -Path $requiredFile -PathType Leaf)) {
            throw "The EasySignage package is missing the required file: $requiredFile"
        }
    }

    Remove-Item -Path $easySignageZipPath -Force

    Write-Host -ForegroundColor Gray "Z> Registering scheduled task $easySignageTaskName for DigiSign user 'User'."
    $easySignageArguments = "/c `"`"$easySignageAutostartPath`"`""
    $easySignageAction = New-ScheduledTaskAction -Execute 'cmd.exe' -Argument $easySignageArguments -WorkingDirectory $easySignageFolder
    $easySignageTrigger = New-ScheduledTaskTrigger -AtLogOn -User 'User'
    $easySignagePrincipal = New-ScheduledTaskPrincipal -UserId 'User' -LogonType Interactive -RunLevel Limited
    Register-ScheduledTask -TaskName $easySignageTaskName -Action $easySignageAction -Trigger $easySignageTrigger -Principal $easySignagePrincipal -Description 'Starts the EasySignage Windows player when the DigiSign user logs on.' -Force | Out-Null

    Write-Host -ForegroundColor Green "Z> EasySignage is installed and will start automatically when User logs on."
}
catch {
    Write-Error "Z> EasySignage installation failed: $($_.Exception.Message)"
    throw
}

Write-Host -ForegroundColor Cyan "========================================================================================="
write-host -ForegroundColor Cyan "   Configuring DigiSign Finished." 
write-host -ForegroundColor Cyan "   The DigiSign User has password 'user' and is set to autologin."
write-host -ForegroundColor Cyan "   You can deliver the computer to the client now after testing auto user login."
Read-Host -Prompt "Z> Press any key to Reboot the DigiSign Device."
restart-computer -force
Write-Host -ForegroundColor Cyan "========================================================================================="

Stop-Transcript
Write-Warning "  If you do see errors, please check the log file at: "
write-warning "  C:\ezNetworking\Automation\Logs\ezCloudDeploy_PostOS_DigiSignCustomisations.log"
