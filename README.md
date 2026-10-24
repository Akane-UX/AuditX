# AuditX - Security Audit Platform

> ***Experimental Project***
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
# Or using binary quickshell:
quickshell --path /home/auditx/shell.qml
```

### 2. Standalone CLI Edition

```bash
python3 auditx-cli.py
# Or after exec ./install.sh:
auditx-cli
```

A complete guide, a list of target options, and CLI export features are available in [README-CLI.md](README-CLI.md).

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

| Distribution Family                                      |    AuditX CLI    |     AuditX GUI     | Auto-Install Tools | Compatibility Tier                              |
| :------------------------------------------------------- | :---------------: | :-----------------: | :-----------------: | :---------------------------------------------- |
| **Arch Linux / BlackArch / EndeavourOS / Manjaro** |      Native      |       Native       | Native (`pacman`) | **Tier 1 (Out-of-the-Box / 100% Native)** |
| **Kali Linux / Parrot Security OS**                |      Native      | Requires Quickshell |  Manual / `apt`  | **Tier 2 (CLI Native, GUI Minor Setup)**  |
| **Ubuntu (22.04 / 24.04 LTS) & Debian 12**         |      Native      | Compile Quickshell |  Manual / `apt`  | **Tier 3 (Moderate Setup)**               |
| **Fedora 40/41 & RHEL / Rocky Linux**              |      Native      |   Compile / COPR   |  Manual / `dnf`  | **Tier 3 (Moderate Setup)**               |
| **openSUSE Tumbleweed / Leap**                     |      Native      | Compile Quickshell | Manual / `zypper` | **Tier 3 (Moderate Setup)**               |
| **NixOS**                                          | Flake / nix-shell |     Nix Package     |       Non-FHS       | **Tier 4 (Custom Flake Packaging)**       |
| **Alpine Linux / Void Linux (musl)**               |   Glibc compat   | Compile Quickshell |  `apk` / compile  | **Tier 4 (Musl Libc Adaptation)**         |

### Explanation of Compatibility Levels:

1. **Tier 1 (Arch-based)**: The main platform of development. Quickshell is available in AUR (`quickshell-git`), the repository tool is compatible with ‘pacman`, and BlackArch provides almost all tools in a built-in manner.
2. **Tier 2 (Potago / Parrot)**: CLI is ready to use without the installation of additional tools because 95% of security tools are installed. The GUI needs a Quickshell build from the source.
3. **Tier 3 (Ubuntu / Debian / Fedora)**: CLI requires manual installation of pentest tools; GUI requires a compilation of Quickshell with header Qt 6 (`qt6-base-dev`, `qt-6declarative-dev`).
4. **Tier 4 (NixOS / Alpine)**: Requires a special non-FHS environment (`flake.nix`) or compatibility layer for the library `musl libc`.

---

## Credits Tools

AuditX coordinates open-source security tools created by security researchers and developers. Full credit goes to their authors:

