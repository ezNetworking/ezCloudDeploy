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
$layoutFilePath = "C:\ezNetworking\Automation\ezCloudDeploy\StartMenuTaskbarLayout.xml"
$userName = "User"
$userGroupName = "NonAdminUsers"

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

# Create the Non Admin Users group
Write-Host -ForegroundColor Gray "Z> Creating NonAdminGroup."
New-LocalGroup -Name $userGroupName -Description 'Non-Admin Users'

# Create non-admin user
Write-Host -ForegroundColor Gray "Z> Creating NonAdminUser."
New-LocalUser -Name $userName -FullName "ThinClient User" -Description "User for Autologin" -PasswordNeverExpires -UserMayNotChangePassword -Password ""

# Add the user to the non-admin user group
Write-Host -ForegroundColor Gray "Z> Adding user to NonAdminGroup."
Add-LocalGroupMember -Group $userGroupName -Member $userName

# Setup Autologin
Write-Host -ForegroundColor Gray "Z> Setting up Autologin."
$RegPath = "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Winlogon"
Set-ItemProperty $RegPath "AutoAdminLogon" -Value "1" -type String 
Set-ItemProperty $RegPath "DefaultUserName" -Value $userName -type String

Write-Host -ForegroundColor White "========================================================================================="
Write-Host -ForegroundColor White "Z> Local Group Policy 'ThinClientUsers' creation and config."
Write-Host -ForegroundColor White "========================================================================================="

# Create and import the local group policy
Write-Host -ForegroundColor Gray "Z> Creating Policy."
$policyName = "ThinClientUsers"
$policyPath = "HKLM:\Software\Policies\Microsoft\Windows"
$policyKey = Join-Path -Path $policyPath -ChildPath $policyName
$layoutPolicyPath = Join-Path -Path $policyKey -ChildPath "Explorer"
$layoutPolicyValueName = "LockedStartLayout"
$layoutPolicyValue = "1"

if (-not (Test-Path -Path $policyKey)) {
    New-Item -Path $policyKey | Out-Null
}

New-ItemProperty -Path $layoutPolicyPath -Name $layoutPolicyValueName -Value $layoutPolicyValue -PropertyType DWORD -Force

# Creating the Start Menu and Taskbar layout
Write-Host -ForegroundColor Gray "Z> Creating StartMenuTaskbarLayout.xml."
$layoutScriptBlock = {
    @"
<LayoutModificationTemplate xmlns="http://schemas.microsoft.com/Start/2014/LayoutModification">
  <LayoutOptions StartTileGroupCellWidth="6" />
  <DefaultLayoutOverride>
    <StartLayoutCollection>
      <defaultlayout:StartLayout GroupCellWidth="6" xmlns:defaultlayout="http://schemas.microsoft.com/Start/2014/FullDefaultLayout">
        <start:Group Name="Group1" xmlns:start="http://schemas.microsoft.com/Start/2014/StartLayout">
          <start:DesktopApplicationTile Size="2x2" Column="0" Row="0" DesktopApplicationLinkPath="%APPDATA%\Microsoft\Windows\Start Menu\Programs\Accessories\Notepad.lnk" />
          <start:DesktopApplicationTile Size="2x2" Column="2" Row="0" DesktopApplicationLinkPath="%APPDATA%\Microsoft\Windows\Start Menu\Programs\Accessories\Paint.lnk" />
          <start:DesktopApplicationTile Size="2x2" Column="0" Row="2" DesktopApplicationLinkPath="%APPDATA%\Microsoft\Windows\Start Menu\Programs\System Tools\File Explorer.lnk" />
          <start:DesktopApplicationTile Size="2x2" Column="2" Row="2" DesktopApplicationLinkPath="%APPDATA%\Microsoft\Windows\Start Menu\Programs\System Tools\Command Prompt.lnk" />
        </start:Group>
      </defaultlayout:StartLayout>
    </StartLayoutCollection>
  </DefaultLayoutOverride>
</LayoutModificationTemplate>
"@
}

$layoutScriptBlock | Out-File -FilePath $layoutFilePath -Encoding UTF8 -Force

# Import the Start Menu and Taskbar layout
Write-Host -ForegroundColor Gray "Z> Importing StartMenuTaskbarLayout.xml."
$policyPath = "$policyKey\Explorer\StartLayoutFile"
Set-ItemProperty -Path $policyPath -Name "0" -Value $layoutFilePath

# Apply the layout to the non-admin user group
Write-Host -ForegroundColor Gray "Z> Applying StartMenuTaskbarLayout.xml to NonAdminGroup."
$groupSid = (New-Object System.Security.Principal.NTAccount("$userGroupName")).Translate([System.Security.Principal.SecurityIdentifier]).Value
$policyPath = "$policyKey\Explorer\RestrictStartMenu"
$policyValue = @(
    "@{User=%SID%}='1'"
    "@{User=$groupSid}='0'"
)
Set-ItemProperty -Path $policyPath -Name "0" -Value $policyValue


Write-Host -ForegroundColor White "========================================================================================="
Write-Host -ForegroundColor White "Z> Removing Apps and creating hardening Policy."
Write-Host -ForegroundColor White "========================================================================================="
Write-Host -ForegroundColor Gray "Z> Removing Chat and MS Store from taskbar."
# Remove the Chat app and Microsoft Store app from the Taskbar
$taskbarLayoutPath = "$env:APPDATA\Microsoft\Internet Explorer\Quick Launch\User Pinned\TaskBar"
$chatAppShortcutPath = Join-Path -Path $taskbarLayoutPath -ChildPath "Microsoft.ChatApp_8wekyb3d8bbwe.lnk"
$storeAppShortcutPath = Join-Path -Path $taskbarLayoutPath -ChildPath "Microsoft.WindowsStore_8wekyb3d8bbwe.lnk"

Remove-Item -Path $chatAppShortcutPath -ErrorAction SilentlyContinue
Remove-Item -Path $storeAppShortcutPath -ErrorAction SilentlyContinue

# Disable Control Panel and Settings access for non-admin users
Write-Host -ForegroundColor Gray "Z> Disabling Control Panel and Settings access for NonAdminGroup."
$policyPath = "$policyKey\Explorer\NoControlPanel"
Set-ItemProperty -Path $policyPath -Name "0" -Value "1"
$policyPath = "$policyKey\Explorer\NoSetFolders"
Set-ItemProperty -Path $policyPath -Name "0" -Value "1"


# Remove Run and Search functionality
Write-Host -ForegroundColor Gray "Z> Removing Run and Search functionality."
$policyPath = "$policyKey\Explorer\NoRun"
Set-ItemProperty -Path $policyPath -Name "0" -Value "1"
$policyPath = "$policyKey\Explorer\NoFind"
Set-ItemProperty -Path $policyPath -Name "0" -Value "1"


# Restrict shutdown privileges
Write-Host -ForegroundColor Gray "Z> Restricting shutdown privileges."
$policyPath = "$policyKey\Explorer\NoClose"
Set-ItemProperty -Path $policyPath -Name "0" -Value "1"


# Allow access to screen settings only
Write-Host -ForegroundColor Gray "Z> Allowing access to screen settings only."
$policyPath = "$policyKey\System"
Set-ItemProperty -Path $policyPath -Name "NoDispCpl" -Value "0"
Set-ItemProperty -Path $policyPath -Name "NoDispAppearancePage" -Value "1"
Set-ItemProperty -Path $policyPath -Name "NoDispBackgroundPage" -Value "1"
Set-ItemProperty -Path $policyPath -Name "NoDispSettingsPage" -Value "1"


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
