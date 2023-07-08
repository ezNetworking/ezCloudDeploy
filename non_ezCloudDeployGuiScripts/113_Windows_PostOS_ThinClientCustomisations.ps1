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
Set-ItemProperty $RegPath "DefaultUserName" -Value $userName -type String

Write-Host -ForegroundColor White "========================================================================================="
Write-Host -ForegroundColor White "Z> Local Group Policy 'ThinClientUsers' creation and config."
Write-Host -ForegroundColor White "========================================================================================="

# Create and import the local group policy
# The non-administrators Local GP is always saved in C:\Windows\System32\GroupPolicyUsers\S-1-5-32-545\User\Registry.pol 
# when updating is needed you can import the Registry.pol file on a clean PC as below, make changes and copy it back to FTP
# LGPO download from ftp
# Download Registry.pol from ftp
# Import Registry.pol to non-administrator group
lgpo /un $LGPOFilePath\Registry.pol

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