| Tool                           | Developers / Maintainers                                                      | Source / Website                                                                                                                |
| ------------------------------ | ----------------------------------------------------------------------------- | ------------------------------------------------------------------------------------------------------------------------------- |
| **Wapiti**               | Maxime Alay-Eddine, Julien Tauran, David del Pozo, Alberto Pastor             | [wapiti-scanner/wapiti](https://github.com/wapiti-scanner/wapiti) / [wapiti-scanner.github.io](https://wapiti-scanner.github.io/) |
| **Sherlock**             | Siddharth Dushantha & Sherlock Project contributors                           | [sherlock-project/sherlock](https://github.com/sherlock-project/sherlock)                                                        |
| **theHarvester**         | Christian Martorella (@laramies) & contributors                               | [laramies/theHarvester](https://github.com/laramies/theHarvester)                                                                |
| **Sublist3r**            | Ahmed Aboul-Ela (@aboul3la)                                                   | [aboul3la/Sublist3r](https://github.com/aboul3la/Sublist3r)                                                                      |
| **Nmap**                 | Gordon Lyon (Fyodor) / Insecure.Com LLC                                       | [nmap.org](https://nmap.org/) / [nmap/nmap](https://github.com/nmap/nmap)                                                         |
| **RustScan**             | Branden (bee-san) & RustScan Community                                        | [RustScan/RustScan](https://github.com/RustScan/RustScan)                                                                        |
| **Nikto**                | Chris Sullo, David Lodge & CIRT.net                                           | [sullo/nikto](https://github.com/sullo/nikto)                                                                                    |
| **WhatWeb**              | Andrew Horton (urbanadventurer), Brendan Coles (bcoles)                       | [urbanadventurer/WhatWeb](https://github.com/urbanadventurer/WhatWeb)                                                            |
| **SQLMap**               | Bernardo Damele A. G., Miroslav Stampar                                       | [sqlmap.org](https://sqlmap.org/) / [sqlmapproject/sqlmap](https://github.com/sqlmapproject/sqlmap)                               |
| **Nuclei**               | ProjectDiscovery                                                              | [projectdiscovery/nuclei](https://github.com/projectdiscovery/nuclei)                                                            |
| **Metasploit Framework** | Rapid7 & Metasploit Community (founded by H.D. Moore)                         | [rapid7/metasploit-framework](https://github.com/rapid7/metasploit-framework) / [metasploit.com](https://www.metasploit.com/)     |
| **Gobuster**             | Christian Mehlmauer (@OJ)                                                     | [OJ/gobuster](https://github.com/OJ/gobuster)                                                                                    |
| **NetExec**              | Pennyw1se, mpgn & NetExec contributors (original CrackMapExec by byt3bl33d3r) | [Pennyw1se/NetExec](https://github.com/Pennyw1se/NetExec)                                                                        |
| **Enum4linux-ng**        | René de Koster (@cddmp)                                                      | [cddmp/enum4linux-ng](https://github.com/cddmp/enum4linux-ng)                                                                    |
| **Gitleaks**             | Zachary Rice (@zricethezav)                                                   | [gitleaks/gitleaks](https://github.com/gitleaks/gitleaks)                                                                        |
| **ScoutSuite**           | NCC Group                                                                     | [nccgroup/ScoutSuite](https://github.com/nccgroup/ScoutSuite)                                                                    |
| **Prowler**              | Toni de la Fuente & Prowler Open Source Contributors                          | [prowler-cloud/prowler](https://github.com/prowler-cloud/prowler)                                                                |
| **Pacu**                 | Rhino Security Labs                                                           | [RhinoSecurityLabs/pacu](https://github.com/RhinoSecurityLabs/pacu)                                                              |
| **Trivy**                | Aqua Security                                                                 | [aquasecurity/trivy](https://github.com/aquasecurity/trivy)                                                                      |
| **Checkov**              | Bridgecrew (Palo Alto Networks)                                               | [bridgecrewio/checkov](https://github.com/bridgecrewio/checkov)                                                                  |
| **Aircrack-ng**          | Thomas d'Otreppe (Mister_X) & Aircrack-ng team                                | [aircrack-ng.org](https://www.aircrack-ng.org/) / [aircrack-ng/aircrack-ng](https://github.com/aircrack-ng/aircrack-ng)           |
| **Wifite**               | derv82, kimocoder                                                             | [derv82/wifite2](https://github.com/derv82/wifite2)                                                                              |
| **Kismet**               | Mike Kershaw (dragorn)                                                        | [kismetwireless.net](https://www.kismetwireless.net/) / [kismetwireless/kismet](https://github.com/kismetwireless/kismet)         |
| **JADX**                 | Skylot                                                                        | [skylot/jadx](https://github.com/skylot/jadx)                                                                                    |
| **Apktool**              | Connor Tumbleson (iBotPeaches), Ryszard Wiśniewski (brutall)                 | [iBotPeaches/Apktool](https://github.com/iBotPeaches/Apktool)                                                                    |
| **Binwalk**              | Craig Heffner / ReFirm Labs                                                   | [ReFirmLabs/binwalk](https://github.com/ReFirmLabs/binwalk)                                                                      |
| **Radare2**              | Sergi Àlvarez (pancake) & Radare2 Community                                  | [rada.re](https://rada.re/) / [radareorg/radare2](https://github.com/radareorg/radare2)                                           |

---

## Legal Disclaimer

AuditX is intended only for authorized penetration testing, vulnerability assessments, and educational research on systems with explicit written permission. Unauthorized testing against target systems without consent is prohibited.
