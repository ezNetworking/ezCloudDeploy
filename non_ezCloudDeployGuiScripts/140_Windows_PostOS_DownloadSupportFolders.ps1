<#
.SYNOPSIS
This script downloads our Support folders from our FTP server to this computer.

.DESCRIPTION
This script performs the following actions:
  - Login to dl.ez.be with a read-only user account.
  - Download the files and folders from the specified remote directory.
.AUTHOR
    Jurgen Verhelst | ez Networking (jurgen.verhelst@ez.be)
.NOTES
Version: 1.5
Last Updated: 11/7/23

#>

param(
    [Parameter(Mandatory=$true)]
    [string]$remoteDirectory
)

Start-Transcript -Path "C:\ezNetworking\Automation\Logs\ezDownloadSupportFolders.log"

Write-Host -ForegroundColor Cyan "========================================================================================="
Write-Host -ForegroundColor Cyan "             Downloading Support Folders from our FTP server - Post OS Deployment"
Write-Host -ForegroundColor Cyan "========================================================================================="
Write-Host -ForegroundColor Cyan ""
Write-Host -ForegroundColor Gray "Z> Importing FTP Module"
# Import the module
Install-module Transferetto
Import-Module Transferetto

# Enable Tracing
Set-FTPTracing -disable

# Define FTP Server connection details
$server = "ftp.driveHQ.com"
$username = "ezpublic"
$password = "MakesYourNetWork"

# Define local directory
$localDirectory = "C:\ezNetworking"

# Function to handle files and directories
function Process-FTPItems {
    param(
        [FluentFTP.FtpClient]$Client,
        [string]$LocalPath,
        [string]$RemotePath
    )

    # Get the list of remote items (files and directories)
    $remoteItems = Get-FTPList -Client $Client -Path $RemotePath
    
    Write-Host "Z> Found $(($remoteItems).Count) items in the remote path: $RemotePath"

    foreach ($remoteItem in $remoteItems) {
        $localFilePath = Join-Path -Path $LocalPath -ChildPath $remoteItem.Name

        if ($remoteItem.Type -eq "File") {
            # Download the remote file and overwrite the local file if it exists
            Receive-FTPFile -Client $Client -LocalPath $localFilePath -RemotePath $remoteItem.FullName -LocalExists Overwrite
        } elseif ($remoteItem.Type -eq "Directory") {
            # If the item is a directory, recursively call this function
            
            Write-Host "Z> Found directory: $remoteItem.FullName"

            if (!(Test-Path $localFilePath)) {
                
                Write-Host "Z> Local directory doesn't exist. Creating: $localFilePath"
                New-Item -ItemType Directory -Path $localFilePath | Out-Null
            }
            
            Write-Host "Z> Navigating into directory: $localFilePath"
            Process-FTPItems -Client $Client -LocalPath $localFilePath -RemotePath $remoteItem.FullName
        }
    }
}

try {
    # Establish a connection to the FTP server
    
    Write-Host "Z> Connecting to FTP Server at $server..."
    $ftpConnection = Connect-FTP -Server $server -Username $username -Password $password -ErrorAction Stop
    Request-FTPConfiguration 

} catch {
    
    Write-Host "Z> Failed to connect to FTP server at $server. Exiting script..."
    Write-Host "Z> Error details: $_"
}

# Process files and directories

Write-Host "Z> Starting to process files and directories..."
Process-FTPItems -Client $ftpConnection -LocalPath $localDirectory -RemotePath $remoteDirectory

# Close the FTP connection

Write-Host "Z> Disconnecting from FTP server..."
Disconnect-FTP -Client $ftpConnection

Write-Host "Z> Process completed."


Write-Host -ForegroundColor Cyan "========================================================================================="
Write-Host -ForegroundColor Cyan "Z> Downloading Support Folders from our FTP server completed successfully."
Write-Host -ForegroundColor Cyan "========================================================================================="
Stop-Transcript


