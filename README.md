# AuditX — Security Audit Platform

> **NOTE:** This project is currently in the **PROTOTYPE** phase. It is actively being developed and may contain bugs or incomplete features. Use with caution and only on authorized targets.

AuditX is a native Linux desktop GUI application built using Quickshell (QML) and Python. It coordinates and runs security audit tools in parallel or sequence, displaying real-time terminal output and structured reports.

## Project Directory Structure
```text
auditx/
├── backend/
│   └── audit.py          # Python orchestrator & backend script
├── components/
│   ├── ConsoleView.qml   # Multi-tab live output terminal component
│   ├── ExportModal.qml   # Interactive file destination & format picker modal
│   ├── ReportView.qml    # Structured report summary & deterministic summarizer
│   ├── TargetBar.qml     # Dynamic multi-target selector & segmented input bar
│   └── ToolCard.qml      # Selectable tool configuration cards
├── launch.sh             # Main application startup script
└── shell.qml             # Main entry point & Quickshell orchestrator
```

## Integrated CLI Tools (31 Tools)
- **Vulnerability**: `nuclei`
- **Web Security**: `nikto`, `whatweb`, `sqlmap`, `gobuster`
- **Network & Active Directory**: `nmap`, `rustscan`, `netexec`, `enum4linux-ng`
- **Exploit & Framework**: `metasploit` (`msfconsole`, `msfvenom`, `msfrpcd`)
- **OSINT & Secrets**: `sherlock`, `theHarvester`, `sublist3r`, `gitleaks`
- **Cloud Security**: `scoutsuite`, `prowler`, `pacu`, `trivy`, `checkov`
- **Wireless Security**: `aircrack-ng`, `airodump-ng`, `airmon-ng`, `wifite`, `kismet`
- **Reverse Engineering**: `jadx`, `apktool`, `binwalk`, `radare2`

## Requirements & Manual Installation Guide

Since AuditX is a GUI orchestrator, you **must install the core dependencies and security tools manually** before running it for the best experience. The auto-install feature is experimental and might fail on some distributions.

### 1. System Dependencies
You need `quickshell` (for the QML GUI) and `python3` (for the backend).
- Install **[Quickshell](https://quickshell.outfoxxed.me/)** based on your distribution.
- Install Python 3 and basic dependencies (Example for Arch Linux):
  ```bash
  sudo pacman -S python qt6-declarative qt6-wayland
  ```

### 2. Python Packages
AuditX requires several Python libraries, especially for Metasploit RPC integration:
```bash
pip3 install msgpack pymetasploit3 --break-system-packages
```
*(Note: It is recommended to use a virtual environment or `pipx` if you prefer not to use `--break-system-packages`)*

### 3. Security Tools (Manual Installation)
Install the security tools you intend to use. AuditX will auto-detect which ones are available on your system.
Example for Arch Linux / BlackArch / Kali:
```bash
# Basic network & web scanners
sudo pacman -S nmap nikto whatweb sqlmap gobuster

# Metasploit Framework (Required for exploit modules & RPC)
sudo pacman -S metasploit

# OSINT & Vulnerability Scanners
sudo pacman -S nuclei gitleaks

# Wireless & Reverse Engineering
sudo pacman -S aircrack-ng kismet binwalk radare2
```
*Make sure to initialize tools like nuclei (`nuclei -update-templates`) and metasploit (`msfdb init`) before first use.*

## Running the App

1. Clone or download this repository.
2. Grant run permissions to the launcher script:
   ```bash
   chmod +x launch.sh
   ```
3. Launch the application:
   ```bash
   ./launch.sh
   ```

## Features
- **Auto-Detection**: On boot, the app checks if integrated tools are installed across all 8 security categories.
- **Auto-Installation**: If a tool is missing, the backend can attempt to pull and install it in user-space or system.
- **Multi-Target Routing**: Dedicated target inputs for IP/Subnet, Domain, URL, Cloud Provider, Local Path, Username, and Wireless Interface.
- **Deterministic Rule-Based Summarizer**: Zero-latency local heuristics that extract open ports, CVEs, cloud misconfigurations, exposed credentials, and generate hardening recommendations.
- **Multi-Tab Terminal Console**: Switch between global output stream and isolated per-tool live log tabs.
- **Comprehensive Report Export**: Interactive modal with custom path selection, quick preset directory buttons (`Documents`, `Desktop`, `Home ~`, `/tmp`), and format chips (`.md`, `.json`, `.txt`).
- **Metasploit RPC Integration**: Automates `msfrpcd` daemon connection for payload generation and listeners.
