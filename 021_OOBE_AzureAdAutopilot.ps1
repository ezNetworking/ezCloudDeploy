# Check if folder exist, if not create them
Write-Host -ForegroundColor Cyan "========================================================================================="
Write-Host -ForegroundColor Cyan "                    Azure AD OOBE Script"
Write-Host -ForegroundColor Cyan "========================================================================================="
Write-Host ""
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

# Start transcript to c:\ezNetworking\Automation\ezCloudDeploy\Logs\ezCloudDeploy_021_OOBE_AzureAdAutopilot.log
Write-Host -ForegroundColor green "  Zed says: Let's start the transcript to c:\ezNetworking\Automation\Logs\ezCloudDeploy_021_OOBE_AzureAdAutopilot.log"
$transcriptPath = "c:\ezNetworking\Automation\Logs\ezCloudDeploy_021_OOBE_AzureAdAutopilot.log"
Start-Transcript -Path $transcriptPath

# starting the onboarding script
Write-Host "========================================================================================="
Write-Host -ForegroundColor green "  Zed says: Starting the onboarding script"
#powershell.exe c:\ezNetworking\Automation\ezCloudDeploy\Scripts\DefaultAppsAndOnboard.ps1
Write-Host "========================================================================================="

# Setup OOBE environment
Write-Host "========================================================================================="
Write-Host -ForegroundColor green "  Zed says: Let's setup the and launch ez Deploy OOBE"
#Set-ExecutionPolicy RemoteSigned -Force # Was unable to set that
Install-Module AutopilotOOBE -Force
Install-Module OSD -Force
import-module OSD -Force
Import-Module AutopilotOOBE -Force


Start-OOBEDeploy -UpdateWindows -UpdateDrivers -RemoveAppx CommunicationsApps,MicrosoftTeams,OfficeHub,People,Skype,Solitaire,Xbox,ZuneMusic,ZuneVideo

# Set some variables
$Params = @{
    Title = 'ez Cloud Deploy Autopilot'
    GroupTag = 'Win-AutoPilot01'
    Assign = $true
    Run = 'NetworkingWireless'
}
Start-AutopilotOOBE @Params
Write-Host "========================================================================================="

#And stop the transcript.
Stop-Transcript
Write-Warning "========================================================================================="
Write-Warning "  Zed says: I'm done mate! If you do not see any errors above you can shut down this PC "
Write-Warning "            and deliver it onsite. The user can then login with his Azure AD account."
Write-Warning "            If you do see errors, please check the log file at: " 
Write-Warning "            $transcriptPath "
Write-Warning "========================================================================================="


<#
.SYNOPSIS
TO BE RUN UN OOBE PHASE ONLY. (Press Shift+F10 in OOBE to open a command prompt, then ezCloudDeploy.exe select this script and run it)
This script verifies the existence of necessary directories for the Autopilot OOBE process, creates them if they're absent, 
starts a transcript for logging, sets up the Autopilot environment, initiates Autopilot OOBE, and finally shuts down the computer.

.DESCRIPTION
The script first checks for certain specified directories in the system and creates them if they don't exist. 
It then starts a transcript log of the process for tracking purposes. The script prepares the environment for Azure AD OOBE 
by setting the appropriate execution policy, installing and importing the AutopilotOOBE module. It then initiates the Autopilot OOBE
with specified parameters. Once the process is complete, it stops the transcript and provides user feedback about the procedure. 
Finally, the script shuts down the computer.

.PARAMETERS
None. The script doesn't take any parameters.

.EXAMPLE
.\021_OOBE_AzureAdAutopilot.ps1

This command executes the script, checking and creating required directories, setting up the environment, starting Azure AD OOBE Autopilot, and shutting down the computer after completion.

.NOTES
Author: Jurgen Verhelst | ez Networking | www.ez.be
#>
