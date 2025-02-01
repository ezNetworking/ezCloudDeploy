
Write-Host -ForegroundColor Cyan "========================================================================================="
Write-Host -ForegroundColor Cyan "             Thinclient Deployment Task Sequence (Win11 24H2 Pro en-US Retail)"
Write-Host -ForegroundColor Cyan "========================================================================================="
Write-Host -ForegroundColor Cyan ""

Write-Host -ForegroundColor White "========================================================================================="
Write-Host -ForegroundColor White "                                1. Parameters"
Write-Host -ForegroundColor White "========================================================================================="
Write-Host -ForegroundColor White ""

# Ask user for the computer name and ezRmmId
Write-Host -ForegroundColor Yellow "  Zed Needs to know some stuff:"
$computerName = Read-Host "  Enter the computer name (CUST-SITE-TCxx)"
$ezRmmId = Read-Host "  Enter the ez RMM Customer ID (2548701561)"
$RdsUri = Read-Host "  Enter the customers RDS server or farm URI (ie rdsfarm.customer.cloud)"
$NetBiosName = Read-Host "  Enter the customers NetBios domain name (ie CUSTOMER)"
Write-Host -ForegroundColor Yellow "Z> Thanks! Getting on it now... Sit back for 10min and enjoy a cup of coffee!"
Write-Host -ForegroundColor White ""

Write-Host -ForegroundColor White "========================================================================================="
Write-Host -ForegroundColor White "                                2. OS Install"
Write-Host -ForegroundColor White "========================================================================================="
Write-Host -ForegroundColor White ""

# Block the script from running on Windows pre w10 and PowerShell pre v5
Block-WinOS
Block-WindowsVersionNe10
Block-PowerShellVersionLt5

#Install-Module OSD -Force
Write-Host -ForegroundColor White "Z> Installing Modules and starting OS Deploy"
Set-ExecutionPolicy -ExecutionPolicy Bypass -Scope Process -Force
Import-Module OSD -Force

$Params = @{
    OSVersion = "Windows 11"
    OSBuild = "24H2"
    OSEdition = "Pro"
    OSLanguage = "en-us"
    OSLicense = "Retail"
    SkipAutopilot = $true
    SkipODT = $true
    Screenshot = $false 
    Restart = $false   
    ZTI = $true 
}
Start-OSDCloud @Params

Write-Host -ForegroundColor Gray "========================================================================================="
# Start transcript
$transcriptPath = "c:\ezNetworking\Automation\Logs\ezCloudDeploy_TaskSequence_Thinclient.log"
Start-Transcript -Path $transcriptPath
Write-Host -ForegroundColor Gray "========================================================================================="
Write-Host ""

#region Specialize
Write-Host -ForegroundColor White "========================================================================================="
Write-Host -ForegroundColor White "                                Section: 3. Specialize"
Write-Host -ForegroundColor White "========================================================================================="
Write-Host -ForegroundColor Cyan ""
Write-Host -ForegroundColor Gray "========================================================================================="

Write-Host -ForegroundColor White "Z> Let's check if the folders exist, if not create them"
$folders = "c:\ezNetworking\Automation\ezCloudDeploy\AutoUnattend", "c:\ezNetworking\Automation\Logs", "c:\ezNetworking\Automation\ezCloudDeploy\Scripts", "C:\ProgramData\OSDeploy"
foreach ($folder in $folders) {
    if (!(Test-Path $folder)) {
        try {
            New-Item -ItemType Directory -Path $folder | Out-Null    
        }
        catch {
            Write-Error "Z> $folder already exists or you don't have the rights to create it"
        }    }
    else {
        Write-Host -ForegroundColor Gray "Z> $folder already exists"
    }
}

# Create a json config file with the ezRmmId
Write-Host -ForegroundColor Gray "========================================================================================="
Write-Host -ForegroundColor White "Z> Creating a json client config file (ezRmmId, RDP URI)"
$ezClientConfig = @"
{
    "TaskSeqType": "Workgroup",
    "ezRmmId": "$($ezRmmId)",
    "custRdsUri": "$($RdsUri)",
    "custNetBiosName": "$($NetBiosName)"
}
"@
$ezClientConfig | Out-File -FilePath "C:\ezNetworking\Automation\ezCloudDeploy\ezClientConfig.json" -Encoding UTF8
Write-Host -ForegroundColor Gray "========================================================================================="

# Download the DefaultAppsAndOnboard.ps1 script from github
Write-Host -ForegroundColor Gray "========================================================================================="
Write-Host -ForegroundColor Gray "Z> Downloading the DefaultAppsAndOnboardScript.ps1 script from ezCloudDeploy."
try {
    $DefaultAppsAndOnboardResponse = Invoke-WebRequest -Uri "https://raw.githubusercontent.com/ezNetworking/ezCloudDeploy/master/non_ezCloudDeployGuiScripts/113_Windows_PostOS_ThinClientCustomisations.ps1" -UseBasicParsing 
    $DefaultAppsAndOnboardScript = $DefaultAppsAndOnboardResponse.content
    Write-Host -ForegroundColor Gray "Z> Saving the Onboard script to c:\ezNetworking\Automation\ezCloudDeploy\Scripts\DefaultAppsAndOnboard.ps1"
    $DefaultAppsAndOnboardScriptPath = "c:\ezNetworking\Automation\ezCloudDeploy\Scripts\DefaultAppsAndOnboard.ps1"
    $DefaultAppsAndOnboardScript | Out-File -FilePath $DefaultAppsAndOnboardScriptPath -Encoding UTF8
}
catch {
    Write-Error " Z> I was unable to download the DefaultAppsAndOnboardScript script."
}


