Write-Host -ForegroundColor Cyan "========================================================================================="
Write-Host -ForegroundColor Cyan "             Thinclient Deployment Client Customisations - Post OS Deployment"
Write-Host -ForegroundColor Cyan "========================================================================================="
Write-Host -ForegroundColor Cyan ""

Write-Host -ForegroundColor Gray "========================================================================================="
Start-Transcript -Path "C:\ezNetworking\Automation\Logs\ezCloudDeploy_PostOS_ThinClientCustomisations.log"
Write-Host -ForegroundColor Gray "========================================================================================="
Set-ExecutionPolicy -ExecutionPolicy Bypass -Scope Process -Force
Set-PSRepository -Name PSGallery -InstallationPolicy Trusted
Install-Module burnttoast
Import-Module burnttoast

# Define the Variables
$jsonFilePath = 'C:\ezNetworking\Automation\ezCloudDeploy\ezClientConfig.json'
$rdpFilePath = 'C:\ezNetworking\Automation\ezCloudDeploy\CustomerRDS.rdp'
$desktopFolderPath = [Environment]::GetFolderPath('CommonDesktopDirectory')
$rdpShortcutFilePath = Join-Path -Path $desktopFolderPath -ChildPath 'RDS Cloud.lnk'

Read-Host -Prompt "Press Enter to continue"
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

$Time = Get-date -Format t
$Splat = @{
    Text = 'Zed: ThinClient Setup' , "Configuring... Started $Time"
    Applogo = 'https://iili.io/H8B8JtI.png'
    Sound = 'IM'
}
New-BurntToastNotification @splat 

# Load the JSON file
$ezClientConfig = Get-Content -Path $jsonFilePath | ConvertFrom-Json

# Disable sleep and disk sleep
powercfg.exe -change -standby-timeout-ac 0
powercfg.exe -change -disk-timeout-ac 0

# Set active power plan to never sleep and never put the disk in sleep mode
$activePlan = (Get-WmiObject -Namespace root\cimv2\power -Class Win32_PowerPlan | Where-Object {$_.IsActive}).ElementName
powercfg.exe -setacvalueindex $activePlan 238C9FA8-0AAD-41ED-83F4-97BE242C8F20 0012ee47-9041-4b5d-9b77-535fba8b1442 000
powercfg.exe -setacvalueindex $activePlan 238C9FA8-0AAD-41ED-83F4-97BE242C8F20 12bbebe6-58d6-4636-95bb-3217ef867c1a 000


# Install ezRmm and ezRS
write-host -ForegroundColor White "Z> ezRMM - Downloading and installing it for customer $($ezClientConfig.ezRmmId)"


