<#
.SYNOPSIS
Configures OOBE with Azure Active Directory (AAD) and removes specified default apps.

.DESCRIPTION
This script checks if the required folders exist, creates them if they don't, sets up the environment, 
prompts the user to input a computer name, generates an unattend.xml file to customize the Windows 10 installation with Azure AD, 
starts OOBEDeploy with the customized unattend.xml file, and removes specified default apps. It also creates a transcript of the deployment process.

.INPUTS
This script prompts the user to input the computer name.

.EXAMPLE
012_WinPE_PostOS_PrepAzureADezAdminLocalSyncezTools.ps1 -ComputerName "MyComputer01" -LocalAdminPassword "MyPassword"

This command configures a Windows 10/11 image with Azure AD on a computer named "MyComputer01" and localAdminPassword "MyPassword" . 
It removes the default apps CommunicationsApps, OfficeHub, People, Skype, Solitaire, Xbox, ZuneMusic, and ZuneVideo.

.NOTES
Author: Jurgen Verhelst | ez Networking | www.ez.be
#>

# Block the script from running on Windows pre w10 and PowerShell pre v5
Block-WinOS
Block-WindowsVersionNe10
Block-PowerShellVersionLt5

# Check if folder exist, if not create them
Write-Host -ForegroundColor green "_______________________________________________________________________"
Write-Host -ForegroundColor green "                    Azure AD Deployment Script"
Write-Host -ForegroundColor green "_______________________________________________________________________"
Write-Host -ForegroundColor green -ForegroundColor green "  Zed says: Let's check if the folders exist, if not create them"
$folders = "c:\ezNetworking\Automation\ezCloudDeploy\AutoUnattend\", "c:\ezNetworking\Automation\Logs", "c:\ezNetworking\Automation\ezCloudDeploy\Scripts", "C:\ProgramData\OSDeploy", 'C:\Windows\Panther'
foreach ($folder in $folders) {
    if (!(Test-Path $folder)) {
        try {
            New-Item -ItemType Directory -Path $folder | Out-Null
    
        }
        catch {
            Write-Error "  Zed says: $folder already exists or you don't have the rights to create it"
        }    }
    else {
        Write-Warning "  Zed says: $folder already exists"
    }
}

# Start transcript to c:\ezNetworking\Automation\ezCloudDeploy\Logs\ezCloudDeploy_011WinPePostOS_PrepLocalADezAdminLocalSyncezTools.log
Write-Host -ForegroundColor green "  Zed says: Let's start the transcript to c:\ezNetworking\Automation\Logs\ezCloudDeploy_011WinPePostOS_PrepAzureADezAdminLocalSyncezTools.log"
$transcriptPath = "c:\ezNetworking\Automation\Logs\ezCloudDeploy_011WinPePostOS_PrepLocalADezAdminLocalSyncezTools.log"
Start-Transcript -Path $transcriptPath

# Setup
Write-Host -ForegroundColor green "  Zed says: Let's setup the environment"
#Set-ExecutionPolicy RemoteSigned -Force # Was unable to set that
Install-Module OSD -Force
Import-Module OSD -Force

# Ask user for the computer name and local admins password
Write-Host -ForegroundColor green "   Zed Needs to know the computer name and password"
$computerName = Read-Host "Enter the computer name"
$localAdminPassword = Read-Host "Enter the local admin password (check in 1P)" -AsSecureString

