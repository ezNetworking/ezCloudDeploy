# Block the script from running on Windows pre w10 and PowerShell pre v5
Block-WinOS
Block-WindowsVersionNe10
Block-PowerShellVersionLt5

Write-Host -ForegroundColor green "_______________________________________________________________________"
Write-Host -ForegroundColor green "                    Azure AD Deployment Script"
Write-Host -ForegroundColor green "_______________________________________________________________________"

Write-Host -ForegroundColor green "  Zed says: Let's check if the folders exist, if not create them"
# Check if folder exist, if not create them
$folders = "c:\ezNetworking\Automation\ezCloudDeploy\AutoUnattend\", "c:\ezNetworking\Automation\Logs", "c:\ezNetworking\Automation\ezCloudDeploy\Scripts", "C:\ProgramData\OSDeploy"
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

# Start transcript to c:\ezNetworking\Automation\ezCloudDeploy\Logs\ezCloudDeploy_012WinPePostOS_PrepAzureADezAdminLocalSyncezTools.log
Write-Host -ForegroundColor green "  Zed says: Let's start the transcript to c:\ezNetworking\Automation\Logs\ezCloudDeploy_012WinPePostOS_PrepAzureADezAdminLocalSyncezTools.log"
$transcriptPath = "c:\ezNetworking\Automation\Logs\ezCloudDeploy_012WinPePostOS_PrepAzureADezAdminLocalSyncezTools.log"
Start-Transcript -Path $transcriptPath

# Setup
Write-Host -ForegroundColor green "  Zed says: Let's setup the OSD environment"
#Set-ExecutionPolicy RemoteSigned -Force # Was unable to set that
# Install-Module OSD -Force # Was already installed
Import-Module OSD -Force

# Ask user for the computer name and ezRmmId
Write-Host -ForegroundColor green "  Zed Needs to know the computer name and ez RMM Customer ID."
$computerName = Read-Host "  Enter the computer name"
$ezRmmId = Read-Host "  Enter the ez RMM Customer ID"

# Create a json config file with the ezRmmId
Write-Host -ForegroundColor green "  Zed says: Creating a json config file with the ezRmmId"
$ezClientConfig = @{
    ezRmmId = $ezRmmId
}
$ezClientConfig | ConvertTo-Json | Out-File -FilePath "C:\ezNetworking\Automation\ezCloudDeploy\ezClientConfig.json" -Encoding UTF8

# Put our autoUnattend xml template for Azure AD OOBE in a variable
Write-Host -ForegroundColor green "  Zed says: Updating our Unattend xml for Azure AD OOBE (no online useraccount page)"
$unattendXml = @"
<?xml version="1.0" encoding="utf-8"?>
<unattend xmlns="urn:schemas-microsoft-com:unattend">
    <settings pass="windowsPE">
        <component name="Microsoft-Windows-International-Core-WinPE" processorArchitecture="amd64" publicKeyToken="31bf3856ad364e35" language="neutral" versionScope="nonSxS" xmlns:wcm="http://schemas.microsoft.com/WMIConfig/2002/State" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance">
            <SetupUILanguage>
                <UILanguage>en-US</UILanguage>
            </SetupUILanguage>
            <InputLocale>0813:00000813</InputLocale>
            <SystemLocale>nl-BE</SystemLocale>
            <UILanguage>en-US</UILanguage>
            <UILanguageFallback>en-US</UILanguageFallback>
            <UserLocale>nl-BE</UserLocale>
        </component>
    </settings>
    <settings pass="specialize">
        <component name="Microsoft-Windows-International-Core" processorArchitecture="amd64" publicKeyToken="31bf3856ad364e35" language="neutral" versionScope="nonSxS" xmlns:wcm="http://schemas.microsoft.com/WMIConfig/2002/State" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance">
            <InputLocale>0813:00000813</InputLocale>
            <SystemLocale>nl-BE</SystemLocale>
            <UILanguage>en-GB</UILanguage>
            <UILanguageFallback>en-GB</UILanguageFallback>
            <UserLocale>nl-BE</UserLocale>
        </component>
        <component name="Microsoft-Windows-Shell-Setup" processorArchitecture="amd64" publicKeyToken="31bf3856ad364e35" language="neutral" versionScope="nonSxS" xmlns:wcm="http://schemas.microsoft.com/WMIConfig/2002/State" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance">
            <ComputerName>$ComputerName</ComputerName>
        </component>
    </settings>
    <settings pass="oobeSystem">
        <component name="Microsoft-Windows-Shell-Setup" processorArchitecture="amd64" publicKeyToken="31bf3856ad364e35" language="neutral" versionScope="nonSxS" xmlns:wcm="http://schemas.microsoft.com/WMIConfig/2002/State" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance">
            <OOBE>        
                <HideEULAPage>true</HideEULAPage>
                <HideOEMRegistrationScreen>true</HideOEMRegistrationScreen>
                <HideOnlineAccountScreens>false</HideOnlineAccountScreens>
                <HideWirelessSetupInOOBE>false</HideWirelessSetupInOOBE>
                <NetworkLocation>Work</NetworkLocation>
                <SkipUserOOBE>false</SkipUserOOBE>
                <SkipMachineOOBE>false</SkipMachineOOBE>
                <ProtectYourPC>3</ProtectYourPC>
            </OOBE>
            <RegisteredOrganization>ez Networking</RegisteredOrganization>
            <RegisteredOwner>ezAdminLocal</RegisteredOwner>
            <DisableAutoDaylightTimeSet>false</DisableAutoDaylightTimeSet>
            <TimeZone>Romance Standard Time</TimeZone>
        </component>
    </settings>
