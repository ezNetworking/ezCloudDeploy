# EasySignage Windows Player Integration

## Scope

The DigiSign installation consists of two stages: `007_Win11_ezDigiSign.ps1` installs Windows and stages the post-OS script, while `non_ezCloudDeployGuiScripts/142_Windows_PostOS_DigiSignCustomisations.ps1` configures the installed system. Update this chain so a deployed DigiSign computer downloads and automatically starts the official EasySignage Windows player. Remove the remaining RDP-specific setup and wording from both stages. Preserve the user's existing rename from `007_Win11_DigiSign.ps1` to `007_Win11_ezDigiSign.ps1`, removal of obsolete RDP desktop customisations, and disabled ezRS installation.

## Installation

- Download the official 64-bit ZIP from `https://download.easysignage.com/easysignage-ds-win64-amd64.exe.zip?utm_source=organic`.
- Store the download temporarily under `C:\ezNetworking\Apps\EasySignage`.
- Extract the complete archive into that folder, keeping `easysignage-ds-win64.exe`, `conf.txt`, and `autostart.bat` together.
- Remove the ZIP after successful extraction.
- Use explicit logging and a terminating error path for download or extraction failures, so the script does not report a successful player setup when required files are absent.
- Make repeated deployment safe by creating the folder when needed and overwriting the extracted package files.

## Automatic Start

- Register a scheduled task named `ezDigitalSignageAutoStart`.
- Trigger it when the local DigiSign account `User` logs on.
- Run the vendor-provided `autostart.bat` from the EasySignage folder with that folder as its working directory.
- Replace an existing task of the same name when the deployment script is rerun.
- Do not launch the player during deployment. The first launch occurs after reboot and autologin, allowing the device hash to appear in the interactive `User` session.

## RDP Cleanup

Remove all remaining RDP-only elements from this script:

- RDP file and shortcut path variables.
- Generation of `UserLogonScript.ps1`.
- The scheduled task that launches `mstsc.exe`.
- Messages or comments that describe RDP startup.

Also update stale RDP wording in `007_Win11_ezDigiSign.ps1`, without changing its responsibility as the first installation stage. Its download and staging of script 142 remain the handoff to the EasySignage configuration stage.

## Existing Device Configuration

Keep the current DigiSign account, autologin, power configuration, local policy import, support tooling, and final reboot behavior. The existing monitor, disk, and system sleep time-outs already meet the relevant EasySignage prerequisites.

## Verification

- Parse the updated file with the PowerShell parser and require zero syntax errors.
- Search both installation-stage scripts for remaining `mstsc`, `.rdp`, `CustomerRDS`, stale RDP wording, and RDP logon-task references.
- Confirm the EasySignage URL, required extracted filenames, install folder, and exact scheduled-task name occur in the final script.
- Review the diff to ensure pre-existing user changes and unrelated files remain untouched.
