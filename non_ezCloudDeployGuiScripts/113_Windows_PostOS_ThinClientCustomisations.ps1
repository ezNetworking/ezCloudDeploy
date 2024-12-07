Write-Host -ForegroundColor Cyan "========================================================================================="
Write-Host -ForegroundColor Cyan "             Thinclient Deployment Client Customisations - Post OS Deployment"
Write-Host -ForegroundColor Cyan "========================================================================================="
Write-Host -ForegroundColor Cyan ""
Start-Transcript -Path "C:\ezNetworking\Automation\Logs\ezCloudDeploy_PostOS_ThinClientCustomisations.log"
Set-ExecutionPolicy -ExecutionPolicy Bypass -Scope Process -Force
Set-PSRepository -Name PSGallery -InstallationPolicy Trusted
Install-Module Transferetto
Import-Module Transferetto

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
$rdpFilePath = 'C:\ezNetworking\Automation\ezCloudDeploy\CustomerRDS.rdp'
$desktopFolderPath = [Environment]::GetFolderPath('CommonDesktopDirectory')
$rdpShortcutFilePath = Join-Path -Path $desktopFolderPath -ChildPath 'RDS Cloud.lnk'
$ezRsUrl = 'https://get.teamviewer.com/ezNetworkingHost'
$SupportFolderScriptPath = "c:\ezNetworking\DownloadSupportFolder.ps1"
$SupportFolderFtpFolder = '/drivehqshare/ezadminftp/public/SupportFolderClients'
$LgpoFtpFolder = "/drivehqshare/ezadminftp/public/LGPO"
$lgpoLocalFolder = "C:\ezNetworking\Automation\ezCloudDeploy\LGPO"

# Define FTP Server connection details
$ftpServer = "ftp.driveHQ.com"
$ftpUsername = "ezPublic"
$ftpPublicPassword = "MakesYourNetWork"

