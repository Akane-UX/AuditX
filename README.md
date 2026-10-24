# AuditX — Security Audit Platform

> **Status:** Active Development (Prototype Phase)
> 
> **Documentation:** [AuditX CLI Guide](README-CLI.md) | [Distro Compatibility](#distro-compatibility)

AuditX is a native Linux desktop GUI application built using Quickshell (Qt 6 QML) and Python to coordinate and execute security audit tools in parallel or sequence, displaying real-time terminal output, deterministic rule-based executive summaries, and structured reports. It also ships with a standalone interactive terminal CLI edition (`auditx-cli.py`, see [AuditX CLI Documentation](README-CLI.md)).

---

## Project Directory Structure

```text
auditx/
├── backend/
│   ├── __init__.py
│   └── audit.py          # Python orchestrator, tool registry & backend CLI
├── components/
│   ├── ConsoleView.qml   # Multi-tab live streaming output terminal
│   ├── ExportModal.qml   # Interactive file destination & format picker modal
│   ├── ReportView.qml    # Rule-based executive summarizer & report builder
│   ├── TargetBar.qml     # Dynamic multi-type target selector (IP, Domain, URL, Cloud, Path, User, Interface)
│   └── ToolCard.qml      # Selectable tool configuration cards with live status
├── auditx-cli.py         # Standalone terminal CLI edition
├── install.sh            # Helper installer for PATH symlinks
├── launch.sh             # Main application startup script
├── README.md             # Primary documentation
├── README-CLI.md         # Dedicated CLI documentation
├── requirements.txt      # Optional Python dependencies
└── shell.qml             # Main entry point & Quickshell orchestrator
```

---

## Integrated Security Categories & Tools (66 Tools Total)

- **Web Security**: `nikto`, `whatweb`, `sqlmap`, `gobuster`
- **Wapiti Dedicated Suite (34 Modular Scanners + Master Runner)**:
  - `wapiti` (Master runner executing all 34 attack modules simultaneously via `-m all`)
  - 34 Individual Targeted Modules: `sql`, `timesql`, `xss`, `permanentxss`, `exec` (RCE), `file` (LFI/RFI), `ssrf`, `xxe`, `ldap`, `upload`, `log4shell`, `spring4shell`, `shellshock`, `takeover`, `crlf`, `csrf`, `redirect`, `htaccess`, `brute_login_form`, `backup`, `buster`, `methods`, `ssl`, `nikto`, `cms`, `wp_enum`, `wapp`, `htp`, `network_device`, `printer`, `cookieflags`, `csp`, `http_headers`, `https_redirect`
- **Vulnerability Assessment**: `nuclei` (Fast YAML template-based vulnerability engine)
- **Network & Active Directory**: `nmap`, `rustscan`, `netexec` (CrackMapExec), `enum4linux-ng`
- **Exploit & Framework**: `metasploit` (`msfconsole`, `msfvenom`, `msfrpcd` API)
- **OSINT & Secrets**: `sherlock`, `theHarvester`, `sublist3r`, `gitleaks`
- **Cloud Security**: `scoutsuite`, `prowler`, `pacu`, `trivy`, `checkov`
- **Wireless Security**: `aircrack-ng`, `airodump-ng`, `airmon-ng`, `wifite`, `kismet`
- **Reverse Engineering**: `jadx`, `apktool`, `binwalk`, `radare2`

---

## Running the Application

### 1. GUI Edition (Quickshell)
```bash
./launch.sh
# Atau langsung menggunakan binary quickshell:
quickshell --path /home/avrlln/auditx/shell.qml
```

### 2. Standalone CLI Edition
```bash
python3 auditx-cli.py
# Atau setelah menjalankan ./install.sh:
auditx-cli
```
Panduan lengkap, daftar opsi target, dan fitur ekspor CLI tersedia di [README-CLI.md](README-CLI.md).

---

## Key Features

- **Dedicated Wapiti Suite Dropdown**: Dedicated accordion dropdown in GUI sidebar allowing one-click execution of all 34 modules or running any single module independently.
- **Multi-Tab Terminal Console**: Switch between global output stream (`ALL`) and isolated live log tabs for each running tool.
- **Deterministic Rule-Based Summarizer**: Zero-latency local heuristics that parse findings, CVEs, secrets, and misconfigurations without external AI dependencies or API limits.
- **Multi-Type Target Routing**: Segmented input bars for `IP`, `Domain`, `URL`, `Cloud`, `Path`, `Username`, and `Interface` with clean styling and smart backend routing.
- **Comprehensive Report Export**: Interactive modal with custom file path selection, quick preset directory buttons (`Documents`, `Desktop`, `Home ~`, `/tmp`), and format chips (`.md`, `.json`, `.txt`).
- **Desktop Environment Reload Isolation**: GUI processes are tagged and protected from termination during desktop shell reloads (`sreload`).
- **Auto-Detection & Auto-Install**: On startup, checks presence of tools and installs missing tools into user-space.

---

## Distro Compatibility

| Distribution Family | AuditX CLI | AuditX GUI | Auto-Install Tools | Compatibility Tier |
| :--- | :---: | :---: | :---: | :--- |
| **Arch Linux / BlackArch / EndeavourOS / Manjaro** | Native | Native | Native (`pacman`) | **Tier 1 (Out-of-the-Box / 100% Native)** |
| **Kali Linux / Parrot Security OS** | Native | Requires Quickshell | Manual / `apt` | **Tier 2 (CLI Native, GUI Minor Setup)** |
| **Ubuntu (22.04 / 24.04 LTS) & Debian 12** | Native | Compile Quickshell | Manual / `apt` | **Tier 3 (Moderate Setup)** |
| **Fedora 40/41 & RHEL / Rocky Linux** | Native | Compile / COPR | Manual / `dnf` | **Tier 3 (Moderate Setup)** |
| **openSUSE Tumbleweed / Leap** | Native | Compile Quickshell | Manual / `zypper` | **Tier 3 (Moderate Setup)** |
| **NixOS** | Flake / nix-shell | Nix Package | Non-FHS | **Tier 4 (Custom Flake Packaging)** |
| **Alpine Linux / Void Linux (musl)** | Glibc compat | Compile Quickshell | `apk` / compile | **Tier 4 (Musl Libc Adaptation)** |

### Penjelasan Tingkat Kompatibilitas:
1. **Tier 1 (Arch-based)**: Platform utama pengembangan. Quickshell tersedia di AUR (`quickshell-git`), repositori tools kompatibel dengan `pacman`, dan BlackArch menyediakan hampir seluruh tools secara bawaan.
2. **Tier 2 (Kali / Parrot)**: CLI siap pakai tanpa instalasi tools tambahan karena 95% perkakas keamanan sudah terpasang. GUI memerlukan build Quickshell dari source.
3. **Tier 3 (Ubuntu / Debian / Fedora)**: CLI membutuhkan instalasi manual alat-alat pentest; GUI membutuhkan kompilasi Quickshell dengan header Qt 6 (`qt6-base-dev`, `qt6-declarative-dev`).
4. **Tier 4 (NixOS / Alpine)**: Membutuhkan environment non-FHS khusus (`flake.nix`) atau compatibility layer untuk pustaka `musl libc`.

---
