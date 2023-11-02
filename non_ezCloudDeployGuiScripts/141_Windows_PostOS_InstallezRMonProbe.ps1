<#
.SYNOPSIS
This script downloads, configures, and runs the ezRMon probe on this computer.

.DESCRIPTION
This script performs the following actions:
  - Downloads the probe with a read-only user account.
  - Creates the necessary registry keys.
  - Runs the probe installer with the required parameters.
  - You still need to approve the probe in the mon.ez.be interface.
.AUTHOR
    Jurgen Verhelst | ez Networking (jurgen.verhelst@ez.be)
.NOTES
Version: 1.1
Last Updated: 11/4/23

#>
Write-Host -ForegroundColor Cyan "========================================================================================="
Write-Host -ForegroundColor Cyan "             Install ezRMon Probe - Post OS Deployment"
Write-Host -ForegroundColor Cyan "========================================================================================="
Write-Host -ForegroundColor Cyan ""
Write-Host -ForegroundColor Cyan "========================================================================================="
Start-Transcript -Path "C:\ezNetworking\Automation\Logs\ezCloudDeploy_116_Windows_PostOS_ezRMMAppsAndOnboard.log"
Write-Host -ForegroundColor Cyan "========================================================================================="
Write-Host -ForegroundColor Gray "Z> Downloading ezRMON Probe."


$LogDir = "c:\ezNetworking\Automation\logs"
$LogPath = "$LogDir\ezRMM_ezRMon_1PrepareAndInstall.log"
$ezRMonProbeDownloadPath = "C:\ezNetworking\Automation\Apps\ezRMon"

Write-Host -ForegroundColor Gray "Z> Check if the required directories exist"
$requiredDirs = @($LogDir,$ezRMonProbeDownloadPath)
foreach ($dir in $requiredDirs) {
    if (-not (Test-Path -Path $dir -PathType Container)) {
        New-Item -Path $dir -ItemType Directory -Force | Out-Null
    }
}

Write-Host -ForegroundColor Gray "Z> Starting transcript at $LogPath"           
Start-Transcript $LogPath
Write-Host -ForegroundColor Gray "Z> Download the probe installer"
$ezRMonProbeDownloadURI = "https://mon.ez.be/public/PRTG_Remote_Probe_Installer.exe?filetype=.exe&username=ezDownloadUser&password=ETK2mgt1jmh!ryj-egb"
try {
    [System.Net.ServicePointManager]::SecurityProtocol = 'Tls12'
    Invoke-WebRequest -Uri $ezRMonProbeDownloadURI -OutFile "$ezRMonProbeDownloadPath\ezRMon_Remote_Probe_Installer.exe"
}
catch {
    Write-Warning "Z> Error occurred while downloading the probe installer: $_"
    return
}

Write-Host -ForegroundColor Gray "Z> Create registry keys and set the values"
$registryKeys = @(
    'HKLM:\Software\Wow6432Node\Paessler',
    'HKLM:\Software\Wow6432Node\Paessler\PRTG Network Monitor',
    'HKLM:\Software\Wow6432Node\Paessler\PRTG Network Monitor\Probe'
)
foreach ($key in $registryKeys) {
    if (-not (Test-Path -Path $key)) {
        New-Item -Path $key -Force | Out-Null
    }
}
New-ItemProperty -Path 'HKLM:\Software\Wow6432Node\Paessler\PRTG Network Monitor\Probe' -Name 'Server' -PropertyType 'String' -Value "mon.ez.be" -Force
New-ItemProperty -Path 'HKLM:\Software\Wow6432Node\Paessler\PRTG Network Monitor\Probe' -Name 'isLocalProbe' -PropertyType 'Dword' -Value 0 -Force
New-ItemProperty -Path 'HKLM:\Software\Wow6432Node\Paessler\PRTG Network Monitor\Probe' -Name 'Password' -PropertyType 'Dword' -Value "1151634273" -Force
New-ItemProperty -Path 'HKLM:\Software\Wow6432Node\Paessler\PRTG Network Monitor\Probe' -Name 'ServerPort' -PropertyType 'String' -Value "23560" -Force

Write-Host -ForegroundColor Gray "Z> Run the probe installer"
$probeInstallerPath = "$ezRMonProbeDownloadPath\ezRMon_Remote_Probe_Installer.exe"
try {
    Start-Process -FilePath $probeInstallerPath -ArgumentList '/verysilent', '/norestart', '/nocloseapplications', "/log=($LogDir)\ezRMM_ezRMon_2ProbeInstallerJob.log" -Wait
}
catch {
    Write-Warning "Error occurred while running the probe installer: $_"
    return
}

Write-Host -ForegroundColor Cyan "========================================================================================="
Write-Host -ForegroundColor Cyan "Z> The ezRMon probe installation completed successfully."
Write-Host -ForegroundColor Cyan "Z> You still need to approve the probe in the mon.ez.be interface."
Write-Host -ForegroundColor Cyan "========================================================================================="
Stop-Transcript
Read-Host -Prompt "Press Enter to exit"