# Function to handle files and directories
function Process-FTPItems {
    param(
        [FluentFTP.FtpClient]$Client,
        [string]$LocalPath,
        [string]$RemotePath
    )

    # Get the list of remote items (files and directories)
    $remoteItems = Get-FTPList -Client $Client -Path $RemotePath
    
    Write-Host "Z> Found $(($remoteItems).Count) items in the remote path: $RemotePath"

    foreach ($remoteItem in $remoteItems) {
        $localFilePath = Join-Path -Path $LocalPath -ChildPath $remoteItem.Name

        if ($remoteItem.Type -eq "File") {
            # Download the remote file and overwrite the local file if it exists
            Receive-FTPFile -Client $Client -LocalPath $localFilePath -RemotePath $remoteItem.FullName -LocalExists Overwrite
        } elseif ($remoteItem.Type -eq "Directory") {
            # If the item is a directory, recursively call this function
            
            Write-Host "Z> Found directory: $remoteItem.FullName"

            if (!(Test-Path $localFilePath)) {
                
                Write-Host "Z> Local directory doesn't exist. Creating: $localFilePath"
                New-Item -ItemType Directory -Path $localFilePath | Out-Null
            }
            
            Write-Host "Z> Navigating into directory: $localFilePath"
            Process-FTPItems -Client $Client -LocalPath $localFilePath -RemotePath $remoteItem.FullName
        }
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


# Install ezRmm and ezRS
#region Install ezRmm and ezRS
Write-Host -ForegroundColor Gray "========================================================================================="
write-host -ForegroundColor White "Z> ezRMM - Downloading and installing it for customer $($ezClientConfig.ezRmmId)"


try {
    $ezRmmUrl = "http://support.ez.be/GetAgent/Msi/?customerId=$($ezClientConfig.ezRmmId)" + '&integratorLogin=jurgen.verhelst%40ez.be'
    write-host -ForegroundColor Gray "Z> Downloading ezRmmInstaller.msi from $ezRmmUrl"
    Invoke-WebRequest -Uri $ezRmmUrl -OutFile "C:\ezNetworking\ezRMM\ezRmmInstaller.msi"
    write-host -ForegroundColor Gray "Z> Installing ezRmm."

    Start-Process -FilePath "C:\ezNetworking\ezRMM\ezRmmInstaller.msi" -ArgumentList "/quiet" -Wait
    
}
catch {
    Write-Error "Z> ezRmm is already installed or had an error $($_.Exception.Message)"
}


Write-Host -ForegroundColor Gray "========================================================================================="
write-host -ForegroundColor Gray "Z> ezRS - Downloading and installing it"
try {
$ConfigId = 'q6epc32'
$Version = 'v15'
[System.Net.ServicePointManager]::SecurityProtocol = 'Tls12'
$UrlDownload = "https://customdesignservice.teamviewer.com/download/windows/$Version/$ConfigId/TeamViewer_Host_Setup.exe"
$FileDownload = "C:\ezNetworking\ezRS\ezRsInstaller.exe"
( New-Object System.Net.WebClient ).DownloadFile( $UrlDownload , $FileDownload )
}
catch {
    Write-Error "Z> ezRS is already installed or had an error $($_.Exception.Message)"
}
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

    Write-Host -ForegroundColor Gray "Z> Running the DownloadSupportFolder script"
    . $SupportFolderScriptPath -remoteDirectory $SupportFolderFtpFolder

    # Create a new scheduled task for the same script
    Write-Host -ForegroundColor Gray ""
    Write-Host -ForegroundColor Gray "Z> Scheduling the DownloadSupportFolder script to run every Sunday at 14:00"
    $action = New-ScheduledTaskAction -Execute "powershell.exe" -Argument "-File $SupportFolderScriptPath -remoteDirectory '$SupportFolderFtpFolder'"
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
Write-Host -ForegroundColor White "Z> Desktop Icons cleanup and creation. Start RDP at login for user 'User'"
Write-Host -ForegroundColor White "========================================================================================="
#Region Desktop Icons cleanup and creation. Start RDP at login for user 'User'
# Get the RDS URI from the JSON file
Write-Host -ForegroundColor Gray "Z> Loading RDS URI from ClientConfig JSON."
$rdsUri = $ezClientConfig.custRdsUri
$netBiosName = $ezClientConfig.custNetBiosName

# Delete all links in the default public user's desktop
Write-Host -ForegroundColor Gray "Z> Delete all links in the default public user's desktop."
Get-ChildItem -Path $desktopFolderPath -Filter '*.*' -File | Remove-Item -Force

# Create the RDP file with the RDS URI
Write-Host -ForegroundColor Gray "Z> Create the RDP file with the RDS URI."
$rdpContent = @"
full address:s:$rdsUri
prompt for credentials:i:1
username:s:$netBiosName\ 
"@
$rdpContent | Out-File -FilePath $rdpFilePath -Encoding ASCII

# Create a shortcut to the RDP file on the public desktop
Write-Host -ForegroundColor Gray "Z> Create a shortcut to the RDP file on the public desktop."
$shell = New-Object -ComObject WScript.Shell
$shortcut = $shell.CreateShortcut($rdpShortcutFilePath)
$shortcut.TargetPath = $rdpFilePath
$shortcut.Save()

# Create a Shutdown shortcut on the public desktop
$WshShell = New-Object -comObject WScript.Shell
$Shortcut = $WshShell.CreateShortcut("$env:PUBLIC\Desktop\Shutdown.lnk")
$Shortcut.TargetPath = "C:\Windows\System32\shutdown.exe"
$Shortcut.Arguments = "/s /t 0"
$Shortcut.IconLocation = "C:\Windows\System32\shell32.dll,27"
$Shortcut.Save()

# Prevent creation of Microsoft Edge desktop shortcut
Write-Host -ForegroundColor Gray "Z> Preventing creation of Microsoft Edge desktop shortcut."
$RegPath = "HKLM:\SOFTWARE\Policies\Microsoft\EdgeUpdate"
if (!(Test-Path $RegPath)) {
    New-Item -Path $RegPath -Force | Out-Null
}
New-ItemProperty -Path $RegPath -Name "CreateDesktopShortcutDefault" -Value 0 -PropertyType "DWORD" -Force | Out-Null

# Disable Windows Search
Write-Host -ForegroundColor Gray "Z> Disabling Windows Search."
$RegPath = "HKLM:\SOFTWARE\Policies\Microsoft\Windows\Windows Search"
if (!(Test-Path $RegPath)) {
    New-Item -Path $RegPath -Force | Out-Null
}
New-ItemProperty -Path $RegPath -Name "DisableSearch" -Value 1 -PropertyType "DWORD" -Force | Out-Null
#endregion

Write-Host -ForegroundColor White ""
Write-Host -ForegroundColor White "========================================================================================="
Write-Host -ForegroundColor White "Z> Importing Local Group Policies for non admins like the thinclient user."
Write-Host -ForegroundColor White "========================================================================================="
#region Import Local Group Policies for non admins like the thinclient user

# Download LGPO files from ftp
Write-Host -ForegroundColor White "Z> Downloading LGPO files from ftp."
Set-FTPTracing -disable


try {
    # Establish a connection to the FTP server
    
    Write-Host "Z> Connecting to FTP Server at $ftpServer..."
    $ftpConnection = Connect-FTP -Server $ftpServer -Username $ftpUsername -Password $ftpPublicPassword
    Request-FTPConfiguration 

} catch {
    
    Write-Host "Z> Failed to connect to FTP server at $ftpServer. Exiting script..."
    Write-Host "Z> Error details: $_"
    
}

# Process files and directories

Write-Host "Z> Starting to process files and directories..."
Process-FTPItems -Client $ftpConnection -LocalPath "C:\ezNetworking" -RemotePath $LgpoFtpFolder

# Close the FTP connection

Write-Host -ForegroundColor Gray "Z> Disconnecting from FTP server..."
Disconnect-FTP -Client $ftpConnection

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
 # {$command = "net user 'User' 'user' /add /fullname:'ThinClient User' /comment:'User for Autologin'"
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
New-LocalUser -Name 'User' -Password $password -FullName 'ThinClient User' -Description 'User for Autologin' -PasswordNeverExpires -UserMayNotChangePassword -AccountNeverExpires
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

# Create User Logon Script to start RDP on login of User
Write-Host -ForegroundColor Gray "Z> Creating job for User to open the RDP via logon script."
$logonScriptContent = @"
& 'mstsc.exe' 'C:\ezNetworking\Automation\ezCloudDeploy\CustomerRDS.rdp'
"@
$logonScriptPath = "C:\ezNetworking\Automation\ezCloudDeploy\UserLogonScript.ps1"
$logonScriptContent | Out-File -FilePath $logonScriptPath -Encoding ASCII
$Action = New-ScheduledTaskAction -Execute 'powershell.exe' -Argument "-File `"$logonScriptPath`""
$Trigger = New-ScheduledTaskTrigger -AtLogOn -User "User"
Register-ScheduledTask -Action $Action -Trigger $Trigger -TaskName "UserLogonScript" -Description "Runs a script at User logon."

Write-Host -ForegroundColor Cyan "========================================================================================="
write-host -ForegroundColor Cyan "Z> Configuring ThinClient Finished." 
write-host -ForegroundColor Cyan "Z> The Thinclient User has password 'user' and is set to autologin."
write-host -ForegroundColor Cyan "Z> You can deliver the computer to the client now after testing auto user login."
Read-Host -Prompt "Z> Press any key to Reboot the ThinClient."
restart-computer -force
Write-Host -ForegroundColor Cyan "========================================================================================="

Stop-Transcript
Write-Warning "  If you do see errors, please check the log file at: "
write-warning "  C:\ezNetworking\Automation\Logs\ezCloudDeploy_PostOS_ThinClientCustomisations.log"
