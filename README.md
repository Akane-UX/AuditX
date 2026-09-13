# AuditX - Security Audit Platform

> **NOTE:** This project is currently in the **PROTOTYPE** phase. It is actively being developed and may contain bugs or incomplete features. Use with caution and only on authorized targets.

AuditX is a native Linux desktop GUI application built using Quickshell (QML) and Python. It coordinates and runs security audit tools in parallel or sequence, displaying real-time terminal output and structured reports.

## Project Directory Structure
```text
auditx/
├── backend/
│   └── audit.py          # Python orchestrator & backend script
├── components/
│   ├── ConsoleView.qml   # Live output terminal component
│   ├── ReportView.qml    # Structured report summary component
│   └── ToolCard.qml      # Selectable tool configuration cards
├── launch.sh             # Main application startup script
└── shell.qml             # Main entry point & Quickshell orchestrator
```

## Integrated CLI Tools
- **Vulnerability**: `nuclei`
- **Web Security**: `nikto`, `whatweb`, `sqlmap`, `gobuster`
- **Network & Active Directory**: `nmap`, `rustscan`, `netexec`, `enum4linux-ng`
- **Exploit & Framework**: `metasploit` (`msfconsole`, `msfvenom`, `msfrpcd`)
- **OSINT & Secrets**: `sherlock`, `theHarvester`, `sublist3r`, `gitleaks`

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
- **Auto-Detection**: On boot, the app checks if integrated tools are installed.
- **Auto-Installation**: If a tool is missing, the backend will attempt to automatically pull and install it before running (e.g. using `pip3` or `pacman`). *(Prototype)*
- **Metasploit RPC Integration**: Automates `msfrpcd` daemon connection for payload generation and listeners.
- **Parallel/Sequenced Execution**: Run individual tools or perform a sequenced "Full Audit" targeting a domain, IP, URL, or username.
- **Dual Console/Report Panels**: Stream standard output in real-time or switch to the structured report tab to view status and summaries.
- **Report Export**: Easily export the compiled markdown reports for documentation.
