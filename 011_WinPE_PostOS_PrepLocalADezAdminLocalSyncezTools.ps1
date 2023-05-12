

# Block the script from running on Windows pre w10 and PowerShell pre v5
Block-WinOS
Block-WindowsVersionNe10
Block-PowerShellVersionLt5

# Check if folder exist, if not create them
Write-Host -ForegroundColor green "_______________________________________________________________________"
Write-Host -ForegroundColor green "                    Local AD Deployment Script"
Write-Host -ForegroundColor green "_______________________________________________________________________"
Write-Host -ForegroundColor green "  Zed says: Let's check if the folders exist, if not create them"
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

# Start transcript to c:\ezNetworking\Automation\ezCloudDeploy\Logs\ezCloudDeploy_011WinPePostOS_PrepLocalADezAdminLocalSyncezTools.log
Write-Host -ForegroundColor green "  Zed says: Let's start the transcript to c:\ezNetworking\Automation\Logs\ezCloudDeploy_011WinPePostOS_PrepLocalADezAdminLocalSyncezTools.log"
$transcriptPath = "c:\ezNetworking\Automation\Logs\ezCloudDeploy_011WinPePostOS_PrepLocalADezAdminLocalSyncezTools.log"
Start-Transcript -Path $transcriptPath

# Setup
Write-Host -ForegroundColor green "  Zed says: Let's setup the OSD environment"
#Set-ExecutionPolicy RemoteSigned -Force # Was unable to set that
# Install-Module OSD -Force # Was already installed
Import-Module OSD -Force

# Ask user for the computer name and ezRmmId
Write-Host -ForegroundColor green "  Zed Needs to know the computer name and ez RMM Customer ID."
$computerName = Read-Host "  Enter the computer name"
Write-Warning "Zed says: I will set the password of the new ezAdminLocal to our super secure "
Write-Warning "          password MakesYourNetWork! :):), as I can't do it securly here. "
Write-Warning "          But no panic, windows will demand you change it at first login. "
Write-Warning "          check 1P for the correct password."
$ezRmmId = Read-Host "  Enter the ezRmm Customer ID"

# Create a json config file with the ezRmmId
Write-Host -ForegroundColor green "  Zed says: I will create a json config file with the ezRmmId"
$ezClientConfig = @{
    ezRmmId = $ezRmmId
}
$ezClientConfig | ConvertTo-Json | Out-File -FilePath "C:\ezNetworking\Automation\ezCloudDeploy\ezClientConfig.json" -Encoding UTF8

