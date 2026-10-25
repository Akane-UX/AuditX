# AuditX CLI

Interactive terminal interface and security tool orchestrator for security assessments, reconnaissance, and network triage.

---

## Overview

AuditX CLI gives you a terminal-based interface to run security tools without remembering command-line flags. It formats targets, runs the selected tools, and streams output directly to the terminal.

```text
        /\           AuditX CLI - v1.9.0
       /  \          Tool Groups by Function:
      /    \         [1] OSINT & Recon (4)        [6] Exploitation & RPC (3)
     /  /\  \        [2] Network & Scan (5)       [7] Cloud Security (5)
    /  /  \  \       [3] Web Security (4)         [8] Wireless Security (5)
   /  /    \  \      [4] Wapiti Suite (35)        [9] Reverse Engineering (4)
  /  /      \  \     [5] Vulnerability Scan (1)   [10] Built-in Network Recon
 /__/        \__\    [c] Clear Terminal           [0] Exit / Quit
```

---

## Features

- **Compact Category Grouping**: All 66 security tools are organized into 9 functional types plus built-in Network Recon for a clean, compact terminal interface.
- **Continuous Scroll Flow**: Selecting categories and running tools appends output cleanly downward without clearing your terminal screen or erasing scrollback history.
- **Direct Category Views**: Focused tool lists without repetitive logos or banners, showing all tools in the chosen category directly.
- **Clear Terminal Option**: Dedicated `[c]` option in the main menu (and tool menus) to wipe and reset the terminal view on demand.
- **Target routing**: Prompts for the appropriate input type based on the selected tool (IP address, domain, URL, local path, username, cloud provider, or network interface).
- **Wapiti suite integration**: Run the master scan (`-m all`) or pick from 34 individual attack modules.
- **Network reconnaissance**: Detects local IP configurations and performs subnet scans using `nmap` or `arp-scan`.
- **Metasploit RPC**: Connect to and run auxiliary modules through `msfrpcd`.
- **Terminal native**: Runs in any standard terminal without graphical dependencies.

---

## Integrated Tools

| Category                                | Tools                                                    | Target Type              |
| --------------------------------------- | -------------------------------------------------------- | ------------------------ |
| **OSINT & Secrets**               | Sherlock, theHarvester, Sublist3r, Gitleaks              | Username, Domain, Path   |
| **Network & Active Directory**    | Nmap, RustScan, NetExec, Enum4Linux-NG                   | IP / Subnet, Domain      |
| **Web Security**                  | Nikto, WhatWeb, SQLMap, Gobuster                         | URL, Domain              |
| **Wapiti Web Suite (35 options)** | Master Scanner (`-m all`) + 34 targeted attack modules | URL                      |
| **Vulnerability Scanning**        | Nuclei                                                   | URL, Domain              |
| **Exploitation & RPC**            | Metasploit Aux, Metasploit RPC, Msfvenom, MSF Listener   | IP, Port, Payload Config |
| **Cloud Security**                | ScoutSuite, Prowler, Pacu, Trivy Cloud, Checkov          | Cloud Provider, Path     |
| **Wireless Security**             | Aircrack-ng, Airodump-ng, Airmon-ng, Wifite, Kismet      | Interface, Capture File  |
| **Reverse Engineering**           | JADX, Apktool, Binwalk, Radare2                          | File Path                |
| **Network Recon**                 | Built-in subnet discovery                                | Automatic / Subnet       |

---

## Installation

### 1. Requirements

- Python 3.10+
- Host security tools (install via your system package manager, e.g. `pacman`, `apt`, or `brew`)

Optional dependencies for Metasploit RPC:

```bash
pip install -r requirements.txt
```

### 2. Quick Setup

Run `install.sh` to create symlinks in `~/.local/bin` (or `/usr/local/bin`):

```bash
chmod +x install.sh
./install.sh
```

This creates:

- `auditx-cli` pointing to `auditx-cli.py`
- `auditx-gui` pointing to `launch.sh`

### 3. Direct Run

You can also run the script directly:

```bash
python3 auditx-cli.py
```

---

## Usage

1. Start AuditX CLI:
   ```bash
   auditx-cli
   ```
2. Type the number corresponding to the tool you want to run.
3. Enter the required target when prompted (IP, domain, URL, username, or path).
4. Review live scan output in your terminal.
5. Choose whether to export the results to a file when prompted.
6. Enter `0` or `q` at the main menu to quit.

---

## Exporting Reports

After running a scan, the CLI allows exporting outputs into formatted files:

- Markdown (`.md`)
- JSON (`.json`)
- Plain text (`.txt`)

You can specify a custom file path or accept the default timestamped filename in the current directory.

---

## Credits Tools

AuditX CLI coordinates open-source security tools created by security researchers and developers. Full credit goes to their authors:

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

AuditX CLI is intended only for authorized penetration testing, vulnerability assessments, and educational research on systems with explicit written permission. Unauthorized testing against target systems without consent is prohibited.
