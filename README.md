# AuditX — Security Audit Platform

> **Status:** Active Development (Prototype Phase)

AuditX is a native Linux desktop GUI application built using Quickshell (QML) and Python to coordinate and execute security audit tools in parallel or sequence, displaying real-time terminal output, deterministic rule-based executive summaries, and structured reports.

## 📁 Project Directory Structure
```text
auditx/
├── backend/
│   └── audit.py          # Python orchestrator, tool registry & backend CLI
├── components/
│   ├── ConsoleView.qml   # Multi-tab live streaming output terminal
│   ├── ExportModal.qml   # Interactive file destination & format picker modal
│   ├── ReportView.qml    # Rule-based executive summarizer & report builder
│   ├── TargetBar.qml     # Dynamic multi-type target selector (IP, Domain, URL, Cloud, Path, User, Interface)
│   └── ToolCard.qml      # Selectable tool configuration cards with live status
├── launch.sh             # Main application startup script
├── auditx-cli.py         # Standalone terminal CLI edition
└── shell.qml             # Main entry point & Quickshell orchestrator
```

## 🛠️ Integrated Security Categories & Tools (66 Tools Total)
- **Web Security**: `nikto`, `whatweb`, `sqlmap`, `gobuster`
- **Wapiti Dedicated Suite (34 Modules + Master)**:
  - `wapiti` (Master runner for all 34 modules simultaneously via `-m all`)
  - 34 Individual Modular Scanners: `sql`, `timesql`, `xss`, `permanentxss`, `exec` (RCE), `file` (LFI/RFI), `ssrf`, `xxe`, `ldap`, `upload`, `log4shell`, `spring4shell`, `shellshock`, `takeover`, `crlf`, `csrf`, `redirect`, `htaccess`, `brute_login_form`, `backup`, `buster`, `methods`, `ssl`, `nikto`, `cms`, `wp_enum`, `wapp`, `htp`, `network_device`, `printer`, `cookieflags`, `csp`, `http_headers`, `https_redirect`
- **Vulnerability**: `nuclei` (Fast YAML template-based vulnerability scanner)
- **Network & Active Directory**: `nmap`, `rustscan`, `netexec`, `enum4linux-ng`
- **Exploit & Framework**: `metasploit` (`msfconsole`, `msfvenom`, `msfrpcd`)
- **OSINT & Secrets**: `sherlock`, `theHarvester`, `sublist3r`, `gitleaks`
- **Cloud Security**: `scoutsuite`, `prowler`, `pacu`, `trivy`, `checkov`
- **Wireless Security**: `aircrack-ng`, `airodump-ng`, `airmon-ng`, `wifite`, `kismet`
- **Reverse Engineering**: `jadx`, `apktool`, `binwalk`, `radare2`

## 🚀 Running the Application

### 1. GUI Edition (Quickshell)
```bash
./launch.sh
# Atau langsung menggunakan quickshell:
quickshell --path /home/avrlln/auditx/shell.qml
```

### 2. Standalone CLI Edition
```bash
python3 auditx-cli.py
```

## ⚙️ Key Features
- **Auto-Detection & Auto-Install**: On startup, checks presence of all tools and auto-installs missing ones into user-space.
- **Dedicated Wapiti Suite Dropdown**: Dedicated accordion dropdown in GUI sidebar allowing one-click execution of all 34 modules or running any single module independently.
- **Multi-Type Target Routing**: Segmented input bars for `IP`, `Domain`, `URL`, `Cloud`, `Path`, `Username`, and `Interface` with smart backend routing.
- **Multi-Tab Terminal Console**: Switch between global output stream (`ALL`) and isolated live log tabs for each running tool.
- **Deterministic Rule-Based Summarizer**: Zero-latency local heuristics that parse findings, CVEs, secrets, and misconfigurations without external AI dependencies.
- **Comprehensive Report Export**: Interactive modal with custom file path selection, quick preset directory buttons (`Documents`, `Desktop`, `Home ~`, `/tmp`), and format chips (`.md`, `.json`, `.txt`).
