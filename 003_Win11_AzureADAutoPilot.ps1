Write-Host -ForegroundColor Cyan "========================================================================================="
Write-Host -ForegroundColor Cyan "             Azure AD Deployment Task Sequence (Win11 22H2 Pro en-US Retail)"
Write-Host -ForegroundColor Cyan "========================================================================================="
Write-Host -ForegroundColor Cyan ""

Write-Host -ForegroundColor Cyan "========================================================================================="
Write-Host -ForegroundColor Cyan "                                1. Parameters"
Write-Host -ForegroundColor Cyan "========================================================================================="
Write-Host -ForegroundColor Cyan ""

# Ask user for the computer name and ezRmmId
Write-Host -ForegroundColor Yellow "  Zed Needs to know the Computer name and ez RMM Customer ID."
$computerName = Read-Host "  Enter the computer name"
$ezRmmId = Read-Host "  Enter the ez RMM Customer ID"
Write-Host -ForegroundColor Cyan ""

#region OS Install
Write-Host -ForegroundColor Cyan "========================================================================================="
Write-Host -ForegroundColor Cyan "                                2. OS Install"
Write-Host -ForegroundColor Cyan "========================================================================================="
Write-Host -ForegroundColor Cyan ""

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
    Screenshot = $true 
    Restart = $false   
    ZTI = $true
}
Start-OSDCloud @Params

Write-Host -ForegroundColor Gray "========================================================================================="
# Start transcript
$transcriptPath = "c:\ezNetworking\Automation\Logs\ezCloudDeploy_TaskSequence_AzureAD.log"
Start-Transcript -Path $transcriptPath
Write-Host -ForegroundColor Gray "========================================================================================="
Write-Host ""
#endregion

#region Specialize
Write-Host -ForegroundColor Cyan "========================================================================================="
Write-Host -ForegroundColor Cyan "                                Section: 3. Specialize"
Write-Host -ForegroundColor Cyan "========================================================================================="
Write-Host -ForegroundColor Cyan ""

Write-Host -ForegroundColor Gray "========================================================================================="
Write-Host -ForegroundColor White "Z> Let's check if the folders exist, if not create them"
$folders = "c:\Windows\System32\Oobe\Info", "c:\windows\System32\Oobe\Info\Default", "c:\ezNetworking\Automation\ezCloudDeploy\AutoUnattend", "c:\ezNetworking\Automation\Logs", "c:\ezNetworking\Automation\ezCloudDeploy\Scripts", "C:\ProgramData\OSDeploy"
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
Write-Host -ForegroundColor White "Z> Creating a json config file with the ezRmmId"
$ezClientConfig = @{
    TaskSeqType = "AzureAD"
    ezRmmId = $ezRmmId
}
$ezClientConfig | ConvertTo-Json | Out-File -FilePath "C:\ezNetworking\Automation\ezCloudDeploy\ezClientConfig.json" -Encoding UTF8
Write-Host -ForegroundColor Gray "========================================================================================="
Write-Host ""

# Download the DefaultAppsAndOnboard.ps1 script from github
Write-Host -ForegroundColor Gray "========================================================================================="
Write-Host -ForegroundColor White "Z> Downloading the DefaultAppsAndOnboardScript.ps1 script from ezCloudDeploy."
try {
    $DefaultAppsAndOnboardResponse = Invoke-WebRequest -Uri "https://raw.githubusercontent.com/ezNetworking/ezCloudDeploy/master/non_ezCloudDeployGuiScripts/111_Windows_PostOS_DefaultAppsAndOnboard.ps1" -UseBasicParsing 
    $DefaultAppsAndOnboardScript = $DefaultAppsAndOnboardResponse.content
    Write-Host -ForegroundColor Gray  "Z> Saving the Onboard script to c:\ezNetworking\Automation\ezCloudDeploy\Scripts\DefaultAppsAndOnboard.ps1"
    $DefaultAppsAndOnboardScriptPath = "c:\ezNetworking\Automation\ezCloudDeploy\Scripts\DefaultAppsAndOnboard.ps1"
    $DefaultAppsAndOnboardScript | Out-File -FilePath $DefaultAppsAndOnboardScriptPath -Encoding UTF8
}
catch {
    Write-Error  "Z> I was unable to download the DefaultAppsAndOnboardScript script."
}
Write-Host -ForegroundColor Gray "========================================================================================="
Write-Host ""
#endregion

#region OOBE
Write-Host -ForegroundColor Cyan "========================================================================================="
Write-Host -ForegroundColor Cyan "                                Section 4. OOBE prep"
Write-Host -ForegroundColor Cyan "========================================================================================="
Write-Host ""

# Put our OOBE xml template for Local AD OOBE in a variable
Write-Host -ForegroundColor Gray "========================================================================================="
Write-Host -ForegroundColor White  "Z> Updating our OOBE xml for Region, Language, Keyboard, Timezone, etc."
$OobeXml = @"
<?xml version="1.0" encoding="utf-8"?>
<FirstExperience>
    <oobe>
        <oem>
            <name>ez Networking</name>
            <computername>$Computername</computername>
        </oem>
        <defaults>
            <language>1033</language>
            <location>21</location>
            <locale>2067</locale>
            <keyboard>0813:00000813</keyboard>
            <timezone>Romance Standard Time</timezone>
            <adjustForDST>true</adjustForDST>
            <hideRegionalSettings>true</hideRegionalSettings>
            <hideTimeAndDate>true</hideTimeAndDate>
        </defaults>
    </oobe>
</FirstExperience>
"@

