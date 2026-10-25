#!/usr/bin/env python3
import sys
import os
import subprocess
import socket
import re

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

def strip_ansi(s: str) -> str:
    return re.sub(r'\033\[[0-9;]*m', '', s)

def ansi_ljust(s: str, width: int) -> str:
    clean_len = len(strip_ansi(s))
    padding = max(0, width - clean_len)
    return s + (' ' * padding)

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

CATEGORIES_DEF = [
    ("OSINT", "OSINT & Recon", "OSINT & Reconnaissance"),
    ("Network", "Network & Scan", "Network Scanning & Active Directory"),
    ("Web", "Web Security", "Web Application Security"),
    ("Wapiti", "Wapiti Suite", "Wapiti Web Vulnerability Suite"),
    ("Vulnerability", "Vulnerability Scan", "Vulnerability Assessment"),
    ("Exploit/Audit", "Exploitation & RPC", "Exploitation & Payloads"),
    ("Cloud", "Cloud Security", "Cloud Security & IaC"),
    ("Wireless", "Wireless Security", "Wireless Security (802.11)"),
    ("Reverse Eng", "Reverse Engineering", "Reverse Engineering & Mobile"),
]

def get_categories_structure(tools_dict):
    cat_map = {}
    for k, meta in tools_dict.items():
        cat = meta.get("category", "Other")
        cat_map.setdefault(cat, []).append((k, meta))
        
    categories = []
    known_cats = set()
    for cid, short_name, title in CATEGORIES_DEF:
        if cid in cat_map:
            categories.append({
                "id": cid,
                "label": short_name,
                "title": title,
                "tools": cat_map[cid]
            })
            known_cats.add(cid)
            
    # Include any dynamically discovered categories not in pre-definitions
    for cid, tools in cat_map.items():
        if cid not in known_cats:
            categories.append({
                "id": cid,
                "label": cid,
                "title": f"{cid} Tools",
                "tools": tools
            })
            
    return categories

def print_main_menu(categories):
    logo = [
        r"        /\        ",
        r"       /  \       ",
        r"      /    \      ",
        r"     /  /\  \     ",
        r"    /  /  \  \    ",
        r"   /  /    \  \   ",
        r"  /  /      \  \  ",
        r" /__/        \__\ "
    ]
    
    right_header = [
        f"{BOLD}AuditX CLI - v1.9.0{RESET}",
        f"{CYAN}Tool Groups by Function:{RESET}"
    ]
    
    col1_items = []
    col2_items = []
    
    half = 5
    for i in range(half):
        if i < len(categories):
            cat = categories[i]
            col1_items.append(f"{CYAN}[{i+1}]{RESET} {cat['label']} {BOLD}({len(cat['tools'])}){RESET}")
        else:
            col1_items.append("")
            
    for i in range(half, half * 2):
        item_num = i + 1
        if i < len(categories):
            cat = categories[i]
            col2_items.append(f"{CYAN}[{item_num}]{RESET} {cat['label']} {BOLD}({len(cat['tools'])}){RESET}")
        elif i == len(categories):
            col2_items.append(f"{CYAN}[{item_num}]{RESET} Built-in Network Recon")
        else:
            col2_items.append("")
            
    col_w = 28
    rows = []
    rows.extend(right_header)
    for c1, c2 in zip(col1_items, col2_items):
        rows.append(f"{ansi_ljust(c1, col_w)} {ansi_ljust(c2, col_w)}")
        
    clear_opt = f"{YELLOW}[c] Clear Terminal{RESET}"
    exit_opt = f"{RED}[0] Exit / Quit{RESET}"
    rows.append(f"{ansi_ljust(clear_opt, col_w)} {ansi_ljust(exit_opt, col_w)}")
    
    max_lines = max(len(logo), len(rows))
    print()
    for i in range(max_lines):
        left = f"{BLUE}{BOLD}{logo[i]}{RESET}" if i < len(logo) else " " * 18
        right = rows[i] if i < len(rows) else ""
        print(f"{left}   {right}")

def print_category_tools(cat_title, tools_list):
    print(f"\n{BLUE}──────────────────────────────────────────────────────────────────────────{RESET}")
    print(f"{BOLD}{CYAN}=== {cat_title} ({len(tools_list)} Tools) ==={RESET}\n")
    
    if len(tools_list) > 10:
        col_w = 36
        half = (len(tools_list) + 1) // 2
        for i in range(half):
            t1_idx = i
            k1, m1 = tools_list[t1_idx]
            left_item = f"{CYAN}[{t1_idx+1:>2}]{RESET} {m1['display']}"
            
            t2_idx = i + half
            if t2_idx < len(tools_list):
                k2, m2 = tools_list[t2_idx]
                right_item = f"{CYAN}[{t2_idx+1:>2}]{RESET} {m2['display']}"
            else:
                right_item = ""
            print(f"  {ansi_ljust(left_item, col_w)} {right_item}")
    else:
        name_w = 22
        for i, (k, meta) in enumerate(tools_list):
            num = f"{CYAN}[{i+1}]{RESET}"
            name = f"{BOLD}{meta['display']}{RESET}"
            desc = meta.get("description", "")[:48]
            print(f"  {num:<12} {ansi_ljust(name, name_w)} {desc}")
            
    print(f"\n  {YELLOW}[0] Back to Main Menu{RESET}       {YELLOW}[c] Clear Terminal{RESET}")
    print(f"{BLUE}──────────────────────────────────────────────────────────────────────────{RESET}")

