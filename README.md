# ez Cloud Deploy Scripts 🚀

**Automated Windows Deployment & Configuration Scripts by ez Networking**

A comprehensive collection of PowerShell scripts designed to streamline Windows 11 deployment, application installation, and system configuration for various deployment scenarios.

## 📋 Overview

ezCloudDeploy provides automated solutions for:
- Windows 10/11 OOBE (Out-of-Box Experience) configuration
- Azure AD and Local AD domain joining
- Application deployment and management
- System customization and optimization
- Remote monitoring tools installation

## 🗂️ Script Collection

### Main Deployment Scripts

| Script | Description | Use Case |
|--------|-------------|----------|
| `002_Win11_LocalAD.ps1` | Windows 11 Local AD deployment | Traditional domain environments |
| `003_Win11_AzureADAutoPilot.ps1` | Windows 11 Azure AD Autopilot | Modern workplace, cloud-first |
| `005_Win11_ThinClient.ps1` | Windows 11 Thin Client setup | VDI/Terminal Server environments |
| `006_Win11_ezRMM_Host.ps1` | Windows 11 with ezRMM monitoring | Managed service provider setups |
| `007_Win11_DigiSign.ps1` | Windows 11 with ez Digital Signage customizations | Digital signature workflows |

### Post-Deployment Configuration Scripts

Located in `non_ezCloudDeployGuiScripts/` directory:

| Script | Purpose |
|--------|---------|
| `101_Windows_PostOOBE_JoinDomainAtFirstLogin.ps1` | GUI for domain joining at first login |
| `111_Windows_PostOS_DefaultAppsAndOnboard.ps1` | Install default applications and onboard to ezRMM |
| `113_Windows_PostOS_ThinClientCustomisations.ps1` | Thin client specific optimizations |
| `114_Windows_PostOS_UninstallOffice.ps1` | Clean Office uninstall utility |
| `115_Windows_PostOS_InstallOffice.ps1` | Office 365 installation |
| `116_Windows_PostOS_ezRMMAppsAndOnboard.ps1` | ezRMM probe setup with monitoring tools |
| `140_Windows_PostOS_DownloadSupportFolders.ps1` | SFTP sync for support files |
| `141_Windows_PostOS_InstallezRMonProbe.ps1` | Install ezRMon monitoring probe |
| `142_Windows_PostOS_DigiSignCustomisations.ps1` | DigiSign workflow optimizations |

## 🚀 Quick Start

### Prerequisites
- Highly suggested: BIOS/UEFI: Set storage to AHCI, not RAID
- Use a network cable, wifi is tooooo slow
- Connect Power adapter for laptops
- ez Cloud Deploy USB stick v25.1 or higher

### Basic Usage

1. **Boot from ez Cloud Deploy USB:**
    - Boot from ez Cloud Deploy USB
        - HP:     F9
        - Dell:   F12
        - Lenovo: Esc

2. **Run a deployment script:**
    Once the GUI has loaded select one 
    of the deployment scripts

3. **if Entra ID script was chosen:**
   - Press Shift + F10 after you have confirmed the region and keyboard layout
   - Start the ezOOBE script by typing:
        ```shell
        ezOOBE.cmd
        ```


## 🔧 Key Features

### Automated Application Installation
- **Chocolatey package manager** setup and configuration
- **Default Apps**, Google Chrome, TreeSize Free, Notepad++, and other essential tools
- **Office 365** deployment with customizable configurations
- **ezRMM monitoring agent** for remote management

### System Optimization
- **Focus Assist** disabled for uninterrupted workflows
- **Sleep/power management** configuration for servers and workstations
- **Windows bloatware removal** (Xbox, Cortana, unnecessary UWP apps)
- **Windows Updates** automated installation

### Smart Detection & Configuration
- **OOBE vs Post-OS detection** - automatically adapts behavior
- **Azure AD vs Local AD** environment detection
- **Network folder synchronization** via SFTP
- **Error handling and fallback mechanisms**

### Remote Management Integration
- **ezRMM agent** deployment and configuration
- **ezRS (TeamViewer)** remote support setup
- **Scheduled maintenance tasks**

## 📁 Configuration
### Directory Structure
Scripts automatically create the following directory structure:
```
C:\ezNetworking\
├── Automation\
│   ├── Logs\
│   ├── Scripts\
│   └── ezCloudDeploy\
├── Apps\
├── ezRMM\
├── ezRS\
└── ezRmon\
```

## 🔍 Monitoring & Logging

All scripts generate comprehensive logs:
- **Main logs:** `C:\ezNetworking\Automation\Logs\`
- **OOBE logs:** `C:\Windows\Temp\`
- **Transcript logging** for full session capture
- **Toast notifications** for user feedback (when available)

## 🤝 Contributing

This repository is maintained by **ez Networking** for our deployment automation needs. 

### Issues & Support
- Check logs in `C:\ezNetworking\Automation\Logs\` for troubleshooting
- Ensure PowerShell execution policy allows script execution
- Verify internet connectivity for module downloads

## 📄 License

Scripts are provided as-is for deployment automation. Modify as needed for your environment.

## 👥 About ez Networking

**ez Networking** | Professional IT services and managed solutions.

**Author:** Jurgen Verhelst  
**Website:** [www.ez.be](https://www.ez.be)

---

*Last updated: November 2025*