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

# Copy ezCloudDeploy.exe to c:\ezNetworking\Automation\ezCloudDeploy\Scripts
Write-Host -ForegroundColor green "  Zed says: Copying ezCloudDeploy.exe to c:\ezNetworking\Automation\ezCloudDeploy\Scripts"
Copy-Item -Path "x:\OSDCloud\config\scripts\startup\ezCloudDeploy.exe" -Destination "c:\ezNetworking\Automation\ezCloudDeploy\ezCloudDeploy.exe" -Force

# Ask user for the computer name and ezRmmId
Write-Host -ForegroundColor green "  Zed Needs to know the computer name and ez RMM Customer ID."
$ezRmmId = Read-Host "  Enter the ez RMM Customer ID"

# Create a json config file with the ezRmmId
Write-Host -ForegroundColor green "  Zed says: Creating a json config file with the ezRmmId"
$ezClientConfig = @{
    ezRmmId = $ezRmmId
}
$ezClientConfig | ConvertTo-Json | Out-File -FilePath "C:\ezNetworking\Automation\ezCloudDeploy\ezClientConfig.json" -Encoding UTF8

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

# Use Start-OOBEDeploy to remove the following apps in the later OOBE phase: CommunicationsApps,MicrosoftTeams,OfficeHub,People,Skype,Solitaire,Xbox,ZuneMusic,ZuneVideo"
Write-Host -ForegroundColor green "  Zed says: Use Start-OOBEDeploy to remove apps in the later OOBE phase: "
Write-Host -ForegroundColor green "            CommunicationsApps,MicrosoftTeams,OfficeHub,People,Skype,Solitaire,Xbox,ZuneMusic,ZuneVideo"
Start-OOBEDeploy -RemoveAppx CommunicationsApps,MicrosoftTeams,OfficeHub,People,Skype,Solitaire,Xbox,ZuneMusic,ZuneVideo

#And stop the transcript.
Stop-Transcript
Write-Warning "  ________________________________________________________________________________________"
Write-Warning "  Zed says: I'm done mate! If you do not see any errors above you can reboot this PC "
Write-Warning "            remember to press Shift+F10 in OOBE to open a command prompt, "
Write-Warning "            then ezCloudDeploy.exe select this script and run it."
Write-Warning "            First Boot by Customer: The user can login using his work account,"
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
