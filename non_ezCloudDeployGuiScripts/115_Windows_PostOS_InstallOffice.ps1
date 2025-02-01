<#
.SYNOPSIS
This script downloads and runs the Office Deployment Tool, create a config XML if none is specified and installs office with the xml file. 

.DESCRIPTION
This code downloads the Office Deployment Tool from a URL, t, and runs it with certain arguments. It checks if the script is running as an administrator and if the specified download path exists. It also deletes any existing folder at a specified path.

.TODO
Teams MSI= https://teams.microsoft.com/downloads/desktopurl?env=production&plat=windows&arch=x64&managedInstaller=true&download=true
msiexec /i Teams_windows_x64.msi ALLUSERS=1

.PARAMETER $ExcludeApps
Array with apps you do NOT want to install
"Groove","Outlook","OneNote","Access","OneDrive","Publisher","Word","Excel","PowerPoint","Teams","Lync"

.NOTES
Author: Jurgen Verhelst | ez Networking (jurgen.verhelst@ez.be) 
Version: 0.7
Last Updated: 19/2/23

#> 
<# 
.DESCRIPTION 
 Installs the Office 365 suite for Windows using the Office Deployment Tool 
#> 

[CmdletBinding(DefaultParameterSetName = 'XMLFile')]
Param(
  [Parameter(Mandatory=$false)][string]$LogPath = "c:\ezNetworking\Automation\logs\ezRMM_Office365Install.log",
  [Parameter(ParameterSetName = "XMLFile")][ValidateNotNullOrEmpty()][String]$ConfiguratonXMLFile,
  [Parameter(ParameterSetName = "NoXML")][ValidateSet("TRUE","FALSE")]$AcceptEULA = "TRUE",
  [Parameter(ParameterSetName = "NoXML")][ValidateSet("SemiAnnual","Current","Monthly")]$Channel = "Monthly",
  [Parameter(ParameterSetName = "NoXML")][Switch]$DisplayInstall = $False,
  [Parameter(ParameterSetName = "NoXML")][ValidateSet("Groove","Outlook","OneNote","Access","OneDrive","Publisher","Word","Excel","PowerPoint","Teams","Lync")][Array]$ExcludeApps = @("Lync", "Groove"),
  [Parameter(ParameterSetName = "NoXML")][ValidateSet("64","32")]$OfficeArch = "64",
  [Parameter(ParameterSetName = "NoXML")][ValidateSet("O365ProPlusRetail","O365BusinessRetail")]$OfficeEdition = "O365BusinessRetail",
  [Parameter(ParameterSetName = "NoXML")][ValidateSet(0,1)]$SharedComputerLicensing = "0",
  [Parameter(ParameterSetName = "NoXML")][ValidateSet("TRUE","FALSE")]$EnableUpdates = "TRUE",
  [Parameter(ParameterSetName = "NoXML")][String]$LoggingPath = "c:\ezNetworking\Automation\Logs",
  [Parameter(ParameterSetName = "NoXML")][String]$SourcePath,
  [Parameter(ParameterSetName = "NoXML")][ValidateSet("TRUE","FALSE")]$PinItemsToTaskbar = "TRUE",
  [Parameter(ParameterSetName = "NoXML")][Switch]$KeepMSI = $False,
  [Parameter(ParameterSetName = "NoXML")][string]$adDomainNetbiosName =  (gwmi WIN32_ComputerSystem).Domain,
  [Parameter(ParameterSetName = "NoXML")][String]$OfficeInstallDownloadPath = "c:\ezNetworking\Automation\Apps\Office365Install"
)
Write-Host -ForegroundColor Cyan "========================================================================================="
Write-Host -ForegroundColor Cyan "             Install Office 365 - Post OS Deployment"
Write-Host -ForegroundColor Cyan "========================================================================================="
Write-Host -ForegroundColor Cyan ""
Function Generate-XMLFile{
  Write-Host = " Zed says: Generating an XML file"
  If($ExcludeApps){
    $ExcludeApps | ForEach-Object{
      $ExcludeAppsString += "<ExcludeApp ID =`"$_`" />"
    }
  }

  If($OfficeArch){
    $OfficeArchString = "`"$OfficeArch`""
  }

  If($KeepMSI){
    $RemoveMSIString = $Null
  }Else{
    $RemoveMSIString =  "<RemoveMSI />"
  }

  If($Channel){
    $ChannelString = "Channel=`"$Channel`""
  }Else{
    $ChannelString = $Null
  }

  If($SourcePath){
    $SourcePathString = "SourcePath=`"$SourcePath`"" 
  }Else{
    $SourcePathString = $Null
  }

  If($DisplayInstall){
    $SilentInstallString = "Full"
  }Else{
    $SilentInstallString = "None"
  }

  If($LoggingPath){
    $LoggingString = "<Logging Level=`"Standard`" Path=`"$LoggingPath`" />"
  }Else{
    $LoggingString = $Null
  }
  #XML data that will be used for the download/install
  $OfficeXML = [XML]@"
  <Configuration>
    <Add OfficeClientEdition=$OfficeArchString $ChannelString $SourcePathString  >
      <Product ID="$OfficeEdition">
        <Language ID="en-us" />
        <Language ID="nl-nl" />
        $ExcludeAppsString
      </Product>
    </Add>  
    <Property Name="PinIconsToTaskbar" Value="$PinItemsToTaskbar" />
    <Property Name="SharedComputerLicensing" Value="$SharedComputerlicensing" />
    <Display Level="$SilentInstallString" AcceptEULA="$AcceptEULA" />
    <Updates Enabled="$EnableUpdates" />
    $RemoveMSIString
    $LoggingString
    <AppSettings>
        <Setup Name="Company" Value="$adDomainNetbiosName" />
        <User Key="software\microsoft\office\16.0\common\graphics" Name="disablehardwareacceleration" Value="1" Type="REG_DWORD" App="office16" Id="L_DoNotUseHardwareAcceleration" />
        <User Key="software\microsoft\office\16.0\common\graphics" Name="disableanimations" Value="1" Type="REG_DWORD" App="office16" Id="L_DisableAnimations" />
        <User Key="software\microsoft\office\16.0\firstrun" Name="disablemovie" Value="1" Type="REG_DWORD" App="office16" Id="L_DisableMovie" />
        <User Key="software\microsoft\office\16.0\firstrun" Name="bootedrtm" Value="1" Type="REG_DWORD" App="office16" Id="L_DisableOfficeFirstrun" />
        <User Key="software\microsoft\vba\security" Name="trustlegacysignature" Value="1" Type="REG_DWORD" App="office16" Id="L_TrustLegacySignature" />
        <User Key="software\microsoft\office\16.0\access\security\trusted documents" Name="disablenetworktrusteddocuments" Value="0" Type="REG_DWORD" App="access16" Id="L_TurnOffTrustedDocumentsOnTheNetwork" />
        <User Key="software\microsoft\office\16.0\access\security\trusted locations" Name="allownetworklocations" Value="1" Type="REG_DWORD" App="access16" Id="L_AllowTrustedLocationsOnTheNetwork" />
        <User Key="software\microsoft\office\16.0\excel\options" Name="defaultformat" Value="51" Type="REG_DWORD" App="excel16" Id="L_SaveExcelfilesas" />
        <User Key="software\microsoft\office\16.0\outlook\cached mode" Name="cacheothersmail" Value="0" Type="REG_DWORD" App="outlk16" Id="L_CacheOthersMail" />
        <User Key="software\microsoft\office\16.0\outlook\options\calendar" Name="workday" Value="124" Type="REG_DWORD" App="outlk16" Id="L_Workweek" />
        <User Key="software\microsoft\office\16.0\outlook\options\calendar" Name="firstdow" Value="1" Type="REG_DWORD" App="outlk16" Id="L_Firstdayoftheweek" />
        <User Key="software\microsoft\office\16.0\outlook\options\calendar" Name="firstwoy" Value="0" Type="REG_DWORD" App="outlk16" Id="L_Firstweekofyear" />
        <User Key="software\microsoft\office\16.0\outlook\options\calendar" Name="weeknum" Value="1" Type="REG_DWORD" App="outlk16" Id="L_Calendarweeknumbers" />
        <User Key="software\microsoft\office\16.0\outlook\cached mode" Name="enable" Value="1" Type="REG_DWORD" App="outlk16" Id="L_ConfigureCachedExchangeMode" />
        <User Key="software\microsoft\office\16.0\outlook\cached mode" Name="downloadsharedfolders" Value="0" Type="REG_DWORD" App="outlk16" Id="L_Downloadshardnonmailfolders" />
        <User Key="software\microsoft\office\16.0\outlook\cached mode" Name="syncwindowsetting" Value="1" Type="REG_DWORD" App="outlk16" Id="L_CachedExchangeModeSyncSlider" />
        <User Key="software\microsoft\office\16.0\outlook\cached mode" Name="sharedfolderageoutdays" Value="15" Type="REG_DWORD" App="outlk16" Id="L_Synchronizingdatainsharedfolders" />
        <User Key="software\microsoft\office\16.0\powerpoint\options" Name="defaultformat" Value="27" Type="REG_DWORD" App="ppt16" Id="L_SavePowerPointfilesas" />
        <User Key="software\microsoft\office\16.0\word\options" Name="defaultformat" Value="" Type="REG_SZ" App="word16" Id="L_SaveWordfilesas" />
    </AppSettings>
  </Configuration>
"@
  #Save the XML file
  $OfficeXML.Save("$OfficeInstallDownloadPath\OfficeInstall.xml")
  Return "$OfficeInstallDownloadPath\OfficeInstall.xml"
}
<#
 # {Function Test-URL{
  Param(
	$CurrentURL
  )

  Try{
    $HTTPRequest = [System.Net.WebRequest]::Create($CurrentURL)
    $HTTPResponse = $HTTPRequest.GetResponse()
    $HTTPStatus = [Int]$HTTPResponse.StatusCode

    If($HTTPStatus -ne 200) {
      Return $False
    }

    $HTTPResponse.Close()

  }Catch{
	  Return $False
  }	
  Return $True
}
Function Get-ODTURL {
  $ODTDLLink = "https://download.microsoft.com/download/2/7/A/27AF1BE6-DD20-4CB4-B154-EBAB8A7D4A7E/officedeploymenttool_16026-20170.exe"

  If((Test-URL -CurrentURL $ODTDLLink) -eq $False){
	$MSWebPage = (Invoke-WebRequest "https://www.microsoft.com/en-us/download/confirmation.aspx?id=49117" -UseBasicParsing).Content
  
    #Thank you reddit user, u/sizzlr for this addition.
    $MSWebPage | ForEach-Object {
      If ($_ -match "url=(https://.*officedeploymenttool.*\.exe)"){
        $ODTDLLink = $matches[1]}
      }
  }
  Return $ODTDLLink
}:Enter a comment or description}
#>

