# Check if folder exist, if not create them
Write-Host "  Zed says: Let's check if the folders exist, if not create them"
$folders = "c:\ezNetworking\Automations\ezCloudDeploy\AutoUntattend\", "c:\ezNetworking\Automations\Logs", "c:\ezNetworking\Automations\ezCloudDeploy\Scripts"
foreach ($folder in $folders) {
    if (!(Test-Path $folder)) {
        New-Item -ItemType Directory -Path $folder | Out-Null
    }
}

# Start transcript to c:\ezNetworking\Automations\ezCloudDeploy\Logs\ezCloudDeploy1WinPePostOSPrepLocalADezAdminLocalSyncezTools.log
Write-Host "  Zed says: Let's start the transcript to c:\ezNetworking\Automations\Logs\ezCloudDeploy1WinPePostOSPrepLocalADezAdminLocalSyncezTools.log"
$transcriptPath = "c:\ezNetworking\Automations\Logs\ezCloudDeploy1WinPePostOSPrepLocalADezAdminLocalSyncezTools.log"
Start-Transcript -Path $transcriptPath

# Setup
Write-Host "  Zed says: Let's setup the environment"
Set-ExecutionPolicy RemoteSigned -Force
Install-Module OSD -Force
Import-Module OSD -Force

# Ask user for the computer name
Write-Host "   Zed Needs to know the computer name"
$computerName = Read-Host "Enter the computer name"

# Put our autoUnattend xml template for Local AD OOBE in a variable
Write-Host " Zed says: I will put our autoUnattend xml template for Local AD OOBE (no online useraccount page) in a variable"
$unattendXml = @"
<?xml version="1.0" encoding="utf-8"?>
<unattend xmlns="urn:schemas-microsoft-com:unattend">
  <settings pass="oobeSystem">
    <component name="Microsoft-Windows-International-Core" publicKeyToken="31bf3856ad364e35" language="neutral" versionScope="nonSxS">
      <InputLocale>0813:00000813</InputLocale>
      <SystemLocale>nl-BE</SystemLocale>
      <UILanguage>en-US</UILanguage>
      <UILanguageFallback>en-US</UILanguageFallback>
      <UserLocale>nl-BE</UserLocale>
      <UILanguage_DefaultUser>en-US</UILanguage_DefaultUser>
      <UILanguageFallback_DefaultUser>en-US</UILanguageFallback_DefaultUser>
      <UserLocale_DefaultUser>nl-BE</UserLocale_DefaultUser>
      <InputLocale_DefaultUser>0813:00000813</InputLocale_DefaultUser>
      <SystemLocale_DefaultUser>nl-BE</SystemLocale_DefaultUser>
      <TimeZone>Central European Standard Time</TimeZone>
    </component>
    <component name="Microsoft-Windows-Shell-Setup" publicKeyToken="31bf3856ad364e35" language="neutral" versionScope="nonSxS">
      <InputLocale>0813:00000813</InputLocale>
      <SystemLocale>nl-BE</SystemLocale>
      <UILanguage>nl-BE</UILanguage>
      <UILanguageFallback>en-US</UILanguageFallback>
      <UserLocale>nl-BES</UserLocale>
      <UILanguage_DefaultUser>en-US</UILanguage_DefaultUser>
      <UILanguageFallback_DefaultUser>en-US</UILanguageFallback_DefaultUser>
      <UserLocale_DefaultUser>nl-BE</UserLocale_DefaultUser>
      <InputLocale_DefaultUser>0813:00000813</InputLocale_DefaultUser>
      <SystemLocale_DefaultUser>nl-BES</SystemLocale_DefaultUser>
      <TimeZone>Central European Standard Time</TimeZone>
      <OOBE>
        <OEMInformation>
            <SupportProvider>ez Networking Support</SupportProvider>
            <Manufacturer>HP</Manufacturer>
            <SupportHours>8/5 to 24/7 depending on contract</SupportHours>
            <SupportPhone>+32 3 376 14 25</SupportPhone>
            <SupportURL>http://www.ez.be</SupportURL>
        </OEMInformation>
        <HideEULAPage>true</HideEULAPage>
        <HideOEMRegistrationScreen>true</HideOEMRegistrationScreen>
        <HideOnlineAccountScreens>true</HideOnlineAccountScreens>
        <HideWirelessSetupInOOBE>true</HideWirelessSetupInOOBE>
        <ProtectYourPC>3</ProtectYourPC>
      </OOBE>
      <UserAccounts>
        <AdministratorPassword>
          <Value>MakesYourNetWork!</Value>
          <PlainText>true</PlainText>
        </AdministratorPassword>
        <LocalAccounts>
          <LocalAccount wcm:action="add">
            <Password>
              <Value>MakesYourNetWork!</Value>
              <PlainText>true</PlainText>
            </Password>
            <DisplayName>ezAdminLocal | ez Networking</DisplayName>
            <Group>Administrators</Group>
            <Name>ezAdminLocal</Name>
          </LocalAccount>
        </LocalAccounts>
      </UserAccounts>
    </component>
  </settings>
