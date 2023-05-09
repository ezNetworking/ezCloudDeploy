<#
.SYNOPSIS
Configures OOBE with Azure Active Directory (AAD) and removes specified default apps and sets a domain join GUI to be loaded at first login.

.DESCRIPTION
This script checks if the required folders exist, creates them if they don't, sets up the environment, prompts the user to input a computer name, 
generates an unattend.xml file to customize the Windows 10 installation with Azure AD, configures the unattend.xml file to run the script, 
starts OOBEDeploy with the customized unattend.xml file, and removes specified default apps. It also creates a transcript of the deployment process.

.INPUTS
This script prompts the user to input the computer name.

.EXAMPLE
Deploy-Windows10AzureAD -ComputerName "MyComputer01"

This command configures a Windows 10/11 image with Local AD on a computer named "MyComputer01". 
It removes the default apps CommunicationsApps, OfficeHub, People, Skype, Solitaire, Xbox, ZuneMusic, and ZuneVideo.

.NOTES
Author: Jurgen Verhelst | ez Networking | www.ez.be
#>


# Check if folder exist, if not create them
Write-Host "  Zed says: Let's check if the folders exist, if not create them"
$folders = "c:\ezNetworking\Automation\ezCloudDeploy\AutoUnattend\", "c:\ezNetworking\Automation\Logs", "c:\ezNetworking\Automation\ezCloudDeploy\Scripts"
foreach ($folder in $folders) {
    if (!(Test-Path $folder)) {
        New-Item -ItemType Directory -Path $folder | Out-Null
    }
}

# Start transcript to c:\ezNetworking\Automation\ezCloudDeploy\Logs\ezCloudDeploy_012WinPePostOS_PrepAzureADezAdminLocalSyncezTools.log
Write-Host "  Zed says: Let's start the transcript to c:\ezNetworking\Automation\Logs\ezCloudDeploy_012WinPePostOS_PrepAzureADezAdminLocalSyncezTools.log"
$transcriptPath = "c:\ezNetworking\Automation\Logs\ezCloudDeploy_012WinPePostOS_PrepAzureADezAdminLocalSyncezTools.log"
Start-Transcript -Path $transcriptPath

# Setup
Write-Host "  Zed says: Let's setup the environment"
Set-ExecutionPolicy RemoteSigned -Force
Install-Module OSD -Force
Import-Module OSD -Force

# Ask user for the computer name and local admins password
Write-Host "   Zed Needs to know the computer name and password"
$computerName = Read-Host "Enter the computer name"
$AzureADminPassword = Read-Host "Enter the local admin password (check in 1P)" -AsSecureString

# Put our autoUnattend xml template for Local AD OOBE in a variable
Write-Host " Zed says: I will put our autoUnattend xml template for Local AD OOBE (no online useraccount page) in a variable"
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
            <ComputerName>COMPUTERNAME</ComputerName>
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
            </OOBE>
        </component>
    </settings>
</unattend>
"@
Write-Host " Zed says: I have a nice unattend.xml template for you: $unattendXml"

# Replace the computername and password in the unattend.xml file
Write-Host " Zed says: I will replace the computername in the unattend.xml file"
(Get-Content $unattendXml) -replace "COMPUTERNAME", $computerName | Out-File $unattendPath

# Write the unattend.xml file to c:\ezNetworking\Automation\ezCloudDeploy\AutoUnattend\
Write-Host " Zed says: will write the AzureAdUnattend.xml file to c:\ezNetworking\Automation\ezCloudDeploy\AutoUnattend\"
$unattendPath = "C:\ezNetworking\Automation\ezCloudDeploy\AutoUnattend\AzureAdUnattend.xml"
$unattendXml | Out-File -FilePath $unattendPath -Encoding UTF8

# Start OOBEDeploy using the unattend.xml file created in c:\ezNetworking\Automation\ezCloudDeploy\AutoUnattend\ and remove the following apps: CommunicationsApps,OfficeHub,People,Skype,Solitaire,Xbox,ZuneMusic,ZuneVideo
Write-Host "  Zed says: Let's start OOBEDeploy using the unattend.xml file created in c:\ezNetworking\Automation\ezCloudDeploy\AutoUnattend\ and remove the following apps: CommunicationsApps,OfficeHub,People,Skype,Solitaire,Xbox,ZuneMusic,ZuneVideo"
Start-OOBEDeploy Start-OOBEDeploy -CustomProfile $unattendPath -RemoveAppx CommunicationsApps,OfficeHub,People,Skype,Solitaire,Xbox,ZuneMusic,ZuneVideo

#And stop the transcript.
Write-Host "  Zed says: And stopping the trancsript. Check out the log file at $transcriptPath and also check if the settings applied and the apps are removed."
Stop-Transcript