## Check ezNetworkingdirs OK zijn
If(-Not(Test-Path -path "c:\ezNetworking\Automation\Logs")){New-Item -path "c:\ezNetworking\Automation\Logs"  -ItemType Directory -ErrorAction Stop | Out-Null}
If(-Not(Test-Path $OfficeInstallDownloadPath )){New-Item -Path $OfficeInstallDownloadPath  -ItemType Directory -ErrorAction Stop | Out-Null}

Start-Transcript $LogPath

$VerbosePreference = "Continue"
$ErrorActionPreference = "Stop"

$CurrentPrincipal = New-Object Security.Principal.WindowsPrincipal([Security.Principal.WindowsIdentity]::GetCurrent())
If(!($CurrentPrincipal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator))){
    Write-Warning " Zed says: Script is not running as Administrator"
    Write-Warning " Zed says: Please rerun this script as Administrator."
    return
}

If(!($ConfiguratonXMLFile)){ #If the user didn't specify with -ConfigurationXMLFile param, we make one!
  $ConfiguratonXMLFile = Generate-XMLFile
}Else{
  If(!(Test-Path $ConfiguratonXMLFile)){
    Write-Warning " Zed says: The configuration XML file is not a valid file"
    Write-Warning " Zed says: Please check the path and try again"
    return
  }
}