try {
    $ezRmmUrl = "http://support.ez.be/GetAgent/Msi/?customerId=$($ezClientConfig.ezRmmId)" + '&integratorLogin=jurgen.verhelst%40ez.be'
    write-host -ForegroundColor Gray "Z> Downloading ezRmmInstaller.msi from $ezRmmUrl"
    Invoke-WebRequest -Uri $ezRmmUrl -OutFile "C:\ezNetworking\Automation\ezCloudDeploy\ezRmmInstaller.msi"
    # Send the toast Alarm
    $Btn = New-BTButton -Content 'Got it!' -arguments 'ok'
    $Splat = @{
        Text = 'Zed: ezRMM needs your Attention' , "Please press OK."
        Applogo = 'https://iili.io/H8B8JtI.png'
        Sound = 'Alarm10'
        Button = $Btn
        HeroImage = 'https://iili.io/HU7A5bV.jpg'
}
New-BurntToastNotification @splat

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

# Download the DownloadSupportFolder script, run and schedule it
Write-Host -ForegroundColor Gray "========================================================================================="
Write-Host -ForegroundColor Gray "Z> Downloading the DownloadSupportFolder Script, runing and scheduling it"
try {
    $DownloadSupportFolderResponse = Invoke-WebRequest -Uri "https://raw.githubusercontent.com/ezNetworking/ezCloudDeploy/master/non_ezCloudDeployGuiScripts/113_Windows_PostOS_ThinClientCustomisations.ps1" -UseBasicParsing 
    $DownloadSupportFolderScript = $DownloadSupportFolderResponse.content
    Write-Host -ForegroundColor Gray "Z> Saving the Onboard script to c:\ezNetworking\DownloadSupportFolder.ps1"
    $DownloadSupportFolderScriptPath = "c:\ezNetworking\DownloadSupportFolder.ps1"
    $DownloadSupportFolderScript | Out-File -FilePath $DownloadSupportFolderScriptPath -Encoding UTF8

    Write-Host -ForegroundColor Gray "Z> Running the DownloadSupportFolder script"
    . $DownloadSupportFolderScriptPath

    Write-Host -ForegroundColor Gray "Z> Scheduling the DownloadSupportFolder script to run every Sunday at 14:00"

    # Create a new scheduled task
    $action = New-ScheduledTaskAction -Execute "powershell.exe" -Argument "-File $DownloadSupportFolderScriptPath"
    $trigger = New-ScheduledTaskTrigger -Weekly -DaysOfWeek Sunday -At 14:00
    $settings = New-ScheduledTaskSettingsSet
    $principal = New-ScheduledTaskPrincipal -UserId "SYSTEM"
    Register-ScheduledTask -TaskName "ezDownloadSupportFolder" -Action $action -Trigger $trigger -Settings $settings -Principal $principal

}
catch {
    Write-Error " Z> I was unable to download the DownloadSupportFolder script."
}



Write-Host -ForegroundColor White "========================================================================================="
Write-Host -ForegroundColor White "Z> RDS shortcut creation."
Write-Host -ForegroundColor White "========================================================================================="
# Get the RDS URI from the JSON file
Write-Host -ForegroundColor Gray "Z> Loading ClientConfig JSON."
$rdsUri = $ezClientConfig.custRdsUri

# Delete all links in the default public user's desktop
Write-Host -ForegroundColor Gray "Z> Delete all links in the default public user's desktop."
Get-ChildItem -Path $desktopFolderPath -Filter '*.*' -File | Remove-Item -Force

# Create the RDP file with the RDS URI
Write-Host -ForegroundColor Gray "Z> Create the RDP file with the RDS URI."
$rdpContent = @"
full address:s:$rdsUri
prompt for credentials:i:1
"@
$rdpContent | Out-File -FilePath $rdpFilePath -Encoding ASCII

# Create a shortcut to the RDP file on the public desktop
Write-Host -ForegroundColor Gray "Z> Create a shortcut to the RDP file on the public desktop."
$shell = New-Object -ComObject WScript.Shell
$shortcut = $shell.CreateShortcut($rdpShortcutFilePath)
$shortcut.TargetPath = $rdpFilePath
$shortcut.Save()

Write-Host -ForegroundColor White "========================================================================================="
Write-Host -ForegroundColor White "Z> Importing Local Group Policies for non admins like the thinclient user."
Write-Host -ForegroundColor White "========================================================================================="

# Download LGPO files from ftp
Write-Host -ForegroundColor White "Z> Downloading LGPO files from ftp."
# Import the module
Import-Module Transferetto

# Enable Tracing
Set-FTPTracing -disable

# Define FTP Server connection details
$server = "192.168.13.15"
$username = "ezPublic"
$password = "MakesYourNetWork"

# Define local and remote directories
$remoteDirectory = "LGPO"
$localDirectory = "C:\ezNetworking\Apps\LGPO"

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

try {
    # Establish a connection to the FTP server
    
    Write-Host "Z> Connecting to FTP Server at $server..."
    $ftpConnection = Connect-FTP -Server $server -Username $username -Password $password
    Request-FTPConfiguration 

} catch {
    
    Write-Host "Z> Failed to connect to FTP server at $server. Exiting script..."
    Write-Host "Z> Error details: $_"
    exit
}

# Process files and directories

Write-Host "Z> Starting to process files and directories..."
Process-FTPItems -Client $ftpConnection -LocalPath $localDirectory -RemotePath $remoteDirectory

# Close the FTP connection

Write-Host "Z> Disconnecting from FTP server..."
Disconnect-FTP -Client $ftpConnection

Write-Host "Z> Process completed."

# The non-administrators Local GP is always saved in C:\Windows\System32\GroupPolicyUsers\S-1-5-32-545\User\Registry.pol 
# when updating is needed you can import the Registry.pol file on a clean PC as below, make changes via MMC/GroupPolEditor and copy it back to FTP
$LGPOFolder = "C:\ezNetworking\Apps\LGPO"

# Import Registry.pol to non-administrator group
write-host -ForegroundColor Gray "Z> Importing Registry.pol to non-administrator group."
$lgpoExe = Join-Path -Path $LGPOFolder -ChildPath "lgpo.exe"
$unCommand = "/un"
$nonAdminPolicyFile = Join-Path -Path $LGPOFolder -ChildPath "NonAdministratorPolicy\LgpoNonAdmins.pol"

# Run the command
Start-Process -FilePath $lgpoExe -ArgumentList $unCommand, $nonAdminPolicyFile -Wait


Write-Host -ForegroundColor White "========================================================================================="
Write-Host -ForegroundColor White "Z> User and group creation."
Write-Host -ForegroundColor White "========================================================================================="

# Create non-admin user
Write-Host -ForegroundColor Gray "Z> Creating NonAdminUser User."
$command = "net user 'User'  /add /passwordreq:no /fullname:'ThinClient User' /comment:'User for Autologin'"
Invoke-Expression -Command $command
# Set password to never expire
Write-Host -ForegroundColor Gray "Z> Set password to never expire."
$command = "wmic useraccount where name='User' set passwordexpires=false"
Invoke-Expression -Command $command

# Setup Autologin
Write-Host -ForegroundColor Gray "Z> Setting up Autologin."
$RegPath = "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Winlogon"
Set-ItemProperty $RegPath "AutoAdminLogon" -Value "1" -type String 
Set-ItemProperty $RegPath "DefaultUserName" -Value "User" -type String

write-host -ForegroundColor Gray "Z> Send a completion toast Alarm"
$Btn = New-BTButton -Content 'Got it!' -arguments 'ok'
$Splat = @{
    Text = 'Zed: Configuring ThinClient Finished' , "Please press OK."
    Applogo = 'https://iili.io/H8B8JtI.png'
    Sound = 'Alarm10'
    Button = $Btn
    HeroImage = 'https://iili.io/HU7A5bV.jpg'
}

Write-Host -ForegroundColor Cyan "========================================================================================="
write-host -ForegroundColor Cyan "Z> Configuring ThinClient Finished." 
write-host -ForegroundColor Cyan "Z> Check if you can login as User and if hardening is applied."
write-host -ForegroundColor Cyan "Z> You can deliver the computer to the client now."
Read-Host -Prompt "Z> Press any key to exit"
Write-Host -ForegroundColor Cyan "========================================================================================="

Stop-Transcript
Write-Warning "  If you do see errors, please check the log file at: "
write-warning "  C:\ezNetworking\Automation\Logs\ezCloudDeploy_PostOS_ThinClientCustomisations.log"
