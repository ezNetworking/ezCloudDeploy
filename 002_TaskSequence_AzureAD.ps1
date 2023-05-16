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

Write-Host -ForegroundColor Cyan "========================================================================================="
Write-Host -ForegroundColor Cyan "                                2. OS Install"
Write-Host -ForegroundColor Cyan "========================================================================================="
Write-Host -ForegroundColor Cyan ""

# Block the script from running on Windows pre w10 and PowerShell pre v5
Block-WinOS
Block-WindowsVersionNe10
Block-PowerShellVersionLt5

#Install-Module OSD -Force
Write-Host -ForegroundColor White "  Z: Installing Modules and starting OS Deploy"
Set-ExecutionPolicy -ExecutionPolicy Bypass -Scope Process -Force
Import-Module OSD -Force

$Params = @{
    OSVersion = "Windows 11"
    OSBuild = "22H2"
    OSEdition = "Pro"
    OSLanguage = "en-us"
    OSLicense = "Retail"
    SkipAutopilot = $true
    SkipODT = $true
    Screenshot = $true 
    Restart = $false   
}
Start-OSDCloud @Params | ECHO Y 

Write-Host -ForegroundColor Cyan "========================================================================================="
Write-Host -ForegroundColor Cyan "                                Section: 3. Specialize"
Write-Host -ForegroundColor Cyan "========================================================================================="
Write-Host -ForegroundColor Cyan ""

Write-Host -ForegroundColor White "  Z: Let's check if the folders exist, if not create them"
$folders = "c:\Windows\System32\Oobe\Info", "c:\windows\System32\Oobe\Info\Default", "c:\ezNetworking\Automation\ezCloudDeploy\AutoUnattend", "c:\ezNetworking\Automation\Logs", "c:\ezNetworking\Automation\ezCloudDeploy\Scripts", "C:\ProgramData\OSDeploy"
foreach ($folder in $folders) {
    if (!(Test-Path $folder)) {
        try {
            New-Item -ItemType Directory -Path $folder | Out-Null    
        }
        catch {
            Write-Error "  Z: $folder already exists or you don't have the rights to create it"
        }    }
    else {
        Write-Host -ForegroundColor Gray "  Z: $folder already exists"
    }
}

# Start transcript
$transcriptPath = "c:\ezNetworking\Automation\Logs\ezCloudDeploy_TaskSequence_AzureAD.log"
Start-Transcript -Path $transcriptPath

# Create a json config file with the ezRmmId
Write-Host -ForegroundColor White "  Z: Creating a json config file with the ezRmmId"
$ezClientConfig = @{
    ezRmmId = $ezRmmId
}
$ezClientConfig | ConvertTo-Json | Out-File -FilePath "C:\ezNetworking\Automation\ezCloudDeploy\ezClientConfig.json" -Encoding UTF8

# Download the DefaultAppsAndOnboard.ps1 script from github
Write-Host -ForegroundColor White " Z: Downloading the DefaultAppsAndOnboardScript.ps1 script from ezCloudDeploy."
try {
    $DefaultAppsAndOnboardResponse = Invoke-WebRequest -Uri "https://raw.githubusercontent.com/ezNetworking/ezCloudDeploy/master/non_ezCloudDeployGuiScripts/111_Windows_PostOS_DefaultAppsAndOnboard.ps1" -UseBasicParsing 
    $DefaultAppsAndOnboardScript = $DefaultAppsAndOnboardResponse.content
    Write-Host -ForegroundColor Gray  "  Z: Saving the Onboard script to c:\ezNetworking\Automation\ezCloudDeploy\Scripts\DefaultAppsAndOnboard.ps1"
    $DefaultAppsAndOnboardScriptPath = "c:\ezNetworking\Automation\ezCloudDeploy\Scripts\DefaultAppsAndOnboard.ps1"
    $DefaultAppsAndOnboardScript | Out-File -FilePath $DefaultAppsAndOnboardScriptPath -Encoding UTF8
}
catch {
    Write-Error  "  Z: I was unable to download the DefaultAppsAndOnboardScript script."
}

Write-Host -ForegroundColor Cyan "========================================================================================="
Write-Host -ForegroundColor Cyan "                                Section 4. OOBE prep"
Write-Host -ForegroundColor Cyan "========================================================================================="
Write-Host ""

# Put our OOBE xml template for Local AD OOBE in a variable
Write-Host -ForegroundColor White  "  Z: Updating our OOBE xml for Region, Language, Keyboard, Timezone, etc."
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

