#!/usr/bin/env python3
import sys
import os
import subprocess
import socket

# Ensure local bin is in PATH
local_bin = os.path.expanduser("~/.local/bin")
if local_bin not in os.environ.get("PATH", "").split(os.pathsep):
    os.environ["PATH"] = local_bin + os.pathsep + os.environ.get("PATH", "")

# Add backend to path to import audit.py
script_dir = os.path.dirname(os.path.realpath(__file__))
backend_paths = [
    os.path.join(script_dir, "backend"),
    script_dir,
    os.path.expanduser("~/auditx/backend"),
]
for p in backend_paths:
    if p not in sys.path:
        sys.path.insert(0, p)

try:
    import audit
    from audit import TOOLS
except ImportError:
    print("Error: Could not find AuditX backend (audit.py). Make sure backend/audit.py exists.")
    sys.exit(1)

# Colors
BLUE = "\033[34m"
RESET = "\033[0m"
BOLD = "\033[1m"
CYAN = "\033[36m"
GREEN = "\033[32m"
RED = "\033[31m"
YELLOW = "\033[33m"

# Override emit to prevent JSON output in CLI mode
def custom_emit(event: str, **kwargs):
    if event == "tool_output":
        print(kwargs.get("line", ""))
    elif event == "tool_error":
        print(f"{RED}[!] Error: {kwargs.get('message')}{RESET}")
    elif event == "tool_start":
        print(f"{CYAN}[$] {kwargs.get('cmd')}{RESET}\n")

audit.emit = custom_emit

def get_my_ip():
    s = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)
    try:
        s.connect(('10.255.255.255', 1))
        IP = s.getsockname()[0]
    except Exception:
        IP = '127.0.0.1'
    finally:
        s.close()
    return IP

def perform_network_recon():
    print(f"\n{BOLD}{BLUE}[*] Performing Network Recon...{RESET}")
    my_ip = get_my_ip()
    print(f"{BOLD}[+] My Local IP: {GREEN}{my_ip}{RESET}")
    
    if my_ip != '127.0.0.1':
        subnet = ".".join(my_ip.split('.')[:-1]) + ".0/24"
        print(f"{BOLD}[*] Scanning surrounding IPs on subnet {subnet}...{RESET}")
        try:
            if subprocess.run(['which', 'nmap'], capture_output=True).returncode == 0:
                subprocess.run(['nmap', '-sn', subnet])
            elif subprocess.run(['which', 'arp-scan'], capture_output=True).returncode == 0:
                subprocess.run(['sudo', 'arp-scan', '--localnet'])
            else:
                print(f"{YELLOW}[!] nmap or arp-scan not found. Cannot scan local subnet.{RESET}")
        except Exception as e:
            print(f"{RED}[!] Error scanning subnet: {e}{RESET}")
    else:
        print(f"{YELLOW}[!] Loopback IP detected, skipping subnet scan.{RESET}")

def print_ui(tools_list):
    os.system("clear")
    logo = [
        r"      /\      ",
        r"     /  \     ",
        r"    /    \    ",
        r"   /      \   ",
        r"  /        \  ",
        r" /          \ "
    ]
    
    right_header = [
        f"{BOLD}AuditX - v1.9.0-cli{RESET}",
        f"Available Tools:"
    ]
    
    col_width = 30
    formatted_tools = []
    
    for i, (key, meta) in enumerate(tools_list.items()):
        formatted_tools.append(f"[{i+1}] {meta['display'][:col_width-6]}")
    
    formatted_tools.append(f"[{len(tools_list)+1}] Network Recon")
    formatted_tools.append(f"[0] Exit / Quit")
    
    num_cols = 2
    rows = []
    for i in range(0, len(formatted_tools), num_cols):
        row = formatted_tools[i:i+num_cols]
        while len(row) < num_cols:
            row.append("")
        rows.append(row)
        
    for i in range(len(rows)):
        r = rows[i]
        right_header.append(f"{r[0]:<{col_width}} {r[1]}")
        
    max_lines = max(len(logo), len(right_header))
    
    for i in range(max_lines):
        left = f"{BLUE}{BOLD}{logo[i]}{RESET}" if i < len(logo) else "              "
        right = right_header[i] if i < len(right_header) else ""
        print(f"{left}   {right}")

