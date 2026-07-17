# EasySignage Windows Player Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Make the post-OS DigiSign stage install and autostart EasySignage, while removing the final RDP remnants from both installation stages.

**Architecture:** Script 007 remains the OSDCloud entry point and stages script 142. Script 142 downloads and extracts the vendor's portable package, validates its required files, and registers a user-logon scheduled task that invokes the vendor `autostart.bat`.

**Tech Stack:** Windows PowerShell 5.1, `Invoke-WebRequest`, `Expand-Archive`, Windows ScheduledTasks cmdlets.

## Global Constraints

- Install EasySignage under `C:\ezNetworking\Apps\EasySignage`.
- Name the scheduled task exactly `ezDigitalSignageAutoStart`.
- Trigger the player only when local account `User` logs on.
- Preserve the existing 007-to-142 staging flow, autologin, power settings, policies, support tooling, and reboot.
- Preserve existing uncommitted DigiSign and ezRS edits.

---

### Task 1: Remove stale RDP behavior and wording

**Files:**
- Modify: `007_Win11_ezDigiSign.ps1`
- Modify: `non_ezCloudDeployGuiScripts/142_Windows_PostOS_DigiSignCustomisations.ps1`

**Interfaces:**
- Consumes: script 007's existing download of script 142.
- Produces: an RDP-free DigiSign installation chain.

- [x] **Step 1: Run the failing static check**

```powershell
rg -n -i 'mstsc|\.rdp|CustomerRDS|RDP URI|creates an RDP file|start RDP' 007_Win11_ezDigiSign.ps1 non_ezCloudDeployGuiScripts/142_Windows_PostOS_DigiSignCustomisations.ps1
```

Expected: matches in both files.

- [x] **Step 2: Remove RDP-only declarations and logon task**

Delete `$rdpFilePath`, `$rdpShortcutFilePath`, the `UserLogonScript.ps1` here-string, and its `Register-ScheduledTask` block from script 142. Change script 007's JSON message to `Creating a json client config file (ezRmmId)` and its closing comment to describe DigiSign post-OS configuration without RDP.

- [x] **Step 3: Re-run the static check**

Run the Step 1 command again. Expected: exit code 1 with no matches.

### Task 2: Install and autostart EasySignage

**Files:**
- Modify: `non_ezCloudDeployGuiScripts/142_Windows_PostOS_DigiSignCustomisations.ps1`

**Interfaces:**
- Consumes: the pre-created `C:\ezNetworking\Apps` directory and local account `User`.
- Produces: `C:\ezNetworking\Apps\EasySignage\autostart.bat` and scheduled task `ezDigitalSignageAutoStart`.

- [x] **Step 1: Run the failing integration-text check**

```powershell
$text = Get-Content -Raw non_ezCloudDeployGuiScripts/142_Windows_PostOS_DigiSignCustomisations.ps1
@('easysignage-ds-win64-amd64.exe.zip', 'autostart.bat', 'ezDigitalSignageAutoStart') | ForEach-Object { if ($text -notmatch [regex]::Escape($_)) { throw "Missing $_" } }
```

Expected: throws `Missing easysignage-ds-win64-amd64.exe.zip`.

- [x] **Step 2: Add download, extraction, validation, and task registration**

Add variables for the official URL, install folder, ZIP, batch file, and executable. Create the folder, download with `Invoke-WebRequest -UseBasicParsing -ErrorAction Stop`, clear old package files before `Expand-Archive -Force`, require `autostart.bat`, `conf.txt`, and `easysignage-ds-win64.exe`, remove the ZIP, then register `ezDigitalSignageAutoStart` with an `AtLogOn -User 'User'` trigger. Use `cmd.exe /c` with the batch file as action and set `WorkingDirectory` to the install folder. Wrap this block in `try/catch`; log success, and rethrow on failure.

- [x] **Step 3: Re-run the integration-text check**

Run the Step 1 command again. Expected: no output and exit code 0.

- [x] **Step 4: Parse both PowerShell scripts**

```powershell
@('007_Win11_ezDigiSign.ps1','non_ezCloudDeployGuiScripts/142_Windows_PostOS_DigiSignCustomisations.ps1') | ForEach-Object { $tokens=$null; $errors=$null; [System.Management.Automation.Language.Parser]::ParseFile((Resolve-Path $_), [ref]$tokens, [ref]$errors) | Out-Null; if ($errors) { $errors | Out-String | Write-Error } }
```

Expected: no parser errors.

- [x] **Step 5: Review scope**

```powershell
git diff --check
git diff -- 007_Win11_ezDigiSign.ps1 non_ezCloudDeployGuiScripts/142_Windows_PostOS_DigiSignCustomisations.ps1
```

Expected: no whitespace errors; diff contains only stale RDP cleanup and the EasySignage installation/autostart block while retaining the existing user edits.