# Put our autoUnattend xml template for Thinclient OOBE in a variable
Write-Host -ForegroundColor White "Z> Updating our Unattend xml for Thinclient OOBE (no online useraccount page)"
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
            <UserLocale>en-US</UserLocale>
        </component>
    </settings>
    <settings pass="specialize">
        <component name="Microsoft-Windows-International-Core" processorArchitecture="amd64" publicKeyToken="31bf3856ad364e35" language="neutral" versionScope="nonSxS" xmlns:wcm="http://schemas.microsoft.com/WMIConfig/2002/State" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance">
            <InputLocale>0813:00000813</InputLocale>
            <SystemLocale>en-US</SystemLocale>
            <UILanguage>en-US</UILanguage>
            <UILanguageFallback>en-US</UILanguageFallback>
            <UserLocale>en-US</UserLocale>
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
                    <CommandLine>cmd /C wmic useraccount where name='ezAdminLocal' set PasswordExpires=false</CommandLine>
                    <Description>Password Never Expires</Description>
                </SynchronousCommand>
            </FirstLogonCommands>
            <TimeZone>Romance Standard Time</TimeZone>
        </component>
    </settings>
</unattend>
"@

# Write the updated unattend.xml file to c:\ezNetworking\Automation\ezCloudDeploy\AutoUnattend\
Write-Host -ForegroundColor White "Z> Writing the unattend.xml file to c:\ezNetworking\Automation\ezCloudDeploy\AutoUnattend\"
write-host -ForegroundColor Gray "$unattendXml"
$unattendPath = "C:\ezNetworking\Automation\ezCloudDeploy\AutoUnattend\ThinclientUnattend.xml"
try {
    $unattendXml | Out-File -FilePath $unattendPath -Encoding UTF8
    
}
catch {
    Write-Error "Z>$unattendPath already exists or you don't have the rights to create it"
}

# Set the unattend.xml file in the offline registry
Write-Host -ForegroundColor Gray "========================================================================================="
Write-Host -ForegroundColor Gray " Z> Setting the unattend.xml file in the offline registry"
reg load HKLM\TempSYSTEM "C:\Windows\System32\Config\SYSTEM"
reg add HKLM\TempSYSTEM\Setup /v UnattendFile /d $unattendPath /f
reg unload HKLM\TempSYSTEM
#endregion

Write-Host -ForegroundColor Gray "========================================================================================="
Write-Host ""
Write-Host -ForegroundColor White "========================================================================================="
Write-Host -ForegroundColor White "                                Section 4. OOBE prep"
Write-Host -ForegroundColor White "========================================================================================="
Write-Host -ForegroundColor Gray "Z> Nice! No OOBE prep to do."





Write-Host -ForegroundColor White "========================================================================================="
Write-Host -ForegroundColor White "                                Zed's finished!"
Write-Host -ForegroundColor White "========================================================================================="
Write-Host -ForegroundColor White ""

Write-Warning "  ========================================================================================="
Write-Warning "  I'm done mate! If you don't see any errors above you can reboot the pc and change the"
Write-Warning "  Admin Password."
Write-Warning "  the default apps will be installed, so make sure the network cable is plugged in.  "
Write-Warning "  ========================================================================================="
Write-Host " "
Write-Warning "  If you do see errors, please check the log file at "
write-warning "  $transcriptPath."
Write-Host " "

Write-Host -ForegroundColor Cyan "========================================================================================="
Write-Host "Restarting this computer in 30s, press CTRL+C to abort"
Write-Host -ForegroundColor Cyan "========================================================================================="
Start-Sleep -Seconds 30
Write-Host -ForegroundColor Yellow "Restarting the computer..."
Restart-Computer -Force
#And stop the transcript.
Stop-Transcript
<#
.SYNOPSIS
Configures a desktop as a Thin Client, removes specified default apps 
and creates shortcuts to the RDS Farm.

.DESCRIPTION
This script checks if the required folders exist, creates them if they don't, sets up the environment, 
prompts the user to input a computer name, generates an unattend.xml file to customize the Windows installation 
for Thinclient usage, creates an RDP file, saves it in the correct folder, 
configures the unattend.xml file to configure users, OOBE, scripts and starts OOBEDeploy with the customized unattend.xml file, 
and removes specified default apps. It also creates a transcript of the deployment process.

.INPUTS
This script prompts the user to input the computer name.

.EXAMPLE
002_TaskSequence_Thinclient.ps1 -ComputerName "CUST-SITE-TCxx" -ezRmmId 123456789 -ezRdsUri "Farm01.cust.cloud"

This command configures a Windows 11 22H2 Pro image with Thinclient on a computer named "MyComputer01" and loads 
an unattend.XML for Users config, region and KBD settings, first run commands, and domain join at first login.
It installs the ez RMM tool and removes the default apps CommunicationsApps, OfficeHub, People, Skype, Solitaire,
Xbox, ZuneMusic, and ZuneVideo.

.NOTES
Author: Jurgen Verhelst | ez Networking | www.ez.be
Modules Used: @Segura: OSD
#>
