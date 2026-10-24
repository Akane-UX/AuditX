# AuditX CLI

Interactive terminal interface and security tool orchestrator for security assessments, reconnaissance, and network triage.

---

## Overview

AuditX CLI gives you a terminal-based interface to run security tools without remembering command-line flags. It formats targets, runs the selected tools, and streams output directly to the terminal.

```text
        /\         AuditX - v1.9.0-cli
       /  \        Available Tools:
      /    \       [1] Sherlock                   [2] theHarvester
     /  /\  \      [3] Sublist3r                  [4] Nmap
    /  /  \  \     [5] RustScan                   [6] Nikto
   /  /    \  \    [7] WhatWeb                    [8] SQLMap
  /  /      \  \   [9] Metasploit Aux             [10] Metasploit RPC
 /__/        \__\  [11] Msfvenom Payload          [12] Nuclei
                   ...                            ...
                   [67] Network Recon             [0] Exit / Quit
```

---

## Features

- **Interactive menu**: Returns to the main menu after each scan, with an explicit `0` or `q` to exit.
- **Two-column layout**: Quick selection for 66 security tools plus built-in Network Recon.
- **Target routing**: Prompts for the appropriate input type based on the selected tool (IP address, domain, URL, local path, username, cloud provider, or network interface).
- **Wapiti suite integration**: Run the master scan (`-m all`) or pick from 34 individual attack modules.
- **Network reconnaissance**: Detects local IP configurations and performs subnet scans using `nmap` or `arp-scan`.
- **Report export**: Save scan results to `.md`, `.json`, or `.txt`.
- **Metasploit RPC**: Connect to and run auxiliary modules through `msfrpcd`.
- **Terminal native**: Runs in any standard terminal without graphical dependencies.

---

## Integrated Tools

| Category | Tools | Target Type |
|---|---|---|
| **OSINT & Secrets** | Sherlock, theHarvester, Sublist3r, Gitleaks | Username, Domain, Path |
| **Network & Active Directory** | Nmap, RustScan, NetExec, Enum4Linux-NG | IP / Subnet, Domain |
| **Web Security** | Nikto, WhatWeb, SQLMap, Gobuster | URL, Domain |
| **Wapiti Web Suite (35 options)** | Master Scanner (`-m all`) + 34 targeted attack modules | URL |
| **Vulnerability Scanning** | Nuclei | URL, Domain |
| **Exploitation & RPC** | Metasploit Aux, Metasploit RPC, Msfvenom, MSF Listener | IP, Port, Payload Config |
| **Cloud Security** | ScoutSuite, Prowler, Pacu, Trivy Cloud, Checkov | Cloud Provider, Path |
| **Wireless Security** | Aircrack-ng, Airodump-ng, Airmon-ng, Wifite, Kismet | Interface, Capture File |
| **Reverse Engineering** | JADX, Apktool, Binwalk, Radare2 | File Path |
| **Network Recon** | Built-in subnet discovery | Automatic / Subnet |

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