# Put our autoUnattend xml template for Azure AD OOBE in a variable
Write-Host -ForegroundColor green " Zed says: I will put our autoUnattend xml template for Azure AD OOBE (no online useraccount page) in a variable"
$unattendXml = @"
<?xml version="1.0" encoding="utf-8"?>
<unattend xmlns="urn:schemas-microsoft-com:unattend">
    <settings pass="oobeSystem">
        <component name="Microsoft-Windows-International-Core" publicKeyToken="31bf3856ad364e35" language="neutral" versionScope="nonSxS">
            <InputLocale>0813:00000813</InputLocale>
            <SystemLocale>nl-BE</SystemLocale>
            <UILanguage>en-US</UILanguage>
            <UILanguageFallback>en-US</UILanguageFallback>
            <UserLocale>nl-BE</UserLocale>
            <UILanguage_DefaultUser>en-US</UILanguage_DefaultUser>
            <UILanguageFallback_DefaultUser>en-US</UILanguageFallback_DefaultUser>
            <UserLocale_DefaultUser>nl-BE</UserLocale_DefaultUser>
            <InputLocale_DefaultUser>0813:00000813</InputLocale_DefaultUser>
            <SystemLocale_DefaultUser>nl-BE</SystemLocale_DefaultUser>
            <TimeZone>Central European Standard Time</TimeZone>
        </component>
        <component name="Microsoft-Windows-Shell-Setup" publicKeyToken="31bf3856ad364e35" language="neutral" versionScope="nonSxS">
            <InputLocale>0813:00000813</InputLocale>
            <SystemLocale>nl-BE</SystemLocale>
            <UILanguage>nl-BE</UILanguage>
            <UILanguageFallback>en-US</UILanguageFallback>
            <UserLocale>nl-BES</UserLocale>
            <UILanguage_DefaultUser>en-US</UILanguage_DefaultUser>
            <UILanguageFallback_DefaultUser>en-US</UILanguageFallback_DefaultUser>
            <UserLocale_DefaultUser>nl-BE</UserLocale_DefaultUser>
            <InputLocale_DefaultUser>0813:00000813</InputLocale_DefaultUser>
            <SystemLocale_DefaultUser>nl-BES</SystemLocale_DefaultUser>
            <TimeZone>Central European Standard Time</TimeZone>
            <ComputerName>$computerName</ComputerName>
            <OOBE>
                <OEMInformation>
                    <SupportProvider>ez Networking Support</SupportProvider>
                    <Manufacturer>HP</Manufacturer>
                    <SupportHours>8/5 to 24/7 depending on contract</SupportHours>
                    <SupportPhone>+32 3 376 14 25</SupportPhone>
                    <SupportURL>http://www.ez.be</SupportURL>
                </OEMInformation>
                <HideEULAPage>true</HideEULAPage>
                <HideOEMRegistrationScreen>true</HideOEMRegistrationScreen>
                <HideOnlineAccountScreens>false</HideOnlineAccountScreens>
                <HideWirelessSetupInOOBE>false</HideWirelessSetupInOOBE>
                <ProtectYourPC>3</ProtectYourPC>
                <RunSynchronous>
                    <RunSynchronousCommand wcm:action="add">
                        <Order>1</Order>
                        <CommandLine>powershell.exe -NoProfile -ExecutionPolicy unrestricted -Command "iex ((new-object net.webclient).DownloadString('https://chocolatey.org/install.ps1'))"</CommandLine>
                        <Description>Install Chocolatey</Description>
                        <RequiresUserInput>false</RequiresUserInput>
                    </RunSynchronousCommand>
                    <RunSynchronousCommand wcm:action="add">
                        <Order>2</Order>
                        <CommandLine>powershell.exe -NoProfile -ExecutionPolicy unrestricted -Command "choco install tree-size-free -y"</CommandLine>
                        <Description>Install TreeSize via Chocolatey</Description>
                        <RequiresUserInput>false</RequiresUserInput>
                    </RunSynchronousCommand>
                </RunSynchronous>
    
            </OOBE>
            <UserAccounts>
                <AdministratorPassword>
                    <Value>$localAdminPassword</Value>
                    <PlainText>true</PlainText>
                </AdministratorPassword>
                <LocalAccounts>
                    <LocalAccount wcm:action="add">
                        <Password>
                        <Value>$localAdminPassword</Value>
                        <PlainText>true</PlainText>
                        </Password>
                        <DisplayName>ezAdminLocal | ez Networking</DisplayName>
                        <Group>Administrators</Group>
                        <Name>ezAdminLocal</Name>
                    </LocalAccount>
                </LocalAccounts>
            </UserAccounts>
        </component>
    </settings>
</unattend>
"@
Write-Host -ForegroundColor green " Zed says: I have a nice unattend.xml template for you: $unattendXml"

# Write the updated unattend.xml file to c:\ezNetworking\Automation\ezCloudDeploy\AutoUnattend\
Write-Host -ForegroundColor green " Zed says: Writing the unattend.xml file to c:\ezNetworking\Automation\ezCloudDeploy\AutoUnattend\"
$unattendPath = "C:\ezNetworking\Automation\ezCloudDeploy\AutoUnattend\AzureAdUnattend.xml"
try {
    $unattendXml | Out-File -FilePath $unattendPath -Encoding UTF8
    
}
catch {
    Write-Error " Zed says: $unattendPath already exists or you don't have the rights to create it"
}

# Set the unattend.xml file in the offline registry
Write-Host -ForegroundColor green " Zed says: Setting the unattend.xml file in the offline registry"
reg load HKLM\TempSYSTEM "C:\Windows\System32\Config\SYSTEM"
reg add HKLM\TempSYSTEM\Setup /v UnattendFile /d $unattendPath /f
reg unload HKLM\TempSYSTEM

# Use Start-OOBEDeploy to remove the following apps in the later OOBE phase: CommunicationsApps,OfficeHub,People,Skype,Solitaire,Xbox,ZuneMusic,ZuneVideo"
Write-Host -ForegroundColor green "  Zed says: Use Start-OOBEDeploy to remove the following apps in the later OOBE phase: CommunicationsApps,OfficeHub,People,Skype,Solitaire,Xbox,ZuneMusic,ZuneVideo"
Start-OOBEDeploy -RemoveAppx CommunicationsApps,OfficeHub,People,Skype,Solitaire,Xbox,ZuneMusic,ZuneVideo

#And stop the transcript.
Write-Host -ForegroundColor green "  Zed says: And stopping the trancsript. Check out the log file at $transcriptPath and also check if the settings applied and the apps are removed."
Stop-Transcript
