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

# Block the script from running on Windows pre w10 and PowerShell pre v5
Block-WinOS
Block-WindowsVersionNe10
Block-PowerShellVersionLt5

# Check if folder exist, if not create them
Write-Host -ForegroundColor green "_______________________________________________________________________"
Write-Host -ForegroundColor green "                    Local AD Deployment Script"
Write-Host -ForegroundColor green "_______________________________________________________________________"
Write-Host -ForegroundColor green "  Zed says: Let's check if the folders exist, if not create them"
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
Write-Host -ForegroundColor green "  Zed says: Let's start the transcript to c:\ezNetworking\Automation\Logs\ezCloudDeploy_011WinPePostOS_PrepLocalADezAdminLocalSyncezTools.log"
$transcriptPath = "c:\ezNetworking\Automation\Logs\ezCloudDeploy_011WinPePostOS_PrepLocalADezAdminLocalSyncezTools.log"
Start-Transcript -Path $transcriptPath

# Setup
Write-Host -ForegroundColor green "  Zed says: Let's setup the OSD environment"
#Set-ExecutionPolicy RemoteSigned -Force # Was unable to set that
Install-Module OSD -Force
Import-Module OSD -Force

# Ask user for the computer name and local admins password
Write-Host -ForegroundColor green "   Zed Needs to know the computer name and password"
$computerName = Read-Host "Enter the computer name"
$localAdminPassword = Read-Host "Enter the local admin password (check in 1P)" -AsSecureString

# Put our autoUnattend xml template for Local AD OOBE in a variable
Write-Host -ForegroundColor green " Zed says: I will put our autoUnattend xml template for Local AD OOBE (no online useraccount page) in a variable"
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
                <OEMInformation>
                    <SupportProvider>ez Networking Support</SupportProvider>
                    <Manufacturer>HP</Manufacturer>
                    <SupportHours>8/5 to 24/7 depending on contract</SupportHours>
                    <SupportPhone>+32 3 376 14 25</SupportPhone>
                    <SupportURL>http://www.ez.be</SupportURL>
                </OEMInformation>            
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
                        <Description>ezAdmin Local | ez Networking</Description>
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
                    <Description>Install Chocolatey</Description>
                    <Order>1</Order>
                    <CommandLine>powershell.exe -NoProfile -ExecutionPolicy unrestricted -Command &quot;iex ((new-object net.webclient).DownloadString(&apos;https://chocolatey.org/install.ps1&apos;))&quot;</CommandLine>
                    <RequiresUserInput>false</RequiresUserInput>
                </SynchronousCommand>
                <SynchronousCommand wcm:action="add">
                    <Order>2</Order>
                    <Description>Install TreeSize via Chocolatey</Description>
                    <RequiresUserInput>false</RequiresUserInput>
                    <CommandLine>powershell.exe -NoProfile -ExecutionPolicy unrestricted -Command &quot;choco install tree-size-free -y&quot;</CommandLine>
                </SynchronousCommand>
                <SynchronousCommand wcm:action="add">
                    <Order>3</Order>
                    <RequiresUserInput>false</RequiresUserInput>
                    <CommandLine>cmd /C wmic useraccount where name="ezAdminLocal" set PasswordExpires=false</CommandLine>
                    <Description>Password Never Expires</Description>
                </SynchronousCommand>
                <SynchronousCommand wcm:action="add">
                    <Description>Join Domain at first login</Description>
                    <Order>4</Order>
                    <CommandLine>C:\Windows\System32\WindowsPowerShell\v1.0\powershell.exe -ExecutionPolicy Bypass -File c:\ezNetworking\Automation\ezCloudDeploy\Scripts\JoinDomainAtFirstLogin.ps1</CommandLine>
                    <RequiresUserInput>false</RequiresUserInput>
                </SynchronousCommand>
            </FirstLogonCommands>
            <TimeZone>Romance Standard Time</TimeZone>
        </component>
    </settings>
</unattend>
"@
Write-Host -ForegroundColor green " Zed says: I have a nice unattend.xml template for you: $unattendXml"

# Write the updated unattend.xml file to c:\ezNetworking\Automation\ezCloudDeploy\AutoUnattend\
Write-Host -ForegroundColor green " Zed says: Writing the unattend.xml file to c:\ezNetworking\Automation\ezCloudDeploy\AutoUnattend\"
$unattendPath = "C:\ezNetworking\Automation\ezCloudDeploy\AutoUnattend\LocalAdUnattend.xml"
try {
    $unattendXml | Out-File -FilePath $unattendPath -Encoding UTF8
    
}
catch {
    Write-Error " Zed says: $unattendPath already exists or you don't have the rights to create it"
}
# Download the JoinDomainAtFirstLogin.ps1 script from github
Write-Host -ForegroundColor green " Zed says: downloading the JoinDomainAtFirstLogin.ps1 script from ezCloudDeploy github..."
try {
    $JoinDomainAtFirstLoginScript = Invoke-WebRequest -Uri "https://raw.githubusercontent.com/ezNetworking/ezCloudDeploy/master/non_ezCloudDeployGuiScripts/101_Windows_PostOOBE_JoinDomainAtFirstLogin.ps1" -UseBasicParsing 
    
}
catch {
    Write-Error " Zed says: I was unable to download the JoinDomainAtFirstLogin.ps1 script from github"
}
# Save the script to c:\ezNetworking\Automation\ezCloudDeploy\Scripts\JoinDomainAtFirstLogin.ps1
Write-Host -ForegroundColor green " Zed says: Saving the script to c:\ezNetworking\Automation\ezCloudDeploy\Scripts\JoinDomainAtFirstLogin.ps1"
$JoinDomainAtFirstLoginScriptPath = "c:\ezNetworking\Automation\ezCloudDeploy\Scripts\JoinDomainAtFirstLogin.ps1"
try {
    $JoinDomainAtFirstLoginScript | Out-File -FilePath $JoinDomainAtFirstLoginScriptPath -Encoding UTF8
    
}
catch {
    Write-Error " Zed says: $JoinDomainAtFirstLoginScriptPath already exists or you don't have the rights to create it"
}
# Configure the script to run at first logon
Write-Host -ForegroundColor green " Zed says: I already configured the script to run at first logon in the unattend.xml file"

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
