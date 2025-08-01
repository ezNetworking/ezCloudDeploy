<#
.SYNOPSIS
    Securely download support folders via SFTP using Posh​-SSH.

.PARAMETER remoteDirectory
    The remote SFTP directory to mirror, e.g. "/SupportFolderServers".

.DESCRIPTION
    - Runs on the jump server itself (via Start-Process from your onboarding script).
    - Logs everything (via Start-Transcript) into the shared log file.
    - Returns a single output string: DOWNLOAD_SUCCESS or DOWNLOAD_FAILED: <error>.

.NOTES
    Author: Jurgen Verhelst / ez Networking
    Version: 1.6 (updated 2025-08-01)
#>

param(
    [Parameter(Mandatory=$true)]
    [string]$remoteDirectory
)

# Configurable parameters
$logFile = 'C:\ezNetworking\Automation\Logs\ezDownloadSupportFolders.log'
$server = "ftp.driveHQ.com"
$port = 22
$username = "ezpublic"
$password = "MakesYourNetWork"

try {
    # Start transcript logging (append mode)
    if (-not (Test-Path $logFile)) { New-Item $logFile -ItemType File | Out-Null }
    Start-Transcript -Path $logFile -Append

    Write-Host -ForegroundColor Cyan "========================================================================================="
    Write-Host -ForegroundColor Cyan "Z> Download Support Folders from our FTP server."
    Write-Host -ForegroundColor Cyan "========================================================================================="

    Write-Host "Z> [$(Get-Date -Format o)] Starting download from SFTP: $remoteDirectory"

    # Ensure TLS1.2 for SFTP
    [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12

    # Install & import Posh-SSH
    if (-not (Get-Module -ListAvailable -Name 'Posh-SSH')) {
        Write-Host "Z> Installing Posh-SSH..."
        Install-Module -Name 'Posh-SSH' -AllowClobber -Force -ErrorAction Stop
    }
    Import-Module 'Posh-SSH' -ErrorAction Stop

    Write-Host "Z> Posh-SSH Version: $((Get-Module Posh-SSH).Version)"

    # Connect to SFTP server
    $cred = New-Object System.Management.Automation.PSCredential (
        $username, (ConvertTo-SecureString $password -AsPlainText -Force)
    )
    Write-Host "Z> Establishing SFTP session to $server..."
    $sess = New-SFTPSession -ComputerName $server -Credential $cred -Port $port -AcceptKey -ErrorAction Stop

    # Recursive download function
    function Download-Recursive {
        param(
            [Parameter(Mandatory)][int]    $SessionId,
            [Parameter(Mandatory)][string] $RemotePath,
            [Parameter(Mandatory)][string] $LocalPath
        )
        $items = Get-SFTPChildItem -SessionId $SessionId -Path $RemotePath
        Write-Host "Z> Found $($items.Count) entries in $RemotePath"
        foreach ($item in $items) {
            $dest = Join-Path -Path $LocalPath -ChildPath $item.Name
            if ($item.IsDirectory) {
                if (-not (Test-Path $dest)) { New-Item -ItemType Directory -Path $dest | Out-Null }
                Download-Recursive -SessionId $SessionId -RemotePath $item.FullName -LocalPath $dest
            } else {
                Write-Host "Z> → Downloading: $($item.FullName)"
                try {
                    Get-SFTPItem -SessionId $SessionId -Path $item.FullName -Destination $LocalPath -Force | Out-Null
                } catch {
                    throw "Failed to download $($item.FullName): $($_.Exception.Message)"
                }
            }
        }
    }

    Download-Recursive -SessionId $sess.SessionId -RemotePath $remoteDirectory -LocalPath 'C:\ezNetworking'
    Remove-SFTPSession -SessionId $sess.SessionId

    Write-Host "Z> [$(Get-Date -Format o)] DOWNLOAD_SUCCESS"
    Write-Host -ForegroundColor Cyan "========================================================================================="
    Write-Host -ForegroundColor Cyan "Z> Downloading Support Folders from our FTP server completed successfully."
    Write-Host -ForegroundColor Cyan "========================================================================================="

    Stop-Transcript
    exit 0
}
catch {
    $msg = $_.Exception.Message
    Write-Host "Z> [$(Get-Date -Format o)] DOWNLOAD_FAILED: $msg"
    Write-Host -ForegroundColor Red "========================================================================================="
    Write-Host -ForegroundColor Red "Z> Downloading Support Folders from our FTP server failed."
    Write-Host -ForegroundColor Red "========================================================================================="

    Stop-Transcript
    exit 1
}