Write-Host -ForegroundColor White  "Z> Writing the OOBE.xml file to c:\Windows\System32\Oobe\Info\Oobe.xml"
$OobeXMLPath = "c:\Windows\System32\Oobe\Info\Oobe.xml"
try {
    $OobeXml | Out-File -FilePath $OobeXMLPath -Encoding UTF8
    
}
catch {
    Write-Error  "Z> $OobeXMLPath already exists or you don't have the rights to create it"
}

Write-Host -ForegroundColor Gray "========================================================================================="
Write-Host -ForegroundColor White "Z> Creating shortcuts to the ezCloudDeploy OOBE and AutoPilot scripts"
$SetCommand = @'
@echo off

:: Set the PowerShell Execution Policy
PowerShell -NoL -Com Set-ExecutionPolicy RemoteSigned -Force

:: Add PowerShell Scripts to the Path
set path=%path%;C:\Program Files\WindowsPowerShell\Scripts

:: Open and Minimize a PowerShell instance just in case
start PowerShell -NoL -W Mi

:: Set regional settings
start "Set Regional Settings" /wait PowerShell -NoL -C "
    Set-WinSystemLocale nl-BE;
    Set-WinUserLanguageList nl-BE -Force;
    Set-WinDefaultInputMethodOverride -InputTip '0813:00000813';
    Set-TimeZone -Id 'Romance Standard Time';
"

:: Install the latest OSD and AutopilotOOBE Modules
start "Install-Module OSD" /wait PowerShell -NoL -C Install-Module OSD -Force -Verbose
start "Install-Module AutopilotOOBE" /wait PowerShell -NoL -C Install-Module AutopilotOOBE -Force -Verbose

:: Start-AutopilotOOBE
start "Start-AutopilotOOBE" /wait PowerShell -NoL -C Start-AutopilotOOBE -Title 'ez Cloud Deploy Autopilot Reg' -GroupTag Win-Autopilot01 -Assign -AssignedComputerName "{0}"

:: Start ez Onboarding
start "ez Onboarding" PowerShell -NoL -C "c:\ezNetworking\Automation\ezCloudDeploy\Scripts\DefaultAppsAndOnboard.ps1"

exit
'@ -f $computername
$SetCommand
$SetCommand | Out-File -FilePath "C:\Windows\system32\ezOOBE.cmd" -Encoding ascii -Force
Write-Host -ForegroundColor Gray "========================================================================================="

#And stop the transcript.
Stop-Transcript
Write-Host -ForegroundColor Gray "========================================================================================="
Write-Host ""
#endregion

Write-Host -ForegroundColor Cyan "========================================================================================="
Write-Host -ForegroundColor Cyan "                                Zed's finished!"
Write-Host -ForegroundColor Cyan "========================================================================================="
Write-Host -ForegroundColor Cyan ""

Write-Warning "  ========================================================================================="
Write-Warning "  I'm done mate! If you don't see any errors above you can reboot the pc and wait for OOBE."
Write-Warning "  Click OK for Country and KBD. Then press Shift + F10 to open a command prompt and type:"
Write-Warning "                           ezOOBE.cmd "
Write-Warning "  Default apps install, onboard ez RMM, remove MS apps, updates and start the Autopilot GUI."
Write-Warning "  ========================================================================================="
Write-Host " "
Write-Warning "  If you do see errors, please check the log file at $transcriptPath."
Write-Host " "
Write-Host -ForegroundColor Cyan "========================================================================================="
Read-Host -Prompt "            Press any key to restart this Computer"
Write-Host -ForegroundColor Cyan "========================================================================================="
Restart-Computer -Force

<#
.SYNOPSIS
Installs Win11, Configures OOBE Onboarding with Azure Active Directory (AAD), removes unused apps, 
installs base apps and does a Azure Registration GUI.

.PREREQ
Autopilot onboarding must be configured in the Azure Portal 
https://learn.microsoft.com/en-us/autopilot/enrollment-autopilot
1. Greate Group
    Endpoint Manager/Groups/New group
    Create a device group, dynamic devices, call it CUSTCODE-SITECODE-CL_AutoPilotDeploy
    in dynamic click edit in the bottom and then paste (device.devicePhysicalIds -any (_ -eq "[OrderID]:Win-AutoPilot01"))
2. Create an Autopilot profile
    Endpoint Manager/Devices/Enroll Devices/Windows enrollment/Deployment Profiles-Windows Autopilot deployment profiles and create profile
    CUSTCODE Windows Autopilot Deployment
    Convert all targeted devices to Autopilot: No (Default)
    User driven (Default)
    MS instra: joined (Default)
    OS: Default (Default)
    Automaticly configure KBD = Yes (Default)
    Microsoft Software Licene terms = Hide (Default)
    Privacy Settings = Hide (Default)
    Hide change account options = Hide (Default)
    User Account Type = Standard (Default)
    Allow pre-provisioning deployment = Yes (NEED TO CHANGE THIS)
    Apply device name template = No (Default)
    Included groups CUSTCODE-AZ-CL_AutoPilotDeploy

.INPUTS
This script prompts the user to input the computer name and ez RMM ID.

.EXAMPLE
002_TaskSequence_AzureAD.ps1 -ComputerName "CUST-SITE-DTxx" -ezRmmId 123456789

This command configures a Windows 11 22H2 Pro image with Azure AD on a computer named "MyComputer01" and installs the ez RMM tool, 
It loads an OOBE.XML for region and KBD settings and removes the default apps CommunicationsApps, OfficeHub, People, Skype, Solitaire, Xbox, ZuneMusic, and ZuneVideo.
Then sets up OOBE ezOnboard.cmd which you can launch doing Shift + F10 at the OOBE screen.

.NOTES
Author: Jurgen Verhelst | ez Networking | www.ez.be
Modules Used: @Segura: OSD, AutopilotOOBE @WindosNZ: BurntToast
#>
