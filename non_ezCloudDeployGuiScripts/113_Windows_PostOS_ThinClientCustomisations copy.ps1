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

# Create the NonAdminUsers group
$createGroupCmd = @"
$group = Get-WmiObject -Class Win32_Group -Filter "LocalAccount=True AND Name='$userGroupName'"
if ($group -eq $null) {
    $group = ([WMIClass] "Win32_Group").Create($userGroupName)
    $group.Put()
}
"@
Invoke-Expression $createGroupCmd

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
$user = Get-WmiObject -Class Win32_UserAccount -Filter "Name='$userName'"
$group = Get-WmiObject -Class Win32_Group -Filter "LocalAccount=True AND Name='$userGroupName'"
$group.AddUser($user)
"@
Invoke-Expression $addGroupCmd

# Create and import the local group policy
$policyCmd = @"
$policyName = "ThinClientUsers"
$policyPath = "HKLM\Software\Policies\Microsoft\Windows"
$policyKey = "$policyPath\$policyName"
$layoutPolicyPath = "$policyKey\Explorer"
$layoutPolicyValueName = "LockedStartLayout"
$layoutPolicyValue = "1"

if (-not (Test-Path -Path $policyKey)) {
    New-Item -Path $policyKey -ItemType RegistryKey | Out-Null
}

New-ItemProperty -Path $layoutPolicyPath -Name $layoutPolicyValueName -
$layoutPolicyValue -ValueType DWORD -Value $layoutPolicyValue -Force
"@
Invoke-Expression $policyCmd

# Import the Start Menu and Taskbar layout
$layoutImportCmd = @"
$policyPath = "$policyKey\Explorer\StartLayoutFile"
Set-ItemProperty -Path $policyPath -Name "0" -Value $layoutFilePath
"@
Invoke-Expression $layoutImportCmd

# Apply the layout to the non-admin user group
$gpupdateCmd = @"
$groupSid = (New-Object System.Security.Principal.NTAccount("$userGroupName")).Translate([System.Security.Principal.SecurityIdentifier]).Value
$policyPath = "$policyKey\Explorer\RestrictStartMenu"
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
$policyPath = "$policyKey\Explorer\NoControlPanel"
Set-ItemProperty -Path $policyPath -Name "0" -Value "1"
"@
Invoke-Expression $disableControlPanelCmd

$disableSettingsCmd = @"
$policyPath = "$policyKey\Explorer\NoSetFolders"
Set-ItemProperty -Path $policyPath -Name "0" -Value "1"
"@
Invoke-Expression $disableSettingsCmd

# Remove Run and Search functionality
$removeRunCmd = @"
$policyPath = "$policyKey\Explorer\NoRun"
Set-ItemProperty -Path $policyPath -Name "0" -Value "1"
"@
Invoke-Expression $removeRunCmd

$removeSearchCmd = @"
$policyPath = "$policyKey\Explorer\NoFind"
Set-ItemProperty -Path $policyPath -Name "0" -Value "1"
"@
Invoke-Expression $removeSearchCmd

# Restrict shutdown privileges
$restrictShutdownCmd = @"
$policyPath = "$policyKey\Explorer\NoClose"
Set-ItemProperty -Path $policyPath -Name "0" -Value "1"
"@
Invoke-Expression $restrictShutdownCmd

# Allow access to screen settings only
$screenSettingsCmd = @"
$policyPath = "$policyKey\System"
Set-ItemProperty -Path $policyPath -Name "NoDispCpl" -Value "0"
Set-ItemProperty -Path $policyPath -Name "NoDispAppearancePage" -Value "1"
Set-ItemProperty -Path $policyPath -Name "NoDispBackgroundPage" -Value "1"
Set-ItemProperty -Path $policyPath -Name "NoDispSettingsPage" -Value "1"
"@
Invoke-Expression $screenSettingsCmd
