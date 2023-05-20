
# Define the Variables
$jsonFilePath = 'C:\ezNetworking\Automation\ezCloudDeploy\ezClientConfig.json'
$rdpFilePath = 'C:\ezNetworking\Automation\ezCloudDeploy\CustomerRDS.rdp'
$desktopFolderPath = [Environment]::GetFolderPath('CommonDesktopDirectory')
$rdpShortcutFilePath = Join-Path -Path $desktopFolderPath -ChildPath 'CustomerRDS.lnk'
$layoutFilePath = "C:\ezNetworking\Automation\ezCloudDeploy\StartMenuTaskbarLayout.xml"
$userName = "User"
$userGroupName = "NonAdminUsers"

# Load the JSON file
$jsonContent = Get-Content -Path $jsonFilePath -Raw | ConvertFrom-Json

# Get the RDS URI from the JSON file
$rdsUri = $jsonContent.ezClientConfig.custRdsUri

# Delete all links in the default public user's desktop
Get-ChildItem -Path $desktopFolderPath -Filter '*.*' -File | Remove-Item -Force

# Create the RDP file with the RDS URI
$rdpContent = @"
full address:s:$rdsUri
prompt for credentials:i:1
"@
$rdpContent | Out-File -FilePath $rdpFilePath -Encoding ASCII

# Create a shortcut to the RDP file on the public desktop
$shell = New-Object -ComObject WScript.Shell
$shortcut = $shell.CreateShortcut($rdpShortcutFilePath)
$shortcut.TargetPath = $rdpFilePath
$shortcut.Save()

# Create non-admin user
$createUserCmd = @"
$pass = ""
$localUserGroup = "$userGroupName"
$existingUser = Get-WmiObject -Class Win32_UserAccount -Filter "Name='$userName'"
if ($existingUser -eq $null) {
    $user = ([WMIClass] "Win32_UserAccount").Create($userName, $pass, $userName -eq "User")
    $user.Rename($userName)
    $user.SetPassword($pass)
    $user.PasswordExpires = $false
    $user.Put()
}
"@
Invoke-Expression $createUserCmd

# Add the user to the non-admin user group
$addGroupCmd = @"
$group = Get-WmiObject -Class Win32_Group -Filter "LocalAccount=True AND Name='$userGroupName'"
if ($group -eq $null) {
    $group = ([WMIClass] "Win32_Group").Create($userGroupName)
    $group.Put()
}

$user = Get-WmiObject -Class Win32_UserAccount -Filter "Name='$userName'"
$group.AddUser($user)
"@
Invoke-Expression $addGroupCmd

# Import the Start Menu and Taskbar layout
$layoutImportCmd = @"
$layoutFilePath = "C:\ezNetworking\Automation\ezCloudDeploy\StartMenuTaskbarLayout.xml"
$policyPath = "HKCU\Software\Microsoft\Windows\CurrentVersion\Group Policy Objects\{RSoP-Guid}\Machine\Preferences\Software\Microsoft\Windows\CurrentVersion\Policies\Explorer\StartLayoutFile"
Set-ItemProperty -Path $policyPath -Name "0" -Value $layoutFilePath
"@
Invoke-Expression $layoutImportCmd

# Apply the layout to the non-admin user group
$gpupdateCmd = @"
$groupSid = (New-Object System.Security.Principal.NTAccount("$userGroupName")).Translate([System.Security.Principal.SecurityIdentifier]).Value
$policyPath = "HKCU\Software\Microsoft\Windows\CurrentVersion\Group Policy Objects\{RSoP-Guid}\Machine\Preferences\Software\Microsoft\Windows\CurrentVersion\Policies\Explorer\RestrictStartMenu"
$policyValue = @(
    "@{User=%SID%"="1"}"
    "@{User=$groupSid}="0""
)
Set-ItemProperty -Path $policyPath -Name "0" -Value $policyValue
"@
Invoke-Expression $gpupdateCmd

# Remove the Chat app and Microsoft Store app from the Taskbar
$removeTaskbarAppsCmd = @"
$taskbarLayoutPath = "$env:APPDATA\Microsoft\Internet Explorer\Quick Launch\User Pinned\TaskBar"
$chatAppShortcutPath = Join-Path -Path $taskbarLayoutPath -ChildPath "Microsoft.ChatApp_8wekyb3d8bbwe.lnk"
$storeAppShortcutPath = Join-Path -Path $taskbarLayoutPath -ChildPath "Microsoft.WindowsStore_8wekyb3d8bbwe.lnk"

Remove-Item -Path $chatAppShortcutPath -ErrorAction SilentlyContinue
Remove-Item -Path $storeAppShortcutPath -ErrorAction SilentlyContinue
"@
Invoke-Expression $removeTaskbarAppsCmd


# Disable Control Panel and Settings access for non-admin users
$disableControlPanelCmd = @"
$policyPath = "HKCU\Software\Microsoft\Windows\CurrentVersion\Policies\Explorer\NoControlPanel"
Set-ItemProperty -Path $policyPath -Name "0" -Value "1"
"@
Invoke-Expression $disableControlPanelCmd

$disableSettingsCmd = @"
$policyPath = "HKCU\Software\Microsoft\Windows\CurrentVersion\Policies\Explorer\NoSetFolders"
Set-ItemProperty -Path $policyPath -Name "0" -Value "1"
"@
Invoke-Expression $disableSettingsCmd

# Remove Run and Search functionality
$removeRunCmd = @"
$policyPath = "HKCU\Software\Microsoft\Windows\CurrentVersion\Policies\Explorer\NoRun"
Set-ItemProperty -Path $policyPath -Name "0" -Value "1"
"@
Invoke-Expression $removeRunCmd

$removeSearchCmd = @"
$policyPath = "HKCU\Software\Microsoft\Windows\CurrentVersion\Policies\Explorer\NoFind"
Set-ItemProperty -Path $policyPath -Name "0" -Value "1"
"@
Invoke-Expression $removeSearchCmd

# Restrict shutdown privileges
$restrictShutdownCmd = @"
$policyPath = "HKCU\Software\Microsoft\Windows\CurrentVersion\Policies\Explorer\NoClose"
Set-ItemProperty -Path $policyPath -Name "0" -Value "1"
"@
Invoke-Expression $restrictShutdownCmd

# Allow access to screen settings only
$screenSettingsCmd = @"
$policyPath = "HKCU\Software\Microsoft\Windows\CurrentVersion\Policies\System"
Set-ItemProperty -Path $policyPath -Name "NoDispCpl" -Value "0"
Set-ItemProperty -Path $policyPath -Name "NoDispAppearancePage" -Value "1"
Set-ItemProperty -Path $policyPath -Name "NoDispBackgroundPage" -Value "1"
Set-ItemProperty -Path $policyPath -Name "NoDispSettingsPage" -Value "1"
"@
Invoke-Expression $screenSettingsCmd