# Put our autoUnattend xml template for Local AD OOBE in a variable
Write-Host -ForegroundColor green "  Zed says: I will put our autoUnattend xml template for Local AD OOBE (no online useraccount page) in a variable"
$unattendXml = @"
<?xml version="1.0" encoding="utf-8"?>
<unattend xmlns="urn:schemas-microsoft-com:unattend">
    <settings pass="windowsPE">
        <component name="Microsoft-Windows-International-Core-WinPE" processorArchitecture="amd64" publicKeyToken="31bf3856ad364e35" language="neutral" versionScope="nonSxS" xmlns:wcm="http://schemas.microsoft.com/WMIConfig/2002/State" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance">
            <SetupUILanguage>
                <UILanguage>en-US</UILanguage>
            </SetupUILanguage>
            <InputLocale>0813:00000813</InputLocale>
            <SystemLocale>en-US</SystemLocale>
            <UILanguage>en-US</UILanguage>
            <UILanguageFallback>en-US</UILanguageFallback>
            <UserLocale>en-GB</UserLocale>
        </component>
    </settings>
    <settings pass="specialize">
        <component name="Microsoft-Windows-International-Core" processorArchitecture="amd64" publicKeyToken="31bf3856ad364e35" language="neutral" versionScope="nonSxS" xmlns:wcm="http://schemas.microsoft.com/WMIConfig/2002/State" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance">
            <InputLocale>0813:00000813</InputLocale>
            <SystemLocale>en-GB</SystemLocale>
            <UILanguage>en-GB</UILanguage>
            <UILanguageFallback>en-GB</UILanguageFallback>
            <UserLocale>en-GB</UserLocale>
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
                <HideOnlineAccountScreens>true</HideOnlineAccountScreens>
                <HideWirelessSetupInOOBE>false</HideWirelessSetupInOOBE>
                <NetworkLocation>Work</NetworkLocation>
                <SkipUserOOBE>true</SkipUserOOBE>
                <SkipMachineOOBE>true</SkipMachineOOBE>
                <ProtectYourPC>3</ProtectYourPC>
            </OOBE>
            <UserAccounts>
                <LocalAccounts>
                    <LocalAccount wcm:action="add">
                        <Password>
                            <Value>MakesYourNetWork!</Value>
                            <PlainText>true</PlainText>
                        </Password>
                        <Description>Local Admin Account for ez Networking</Description>
                        <DisplayName>ezAdmin Local | ez Networking</DisplayName>
                        <Group>Administrators</Group>
                        <Name>ezAdminLocal</Name>
                    </LocalAccount>
                </LocalAccounts>
            </UserAccounts>
            <RegisteredOrganization>ez Networking</RegisteredOrganization>
            <RegisteredOwner>ezAdminLocal</RegisteredOwner>
            <DisableAutoDaylightTimeSet>false</DisableAutoDaylightTimeSet>
            <FirstLogonCommands>
                <SynchronousCommand wcm:action="add">
                    <Description>Default Apps And Onboard</Description>
                    <Order>1</Order>
                    <CommandLine>C:\Windows\System32\WindowsPowerShell\v1.0\powershell.exe -ExecutionPolicy Bypass -File c:\ezNetworking\Automation\ezCloudDeploy\Scripts\DefaultAppsAndOnboard.ps1</CommandLine>
                    <RequiresUserInput>true</RequiresUserInput>
                </SynchronousCommand>
                <SynchronousCommand wcm:action="add">
                    <Order>2</Order>
                    <RequiresUserInput>false</RequiresUserInput>
                    <CommandLine>cmd /C wmic useraccount where name="ezAdminLocal" set PasswordExpires=false</CommandLine>
                </SynchronousCommand>
                <SynchronousCommand wcm:action="add">
                    <Description>Join Domain at first login</Description>
                    <Order>3</Order>
                    <CommandLine>C:\Windows\System32\WindowsPowerShell\v1.0\powershell.exe -ExecutionPolicy Bypass -File c:\ezNetworking\Automation\ezCloudDeploy\Scripts\JoinDomainAtFirstLogin.ps1</CommandLine>
                    <RequiresUserInput>true</RequiresUserInput>
                </SynchronousCommand>
            </FirstLogonCommands>
            <TimeZone>Romance Standard Time</TimeZone>
        </component>
    </settings>
</unattend>
"@

# Write the updated unattend.xml file to c:\ezNetworking\Automation\ezCloudDeploy\AutoUnattend\
Write-Host -ForegroundColor green "  Zed says: Writing the unattend.xml file to c:\ezNetworking\Automation\ezCloudDeploy\AutoUnattend\"
$unattendPath = "C:\ezNetworking\Automation\ezCloudDeploy\AutoUnattend\LocalAdUnattend.xml"
try {
    $unattendXml | Out-File -FilePath $unattendPath -Encoding UTF8
    
}
catch {
    Write-Error "  Zed says: $unattendPath already exists or you don't have the rights to create it"
}

# Download the DefaultAppsAndOnboard.ps1 script from github
Write-Host -ForegroundColor green "  Zed says: downloading the DefaultAppsAndOnboardScript.ps1 script from ezCloudDeploy github..."
try {
    $DefaultAppsAndOnboardResponse = Invoke-WebRequest -Uri "https://raw.githubusercontent.com/ezNetworking/ezCloudDeploy/master/non_ezCloudDeployGuiScripts/111_Windows_PostOS_DefaultAppsAndOnboard.ps1" -UseBasicParsing 
    $DefaultAppsAndOnboardScript = $DefaultAppsAndOnboardResponse.content
    Write-Host -ForegroundColor green "  Zed says: Saving the Onboard script to c:\ezNetworking\Automation\ezCloudDeploy\Scripts\DefaultAppsAndOnboard.ps1"
    $DefaultAppsAndOnboardScriptPath = "c:\ezNetworking\Automation\ezCloudDeploy\Scripts\DefaultAppsAndOnboard.ps1"
    $DefaultAppsAndOnboardScript | Out-File -FilePath $DefaultAppsAndOnboardScriptPath -Encoding UTF8
}
catch {
    Write-Error "  Zed says: I was unable to download the DefaultAppsAndOnboardScript.ps1 script from github"
}