Write-Host -ForegroundColor White  "  Z: Writing the OOBE.xml file to c:\Windows\System32\Oobe\Info\Oobe.xml"
$OobeXMLPath = "c:\Windows\System32\Oobe\Info\Oobe.xml"
try {
    $OobeXml | Out-File -FilePath $OobeXMLPath -Encoding UTF8
    
}
catch {
    Write-Error  "  Z: $OobeXMLPath already exists or you don't have the rights to create it"
}


Write-Host -ForegroundColor White "  Z: Creating shortcusts to the ezCloudDeploy OOBE and AutoPilot scripts"
$SetCommand = @'
@echo off

:: Set the PowerShell Execution Policy
PowerShell -NoL -Com Set-ExecutionPolicy RemoteSigned -Force

:: Add PowerShell Scripts to the Path
set path=%path%;C:\Program Files\WindowsPowerShell\Scripts

:: Open and Minimize a PowerShell instance just in case
start PowerShell -NoL -W Mi

:: Install the latest OSD Module
start "Install-Module OSD" /wait PowerShell -NoL -C Install-Module OSD -Force -Verbose

:: Start-OOBEDeploy
start "Start-OOBEDeploy" PowerShell -NoL -C Start-OOBEDeploy -AddNetFX3 -UpdateDrivers -UpdateWindows -removeappx "CommunicationsApps","OfficeHub","People","Skype","Solitaire","Xbox","ZuneMusic","ZuneVideo"

exit
'@
$SetCommand | Out-File -FilePath "C:\Windows\ezDeploy.cmd" -Encoding ascii -Force


$SetCommand = @'
@echo off

:: Set the PowerShell Execution Policy
PowerShell -NoL -Com Set-ExecutionPolicy RemoteSigned -Force

:: Add PowerShell Scripts to the Path
set path=%path%;C:\Program Files\WindowsPowerShell\Scripts

:: Open and Minimize a PowerShell instance just in case
start PowerShell -NoL -W Mi

:: Install the latest AutopilotOOBE Module
start "Install-Module AutopilotOOBE" /wait PowerShell -NoL -C Install-Module AutopilotOOBE -Force -Verbose

:: Start-AutopilotOOBE
:: There are multiple example lines. Make sure only one is uncommented
:: The next line assumes that you have a configuration saved in C:\ProgramData\OSDeploy\OSDeploy.AutopilotOOBE.json
REM start "Start-AutopilotOOBE" PowerShell -NoL -C Start-AutopilotOOBE
:: The next line is how you would apply a CustomProfile
REM start "Start-AutopilotOOBE" PowerShell -NoL -C Start-AutopilotOOBE -CustomProfile OSDeploy
:: The next line is how you would configure everything from the command line
start "Start-AutopilotOOBE" PowerShell -NoL -C Start-AutopilotOOBE -Title 'ez Cloud Deploy Autopilot Reg' -GroupTag Win-Autopilot01 -Assign

exit
'@
$SetCommand | Out-File -FilePath "C:\Windows\ezAutopilot.cmd" -Encoding ascii -Force

#And stop the transcript.
Stop-Transcript
Write-Host -ForegroundColor Cyan "========================================================================================="
Write-Host -ForegroundColor Cyan "                                Zed's finished!"
Write-Host -ForegroundColor Cyan "========================================================================================="
Write-Host -ForegroundColor Cyan ""

Write-Warning "  ========================================================================================="
Write-Warning "  I'm done mate! If you do not see any errors above you can shut down this PC and deliver"
Write-Warning "  it onsite."
Write-Warning "  First Boot at Customer: The OOBE should be limited to logging in using M365 creds now. "
Write-Warning "  The default apps will be installed, so make sure the network cable is plugged in."
Write-Warning "  If you do see errors, please check the log file at $transcriptPath and fix the errors."
Write-Warning "  ========================================================================================="
#Read-Host -Prompt "            Press any key to shutdown this Computer"

#Stop-Computer -Force

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
002_TaskSequence_AzureAD.ps1 -ComputerName "CUST-SITE-DTxx" -ezRmmId 123456789

This command configures a Windows 10/11 image with Local AD on a computer named "MyComputer01". 
It removes the default apps CommunicationsApps, OfficeHub, People, Skype, Solitaire, Xbox, ZuneMusic, and ZuneVideo.

.NOTES
Author: Jurgen Verhelst | ez Networking | www.ez.be
Modules Used: @Segura: OSD, AutopilotOOBE @
#>