def main():
    tool_keys = list(TOOLS.keys())
    total_options = len(tool_keys) + 1  # Network Recon is last numbered tool option

    while True:
        try:
            print_ui(TOOLS)
            print(f"\n{BLUE}──────────────────────────────────────────────────────────────────────────{RESET}")
            choice = input(f"{BOLD}[>] Select tool [1-{total_options}, 0/q to quit]: {RESET}").strip()
            
            if choice.lower() in ["0", "q", "quit", "exit"]:
                print(f"\n{CYAN}[*] Exiting AuditX CLI. Stay secure!{RESET}\n")
                break
                
            if not choice.isdigit():
                print(f"{RED}[!] Invalid choice. Please enter a number between 0 and {total_options} or 'q'.{RESET}")
                input(f"{YELLOW}Press Enter to continue...{RESET}")
                continue
                
            choice_num = int(choice)
            if choice_num < 1 or choice_num > total_options:
                print(f"{RED}[!] Choice out of range (1-{total_options}).{RESET}")
                input(f"{YELLOW}Press Enter to continue...{RESET}")
                continue
                
            if choice_num == total_options:
                perform_network_recon()
                input(f"\n{BOLD}{GREEN}[✓] Network Recon completed. Press Enter to return to menu...{RESET}")
                continue
                
            selected_key = tool_keys[choice_num - 1]
            selected_tool = TOOLS[selected_key]
            
            input_type = selected_tool.get('input_type', 'target')
            target = input(f"{BOLD}[>] Enter Target {input_type.capitalize()}: {RESET}").strip()
            
            if not target:
                print(f"{RED}[!] Target cannot be empty.{RESET}")
                input(f"{YELLOW}Press Enter to continue...{RESET}")
                continue
                
            print(f"\n{BOLD}{BLUE}[*] Preparing {selected_tool['display']}...{RESET}")
            
            if selected_key == "wapiti":
                print(f"\n{BOLD}{CYAN}=== Wapiti Module Selection ==={RESET}")
                print(f"  [1] All 30 Modules (-m all) {GREEN}[Recommended / Full Web Audit]{RESET}")
                print(f"  [2] Core Web Attacks (sql, timesql, xss, permanentxss, ssrf, exec, file, upload)")
                print(f"  [3] Remote Code & Critical CVEs (log4shell, spring4shell, shellshock, xxe, ldap)")
                print(f"  [4] Recon, Auth & Surface (buster, backup, brute_login_form, cms, htaccess, wapp)")
                print(f"  [5] Custom Modules (comma-separated, e.g. sql,xss,ssrf)")
                print(f"  [6] View All 30 Module Details & Descriptions")
                mod_choice = input(f"{BOLD}[>] Choose mode [1-6, default 1]: {RESET}").strip()
                modules_opt = "all"
                if mod_choice == "2":
                    modules_opt = "sql,timesql,xss,permanentxss,ssrf,exec,file,upload"
                elif mod_choice == "3":
                    modules_opt = "log4shell,spring4shell,shellshock,xxe,ldap"
                elif mod_choice == "4":
                    modules_opt = "buster,backup,brute_login_form,cms,htaccess,wapp"
                elif mod_choice == "5":
                    custom_m = input(f"{BOLD}[>] Enter module names (comma-separated): {RESET}").strip()
                    modules_opt = custom_m if custom_m else "all"
                elif mod_choice == "6":
                    print(f"\n{BOLD}{BLUE}=== All 30 Wapiti Attack Modules ==={RESET}")
                    for m_name, m_desc in getattr(audit, "WAPITI_MODULES", {}).items():
                        print(f"  {GREEN}{m_name:<18}{RESET} : {m_desc}")
                    print()
                    modules_opt = input(f"{BOLD}[>] Enter modules to run or press Enter for 'all': {RESET}").strip() or "all"
                
                cmd = selected_tool['build_cmd'](target, {"modules": modules_opt})
            else:
                cmd = selected_tool['build_cmd'](target, {})
            
            if selected_key == "msf_rpc":
                audit.run_msf_rpc(target)
                input(f"\n{BOLD}{GREEN}[✓] Scan finished. Press Enter to return to menu...{RESET}")
                continue
                
            print(f"{CYAN}[$] {' '.join(cmd)}{RESET}\n")
            
            try:
                proc = subprocess.Popen(cmd)
                proc.wait()
            except FileNotFoundError:
                print(f"{RED}[!] Command not found: {cmd[0]}{RESET}")
                print(f"{YELLOW}[*] You may need to install it first using: {RESET}")
                print(f"    {' '.join(selected_tool.get('install_cmd', []))}")
            except KeyboardInterrupt:
                print(f"\n{YELLOW}[!] Execution interrupted by user.{RESET}")
                
            input(f"\n{BOLD}{GREEN}[✓] Scan finished. Press Enter to return to menu...{RESET}")

        except (KeyboardInterrupt, EOFError):
            print(f"\n\n{YELLOW}[!] Exiting AuditX CLI...{RESET}\n")
            break

if __name__ == "__main__":
    main()