</unattend>
"@

# Write the updated unattend.xml file to c:\ezNetworking\Automation\ezCloudDeploy\AutoUnattend\
Write-Host -ForegroundColor green "  Zed says: Writing the unattend.xml file to c:\ezNetworking\Automation\ezCloudDeploy\AutoUnattend\"
$unattendPath = "C:\ezNetworking\Automation\ezCloudDeploy\AutoUnattend\AzureAdUnattend.xml"
try {
    $unattendXml | Out-File -FilePath $unattendPath -Encoding UTF8
    
}
catch {
    Write-Error "  Zed says: $unattendPath already exists or you don't have the rights to create it"
}

# Download the DefaultAppsAndOnboard.ps1 script from github
Write-Host -ForegroundColor green "  Zed says: Downloading the DefaultAppsAndOnboardScript.ps1 script from ezCloudDeploy."
try {
    $DefaultAppsAndOnboardResponse = Invoke-WebRequest -Uri "https://raw.githubusercontent.com/ezNetworking/ezCloudDeploy/master/non_ezCloudDeployGuiScripts/111_Windows_PostOS_DefaultAppsAndOnboard.ps1" -UseBasicParsing 
    $DefaultAppsAndOnboardScript = $DefaultAppsAndOnboardResponse.content
    Write-Host -ForegroundColor green "  Zed says: Saving the Onboard script to c:\ezNetworking\Automation\ezCloudDeploy\Scripts\DefaultAppsAndOnboard.ps1"
    $DefaultAppsAndOnboardScriptPath = "c:\ezNetworking\Automation\ezCloudDeploy\Scripts\DefaultAppsAndOnboard.ps1"
    $DefaultAppsAndOnboardScript | Out-File -FilePath $DefaultAppsAndOnboardScriptPath -Encoding UTF8
}
catch {
    Write-Error "  Zed says: I was unable to download the DefaultAppsAndOnboardScript script."
}

# Set the unattend.xml file in the offline registry
Write-Host -ForegroundColor green "  Zed says: Setting the unattend.xml file in the offline registry"
reg load HKLM\TempSYSTEM "C:\Windows\System32\Config\SYSTEM"
reg add HKLM\TempSYSTEM\Setup /v UnattendFile /d $unattendPath /f
reg unload HKLM\TempSYSTEM

# Use Start-OOBEDeploy to remove the following apps in the later OOBE phase: CommunicationsApps,MicrosoftTeams,OfficeHub,People,Skype,Solitaire,Xbox,ZuneMusic,ZuneVideo"
Write-Host -ForegroundColor green "  Zed says: Use Start-OOBEDeploy to remove apps in the later OOBE phase: "
Write-Host -ForegroundColor green "            CommunicationsApps,MicrosoftTeams,OfficeHub,People,Skype,Solitaire,Xbox,ZuneMusic,ZuneVideo"
Start-OOBEDeploy -RemoveAppx CommunicationsApps,MicrosoftTeams,OfficeHub,People,Skype,Solitaire,Xbox,ZuneMusic,ZuneVideo

#And stop the transcript.
Stop-Transcript
Write-Warning "  ________________________________________________________________________________________"
Write-Warning "  Zed says: I'm done mate! If you do not see any errors above you can shut down this PC "
Write-Warning "            and send it to the customer. The first boot will take a while, so be patient."
Write-Warning " "
Write-Warning "            First Boot at Customer: The user can login using his work account,"
Write-Warning "            and in the background the default apps will be installed, so make sure the "
Write-Warning "            network cable is plugged in. If you do see errors, please check the log file at "
write-warning "            $transcriptPath."
Write-Warning "  _________________________________________________________________________________________"
Read-Host -Prompt "            Press any key to shutdown this Computer"

Stop-Computer -Force

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