# Download the JoinDomainAtFirstLogin.ps1 script from github
Write-Host -ForegroundColor green "  Zed says: downloading the JoinDomainAtFirstLogin.ps1 script from ezCloudDeploy github..."
try {
    $JoinDomainAtFirstLoginResponse = Invoke-WebRequest -Uri "https://raw.githubusercontent.com/ezNetworking/ezCloudDeploy/master/non_ezCloudDeployGuiScripts/101_Windows_PostOOBE_JoinDomainAtFirstLogin.ps1" -UseBasicParsing 
    $JoinDomainAtFirstLoginScript = $JoinDomainAtFirstLoginResponse.content
    Write-Host -ForegroundColor green "  Zed says: Saving the AD Join script to c:\ezNetworking\Automation\ezCloudDeploy\Scripts\JoinDomainAtFirstLogin.ps1"
    $JoinDomainAtFirstLoginScriptPath = "c:\ezNetworking\Automation\ezCloudDeploy\Scripts\JoinDomainAtFirstLogin.ps1"
    $JoinDomainAtFirstLoginScript | Out-File -FilePath $JoinDomainAtFirstLoginScriptPath -Encoding UTF8
    }
catch {
    Write-Error "  Zed says: I was unable to download the JoinDomainAtFirstLogin.ps1 script from github"
}

# Set the unattend.xml file in the offline registry
Write-Host -ForegroundColor green "  Zed says: Setting the unattend.xml file in the offline registry"
reg load HKLM\TempSYSTEM "C:\Windows\System32\Config\SYSTEM"
reg add HKLM\TempSYSTEM\Setup /v UnattendFile /d $unattendPath /f
reg unload HKLM\TempSYSTEM

# Use Start-OOBEDeploy to remove the following apps in the later OOBE phase: CommunicationsApps,OfficeHub,People,Skype,Solitaire,Xbox,ZuneMusic,ZuneVideo"
Write-Host -ForegroundColor green "  Zed says: Use Start-OOBEDeploy to remove the following apps in the later OOBE phase: CommunicationsApps,MicrosoftTeams,OfficeHub,People,Skype,Solitaire,Xbox,ZuneMusic,ZuneVideo"
Start-OOBEDeploy -RemoveAppx CommunicationsApps,OfficeHub,People,Skype,Solitaire,Xbox,ZuneMusic,ZuneVideo

#And stop the transcript.
Stop-Transcript
Write-Warning "  ________________________________________________________________________________________"
Write-Warning "  Zed says: I'm done mate! If you do not see any errors above you can shut down this PC "
Write-Warning "            and send it to the customer. The first boot will take a while, so be patient."
Write-Warning " "
Write-Warning "            First Boot at Customer: Once logged in a Domain Join Gui will be displayed "
Write-Warning "            and in the background the default apps will be installed, so make sure the "
Write-Warning "            network cable is plugged in. If you do see errors, please check the log file "
write-warning "            at $transcriptPath and fix the errors."
Write-Warning "  _________________________________________________________________________________________"
Read-Host -Prompt "            Press any key to shutdown this Computer"

Stop-Computer -Force

<#
.SYNOPSIS
Configures OOBE with Local Active Directory (AD) and removes specified default apps and sets a domain join GUI to be loaded at first login.

.DESCRIPTION
This script checks if the required folders exist, creates them if they don't, sets up the environment, prompts the user to input a computer name, 
generates an unattend.xml file to customize the Windows 10 installation with Local AD, 
downloads a PowerShell script to join the domain at first login, saves it in the correct folder, configures the unattend.xml file to run the script, 
starts OOBEDeploy with the customized unattend.xml file, and removes specified default apps. It also creates a transcript of the deployment process.

.INPUTS
This script prompts the user to input the computer name.

.EXAMPLE
Deploy-Windows10LocalAD -ComputerName "MyComputer01"

This command configures a Windows 10/11 image with Local AD on a computer named "MyComputer01". 
It removes the default apps CommunicationsApps, OfficeHub, People, Skype, Solitaire, Xbox, ZuneMusic, and ZuneVideo.

.NOTES
Author: Jurgen Verhelst | ez Networking | www.ez.be
#>
