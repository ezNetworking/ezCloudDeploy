

# Block the script from running on Windows pre w10 and PowerShell pre v5
Block-WinOS
Block-WindowsVersionNe10
Block-PowerShellVersionLt5

# Check if folder exist, if not create them
Write-Host -ForegroundColor green "_______________________________________________________________________"
Write-Host -ForegroundColor green "                    Azure AD Deployment Task Sequence"
Write-Host -ForegroundColor green "_______________________________________________________________________"


#================================================
#   OSDCloud Task Sequence
#   Windows 10 21H1 Pro nl-BE Retail
#   No Autopilot
#   No Office Deployment Tool
#================================================
#   PreOS
#   Install and Import OSD Module
#================================================
#Install-Module OSD -Force
Import-Module OSD -Force
#================================================
#   [OS] Start-OSDCloud with Params
#================================================
$Params = @{
    OSBuild = "21H1"
    OSEdition = "Pro"
    OSLanguage = "en-us"
    OSLicense = "Retail"
    SkipAutopilot = $true
    SkipODT = $true
}
Start-OSDCloud @Params

Write-Host -ForegroundColor green "  Zed says: Let's check if the folders exist, if not create them"
$folders = "c:\programdata\osdeploy", "c:\ezNetworking\Automation\ezCloudDeploy\AutoUnattend\", "c:\ezNetworking\Automation\Logs", "c:\ezNetworking\Automation\ezCloudDeploy\Scripts", "C:\ProgramData\OSDeploy"
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

# Start transcript to c:\ezNetworking\Automation\ezCloudDeploy\Logs\ezCloudDeploy_TaskSequence_AzureAD.log
Write-Host -ForegroundColor green "  Zed says: Let's start the transcript to c:\ezNetworking\Automation\Logs\ezCloudDeploy_TaskSequence_AzureAD.log"
$transcriptPath = "c:\ezNetworking\Automation\Logs\ezCloudDeploy_TaskSequence_AzureAD.log"
Start-Transcript -Path $transcriptPath

#================================================
#   WinPE PostOS Sample
#   AutopilotOOBE Offline Staging
#================================================
Install-Module AutopilotOOBE -Force
Import-Module AutopilotOOBE -Force

$Params = @{
    Title = 'ez Cloud Deploy Autopilot'
    GroupTag = 'Enterprise'
    GroupTagOptions = 'Development','Enterprise'
    Assign = $true
    Run = 'NetworkingWireless'
    Autopilot = $true
}
AutopilotOOBE @Params
#================================================
#   WinPE PostOS Sample
#   OOBEDeploy Offline Staging
#================================================
$Params = @{
    Autopilot = $false
    RemoveAppx = "CommunicationsApps","OfficeHub","People","Skype","Solitaire","Xbox","ZuneMusic","ZuneVideo"
    UpdateDrivers = $true
    UpdateWindows = $true
}
Start-OOBEDeploy @Params
#================================================
#   WinPE PostOS
#   Set OOBEDeploy CMD.ps1
#================================================
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
:: There are multiple example lines. Make sure only one is uncommented
:: The next line assumes that you have a configuration saved in C:\ProgramData\OSDeploy\OSDeploy.OOBEDeploy.json
REM start "Start-OOBEDeploy" PowerShell -NoL -C Start-OOBEDeploy
:: The next line assumes that you do not have a configuration saved in or want to ensure that these are applied
start "Start-OOBEDeploy" PowerShell -NoL -C Start-OOBEDeploy -AddNetFX3 -UpdateDrivers -UpdateWindows -removeappx "CommunicationsApps","OfficeHub","People","Skype","Solitaire","Xbox","ZuneMusic","ZuneVideo"

exit
'@
$SetCommand | Out-File -FilePath "C:\Windows\ezDeploy.cmd" -Encoding ascii -Force
#================================================
#   WinPE PostOS
#   Set AutopilotOOBE CMD.ps1
#================================================
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
#================================================
#   PostOS
#   Restart-Computer
#================================================
Restart-Computer
#And stop the transcript.
Stop-Transcript
Write-Warning "  ____________________________________________________________________________________________________________"
Write-Warning "  Zed says: I'm done mate! If you do not see any errors above you can shut down this PC and deliver it onsite."
Write-Warning "            First Boot at Customer: Once logged in a Domain Join Gui will be displayed and in the background,"
Write-Warning "            the default apps will be installed, so make sure the network cable is plugged in."
Write-Warning "            If you do see errors, please check the log file at $transcriptPath and fix the errors."
Write-Warning "  ____________________________________________________________________________________________________________"
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
Deploy-Windows10AzureAD -ComputerName "MyComputer01"

This command configures a Windows 10/11 image with Local AD on a computer named "MyComputer01". 
It removes the default apps CommunicationsApps, OfficeHub, People, Skype, Solitaire, Xbox, ZuneMusic, and ZuneVideo.

.NOTES
Author: Jurgen Verhelst | ez Networking | www.ez.be
#>