<#
 # {
#Get the ODT Download link
$ODTInstallLink = Get-ODTURL

#Download the Office Deployment Tool
Write-Host " Zed says: Downloading the Office Deployment Tool..."
Try{
  Invoke-WebRequest -Uri $ODTInstallLink -OutFile "$OfficeInstallDownloadPath\ODTSetup.exe"
}Catch{
  Write-Warning " Zed says: There was an error downloading the Office Deployment Tool."
  Write-Warning " Zed says: Please verify the below link is valid:"
  Write-Warning $ODTInstallLink
  return
}

#Run the Office Deployment Tool setup
Try{
  Write-Host " Zed says: Running the Office Deployment Tool..."
  Start-Process "$OfficeInstallDownloadPath\ODTSetup.exe" -ArgumentList "/quiet /extract:$OfficeInstallDownloadPath" -Wait
}Catch{
  Write-Warning " Zed says: Error running the Office Deployment Tool. The error is below:"
  Write-Warning $_
  return
}
:Enter a comment or description}
#>
#Run the O365 install
Try{
  Write-Host " Zed says: Downloading and installing Office 365"
  #$OfficeInstall = Start-Process "$OfficeInstallDownloadPath\Setup.exe" -ArgumentList "/configure $ConfiguratonXMLFile" -Wait -PassThru
  choco install office365business --params "'/configpath:$ConfiguratonXMLFile'" -y
  If ($LASTEXITCODE -eq 0) {
    Write-Host " Zed says: Office 365 installed successfully via Chocolatey."
  } Else {
    Write-Warning " Zed says: Office 365 installation via Chocolatey failed with exit code $LASTEXITCODE."
    return
  }
}Catch{
  Write-Warning " Zed says: Error running the Office install. The error is below:"
  Write-Warning $_
  return
}

#Check if Office 365 suite was installed correctly.

$RegLocations = @('HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall',
                  'HKLM:\SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall'
                 )

$OfficeInstalled = $False
Foreach ($Key in (Get-ChildItem $RegLocations) ) {
  If($Key.GetValue("DisplayName") -like "*Office 16*") {
    $OfficeVersionInstalled = $Key.GetValue("DisplayName")
    $OfficeInstalled = $True
  }
}

If($OfficeInstalled){
  Write-Host " Zed says: $($OfficeVersionInstalled) installed successfully!"
}Else{
  Write-Warning " Zed says: Office 365 was not detected after the install ran"
}
Stop-Transcript