def execute_tool_workflow(selected_key, selected_tool):
    input_type = selected_tool.get('input_type', 'target')
    print(f"\n{BOLD}{CYAN}=== Selected Tool: {selected_tool['display']} ==={RESET}")
    if selected_tool.get('description'):
        print(f"{BLUE}[i] Description: {selected_tool['description']}{RESET}")
        
    target = input(f"{BOLD}[>] Enter Target ({input_type.upper()}) [or '0' to cancel]: {RESET}").strip()
    
    if not target or target.lower() in ["0", "b", "back", "cancel"]:
        print(f"{YELLOW}[*] Operation cancelled.{RESET}\n")
        return
        
    print(f"\n{BOLD}{BLUE}[*] Preparing {selected_tool['display']}...{RESET}")
    
    if selected_key == "wapiti":
        print(f"\n{BOLD}{CYAN}=== Wapiti Module Selection ==={RESET}")
        print(f"  [1] All 34 Modules (-m all) {GREEN}[Recommended / Full Web Audit]{RESET}")
        print(f"  [2] Core Web Attacks (sql, timesql, xss, permanentxss, ssrf, exec, file, upload)")
        print(f"  [3] Remote Code & Critical CVEs (log4shell, spring4shell, shellshock, xxe, ldap)")
        print(f"  [4] Recon, Auth & Surface (buster, backup, brute_login_form, cms, htaccess, wapp)")
        print(f"  [5] Custom Modules (comma-separated, e.g. sql,xss,ssrf)")
        print(f"  [6] View All 34 Module Details & Descriptions")
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
            print(f"\n{BOLD}{BLUE}=== All 34 Wapiti Attack Modules ==={RESET}")
            for m_name, m_desc in getattr(audit, "WAPITI_MODULES", {}).items():
                print(f"  {GREEN}{m_name:<18}{RESET} : {m_desc}")
            print()
            modules_opt = input(f"{BOLD}[>] Enter modules to run or press Enter for 'all': {RESET}").strip() or "all"
            
        cmd = selected_tool['build_cmd'](target, {"modules": modules_opt})
    else:
        cmd = selected_tool['build_cmd'](target, {})
        
    if selected_key == "msf_rpc":
        audit.run_msf_rpc(target)
        input(f"\n{BOLD}{GREEN}[✓] Scan finished. Press Enter to return to menu...{RESET}\n")
        return
        
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
        
    input(f"\n{BOLD}{GREEN}[✓] Scan finished. Press Enter to return to menu...{RESET}\n")

def category_menu_loop(cat_id, cat_title, tools_in_cat):
    while True:
        try:
            print_category_tools(cat_title, tools_in_cat)
            total_tools = len(tools_in_cat)
            choice = input(f"{BOLD}[>] Select tool [1-{total_tools}, 0 to back]: {RESET}").strip()
            
            if choice.lower() in ["0", "b", "back"]:
                break
                
            if choice.lower() in ["c", "cls", "clear"]:
                os.system("clear")
                continue
                
            if choice.lower() in ["q", "quit", "exit"]:
                print(f"\n{CYAN}[*] Exiting AuditX CLI. Stay secure!{RESET}\n")
                sys.exit(0)
                
            if not choice.isdigit():
                print(f"{RED}[!] Invalid choice '{choice}'. Enter 1-{total_tools} or '0' to return.{RESET}")
                continue
                
            tool_idx = int(choice)
            if tool_idx < 1 or tool_idx > total_tools:
                print(f"{RED}[!] Choice out of range (1-{total_tools}).{RESET}")
                continue
                
            selected_key, selected_tool = tools_in_cat[tool_idx - 1]
            execute_tool_workflow(selected_key, selected_tool)
            
        except (KeyboardInterrupt, EOFError):
            print(f"\n{YELLOW}[*] Returning to Main Menu...{RESET}\n")
            break

def main():
    os.system("clear")
    categories = get_categories_structure(TOOLS)
    total_categories = len(categories)
    network_recon_num = total_categories + 1
    
    while True:
        try:
            print_main_menu(categories)
            print(f"{BLUE}──────────────────────────────────────────────────────────────────────────{RESET}")
            choice = input(f"{BOLD}[>] Select category [1-{network_recon_num}, c to clear, 0/q to quit]: {RESET}").strip()
            
            if choice.lower() in ["0", "q", "quit", "exit"]:
                print(f"\n{CYAN}[*] Exiting AuditX CLI. Stay secure!{RESET}\n")
                break
                
            if choice.lower() in ["c", "cls", "clear"]:
                os.system("clear")
                continue
                
            if not choice.isdigit():
                print(f"{RED}[!] Invalid choice '{choice}'. Enter 1-{network_recon_num}, 'c' to clear, or '0' to quit.{RESET}")
                continue
                
            choice_num = int(choice)
            if choice_num == network_recon_num:
                perform_network_recon()
                input(f"\n{BOLD}{GREEN}[✓] Network Recon completed. Press Enter to return to menu...{RESET}\n")
                continue
                
            if choice_num < 1 or choice_num > total_categories:
                print(f"{RED}[!] Choice out of range (1-{network_recon_num}).{RESET}")
                continue
                
            selected_cat = categories[choice_num - 1]
            category_menu_loop(selected_cat["id"], selected_cat["title"], selected_cat["tools"])
            print()
            
        except (KeyboardInterrupt, EOFError):
            print(f"\n\n{YELLOW}[!] Exiting AuditX CLI. Stay secure!{RESET}\n")
            break

if __name__ == "__main__":
    main()