</unattend>
"@
Write-Host " Zed says: I have a nice unattend.xml template for you: $unattendXml"

# Replace the computername in the unattend.xml file
Write-Host " Zed says: I will replace the computername in the unattend.xml file"
(Get-Content $unattendXml) -replace "COMPUTERNAME", $computerName | Out-File $unattendPath

# Write the unattend.xml file to c:\ezNetworking\Automations\ezCloudDeploy\AutoUnattend\
Write-Host " Zed says: will write the unattend.xml file to c:\ezNetworking\Automations\ezCloudDeploy\AutoUnattend\"
$unattendPath = "C:\ezNetworking\Automations\ezCloudDeploy\Autountattend\unattend.xml"
$unattendXml | Out-File -FilePath $unattendPath -Encoding UTF8

# Download the JoinDomainAtFirstLogin.ps1 script from github
Write-Host " Zed says: I will download the JoinDomainAtFirstLogin.ps1 script from github"
$JoinDomainAtFirstLogin = Invoke-WebRequest -Uri "https://raw.githubusercontent.com/ezNetworking/ezCloudDeploy/master/Scripts/JoinDomainAtFirstLogin.ps1" -UseBasicParsing 

# Save the script to c:\ezNetworking\Automations\ezCloudDeploy\Scripts\JoinDomainAtFirstLogin.ps1
Write-Host " Zed says: I will save the script to c:\ezNetworking\Automations\ezCloudDeploy\Scripts\JoinDomainAtFirstLogin.ps1"
$JoinDomainAtFirstLoginScriptPath = "c:\ezNetworking\Automations\ezCloudDeploy\Scripts\JoinDomainAtFirstLogin.ps1"
$JoinDomainAtFirstLogin | Out-File -FilePath $JoinDomainAtFirstLoginScriptPath -Encoding UTF8

# Configure the script to run at first logon
Write-Host " Zed says: I will configure the script to run at first logon"


# Add script to the scripts folder
Write-Host " Zed says: I will add the script to the scripts folder then set it to run at first logon"
$JoinDomainAtFirstLoginScriptPath = "c:\ezNetworking\Automations\ezCloudDeploy\Scripts\JoinDomainAtFirstLogin.ps1"
$JoinDomainAtFirstLogin | Out-File -FilePath $JoinDomainAtFirstLoginScriptPath -Encoding UTF8



# Start OOBEDeploy using the unattend.xml file created in c:\ezNetworking\Automations\ezCloudDeploy\AutoUnattend\ and remove the following apps: CommunicationsApps,OfficeHub,People,Skype,Solitaire,Xbox,ZuneMusic,ZuneVideo
Write-Host "  Zed says: Let's start OOBEDeploy using the unattend.xml file created in c:\ezNetworking\Automations\ezCloudDeploy\AutoUnattend\ and remove the following apps: CommunicationsApps,OfficeHub,People,Skype,Solitaire,Xbox,ZuneMusic,ZuneVideo"
Start-OOBEDeploy Start-OOBEDeploy -CustomProfile $unattendPath -RemoveAppx CommunicationsApps,OfficeHub,People,Skype,Solitaire,Xbox,ZuneMusic,ZuneVideo

#And stop the trancsript.
Write-Host "  Zed says: And stopping the trancsript. Check out the log file at $transcriptPath and also check if the settings applied and the apps are removed."
Stop-Transcript
