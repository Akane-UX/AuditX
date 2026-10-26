import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import "components"

// ─── AuditX — Security Audit Tool (Quickshell / QML) ─────────────────────────
ShellRoot {
    id: root

    // ── State ──────────────────────────────────────────────────────────────────
    property string targetIp: ""
    property string targetDomain: ""
    property string targetUrl: ""
    property string targetCloud: ""
    property string targetPath: ""
    property string targetUsername: ""
    property string targetInterface: ""

    property string target: (targetIp || targetDomain || targetUrl || targetCloud || targetPath || targetUsername || targetInterface || "")
    property bool   isRunning: false
    property string activeTab: "console"   // "console" | "report" | "terminal"
    property var    toolRunState: ({})      // tool -> "idle" | "running" | "done" | "failed"
    property var    toolLines: ({})         // tool -> array of output lines
    property var    missingTools: []        // tool ids not detected

    // toolStatus stored as a ListModel for reliable reactivity in ToolCard bindings
    ListModel {
        id: toolStatusModel
        // Each element: { tool: "name", installed: true/false }
    }

    // Helper: get installed bool by tool name from toolStatusModel
    function toolIsInstalled(toolName) {
        for (var i = 0; i < toolStatusModel.count; i++) {
            if (toolStatusModel.get(i).tool === toolName)
                return toolStatusModel.get(i).installed
        }
        return false
    }

    // Helper: update or insert tool status
    function setToolStatus(toolName, installed) {
        for (var i = 0; i < toolStatusModel.count; i++) {
            if (toolStatusModel.get(i).tool === toolName) {
                toolStatusModel.setProperty(i, "installed", installed)
                return
            }
        }
        toolStatusModel.append({ tool: toolName, installed: installed })
    }

    property var toolMeta: [
        { id: "sherlock",      display: "Sherlock",       category: "OSINT",         inputType: "user",      description: "Username search across hundreds of platforms" },
        { id: "theharvester",  display: "theHarvester",   category: "OSINT",         inputType: "domain",    description: "Email, subdomain & IP harvesting" },
        { id: "sublist3r",     display: "Sublist3r",      category: "OSINT",         inputType: "domain",    description: "Fast subdomain enumeration" },
        { id: "nmap",          display: "Nmap",           category: "Network",       inputType: "ip",        description: "Port scanning & service detection" },
        { id: "rustscan",      display: "RustScan",       category: "Network",       inputType: "ip",        description: "Ultra-fast port scanner" },
        { id: "nikto",         display: "Nikto",          category: "Web",           inputType: "url",       description: "Web server vulnerability scanner" },
        { id: "whatweb",       display: "WhatWeb",        category: "Web",           inputType: "url",       description: "Web technology fingerprinting" },
        { id: "sqlmap",        display: "SQLMap",         category: "Web",           inputType: "url",       description: "SQL injection detection & exploitation" },
        { id: "metasploit",    display: "Metasploit Aux", category: "Network",       inputType: "ip",        description: "MSF service & SMB fingerprinting scanner" },
        { id: "msf_rpc",       display: "Metasploit RPC", category: "Exploit/Audit", inputType: "ip",        description: "MSF RPC API orchestrator via msfrpcd" },
        { id: "msfvenom",      display: "Msfvenom",       category: "Exploit/Audit", inputType: "ip",        description: "Generate Linux meterpreter reverse TCP payload" },
        { id: "msf_listener",  display: "MSF Listener",   category: "Exploit/Audit", inputType: "ip",        description: "Start reverse TCP handler (linux/x64/meterpreter)" },
        { id: "nuclei",        display: "Nuclei",         category: "Vulnerability", inputType: "url",       description: "Fast template-based vulnerability scanner" },
        { id: "gobuster",      display: "Gobuster",       category: "Web",           inputType: "url",       description: "Directory and file fuzzing tool" },
        { id: "netexec",       display: "NetExec",        category: "Network",       inputType: "ip",        description: "AD / SMB environment pentesting tool" },
        { id: "enum4linux-ng", display: "Enum4Linux-NG",  category: "Network",       inputType: "ip",        description: "Windows / Samba enumeration tool" },
        { id: "gitleaks",      display: "Gitleaks",       category: "OSINT",         inputType: "path",      description: "Detect secrets and passwords in repositories" },
        { id: "scoutsuite",    display: "ScoutSuite",     category: "Cloud",         inputType: "cloud",     description: "Multi-cloud security posture assessment" },
        { id: "prowler",       display: "Prowler",        category: "Cloud",         inputType: "cloud",     description: "Cloud security & CIS compliance benchmarks" },
        { id: "pacu",          display: "Pacu",           category: "Cloud",         inputType: "cloud",     description: "AWS cloud exploitation & auditing framework" },
        { id: "trivy",         display: "Trivy Cloud",    category: "Cloud",         inputType: "cloud",     description: "Cloud & IaC scanner for AWS, K8s, Terraform" },
        { id: "checkov",       display: "Checkov",        category: "Cloud",         inputType: "path",      description: "Static code analysis for IaC & cloud configs" },
        { id: "aircrack-ng",   display: "Aircrack-ng",    category: "Wireless",      inputType: "path",      description: "802.11 WEP/WPA/WPA2 key cracker from handshake captures" },
        { id: "airodump-ng",   display: "Airodump-ng",    category: "Wireless",      inputType: "interface", description: "Packet sniffer & live wireless network monitor" },
        { id: "airmon-ng",     display: "Airmon-ng",      category: "Wireless",      inputType: "interface", description: "Manage wireless card monitor mode & check processes" },
        { id: "wifite",        display: "Wifite",         category: "Wireless",      inputType: "interface", description: "Automated wireless auditor (attacks WEP/WPA/PMKID)" },
        { id: "kismet",        display: "Kismet",         category: "Wireless",      inputType: "interface", description: "Wireless network detector, sniffer & wardriving IDS" },
        { id: "jadx",          display: "Jadx Decompiler", category: "Reverse Eng",  inputType: "path",      description: "Dex to Java decompiler and APK source extractor" },
        { id: "apktool",       display: "Apktool",         category: "Reverse Eng",  inputType: "path",      description: "Disassemble Android APK resources, manifest & smali" },
        { id: "binwalk",       display: "Binwalk",         category: "Reverse Eng",  inputType: "path",      description: "Firmware analysis tool & embedded signature scanner" },
        { id: "radare2",       display: "Radare2 (r2)",    category: "Reverse Eng",  inputType: "path",      description: "UNIX-like RE framework (binary headers, symbols, strings)" },

        // ── Wapiti Dedicated Category (All 34 Modules + Master) ──────────────────
        { id: "wapiti", display: "Wapiti (All 34 Modules)", category: "Wapiti", inputType: "url", description: "Full web vulnerability scanner loaded with all 34 attack modules (-m all)" },
        { id: "wapiti_sql", display: "Wapiti: SQL Injection", category: "Wapiti", inputType: "url", description: "Detect SQL & XPath injection via error-based and boolean blind techniques" },
        { id: "wapiti_timesql", display: "Wapiti: Time-Based SQLi", category: "Wapiti", inputType: "url", description: "Detect blind SQL injection vulnerabilities using time-delay analysis" },
        { id: "wapiti_xss", display: "Wapiti: Reflected XSS", category: "Wapiti", inputType: "url", description: "Detect reflected Cross-Site Scripting flaws in query parameters and forms" },
        { id: "wapiti_permanentxss", display: "Wapiti: Stored XSS", category: "Wapiti", inputType: "url", description: "Detect stored/persistent Cross-Site Scripting vulnerabilities on the web server" },
        { id: "wapiti_exec", display: "Wapiti: Command Execution", category: "Wapiti", inputType: "url", description: "Detect Remote Code Execution (RCE) and system command injection vectors" },
        { id: "wapiti_file", display: "Wapiti: File Inclusion", category: "Wapiti", inputType: "url", description: "Detect Path Traversal and Local/Remote File Inclusion (LFI/RFI) flaws" },
        { id: "wapiti_ssrf", display: "Wapiti: SSRF", category: "Wapiti", inputType: "url", description: "Detect Server-Side Request Forgery vulnerabilities via callback endpoints" },
        { id: "wapiti_xxe", display: "Wapiti: XXE Injection", category: "Wapiti", inputType: "url", description: "Detect XML External Entity injection and sensitive file reading vulnerabilities" },
        { id: "wapiti_ldap", display: "Wapiti: LDAP Injection", category: "Wapiti", inputType: "url", description: "Detect error-based and boolean-based LDAP query injection vulnerabilities" },
        { id: "wapiti_upload", display: "Wapiti: Arbitrary Upload", category: "Wapiti", inputType: "url", description: "Detect unrestricted file upload flaws for web shell deployment" },
        { id: "wapiti_log4shell", display: "Wapiti: Log4Shell", category: "Wapiti", inputType: "url", description: "Scan for Apache Log4Shell remote code execution vulnerability (CVE-2021-44228)" },
        { id: "wapiti_spring4shell", display: "Wapiti: Spring4Shell", category: "Wapiti", inputType: "url", description: "Detect Spring Framework Remote Code Execution vulnerability (CVE-2022-22965)" },
        { id: "wapiti_shellshock", display: "Wapiti: Shellshock", category: "Wapiti", inputType: "url", description: "Detect GNU Bash Shellshock execution vulnerability (CVE-2014-6271)" },
        { id: "wapiti_takeover", display: "Wapiti: Subdomain Takeover", category: "Wapiti", inputType: "url", description: "Detect dangling DNS / CNAME records vulnerable to subdomain hijacking" },
        { id: "wapiti_crlf", display: "Wapiti: CRLF Injection", category: "Wapiti", inputType: "url", description: "Detect Carriage Return Line Feed (CRLF) / HTTP response splitting" },
        { id: "wapiti_csrf", display: "Wapiti: CSRF Flaws", category: "Wapiti", inputType: "url", description: "Detect forms missing anti-Cross-Site Request Forgery protections" },
        { id: "wapiti_redirect", display: "Wapiti: Open Redirect", category: "Wapiti", inputType: "url", description: "Detect unvalidated URL redirection and open phishing relays" },
        { id: "wapiti_htaccess", display: "Wapiti: Htaccess Bypass", category: "Wapiti", inputType: "url", description: "Attempt bypass of resource access controls using custom HTTP methods" },
        { id: "wapiti_brute_login_form", display: "Wapiti: Brute Login Form", category: "Wapiti", inputType: "url", description: "Brute-force authentication forms with common weak credentials dictionary" },
        { id: "wapiti_backup", display: "Wapiti: Backup Files", category: "Wapiti", inputType: "url", description: "Uncover backup copies of scripts and sensitive archives on the web server" },
        { id: "wapiti_buster", display: "Wapiti: Buster Paths", category: "Wapiti", inputType: "url", description: "Brute-force directories and hidden files (DirBuster-style exploration)" },
        { id: "wapiti_methods", display: "Wapiti: HTTP Methods", category: "Wapiti", inputType: "url", description: "Audit dangerous and uncommon HTTP methods (PUT, DELETE, OPTIONS, TRACE)" },
        { id: "wapiti_ssl", display: "Wapiti: SSL/TLS Security", category: "Wapiti", inputType: "url", description: "Evaluate SSL/TLS certificate configuration and cipher suite vulnerabilities" },
        { id: "wapiti_nikto", display: "Wapiti: Nikto Database", category: "Wapiti", inputType: "url", description: "Brute-force dangerous scripts and known flaws using Nikto rules database" },
        { id: "wapiti_cms", display: "Wapiti: CMS Detection", category: "Wapiti", inputType: "url", description: "Detect CMS type and version (WordPress, Joomla, Drupal, PrestaShop, SPIP)" },
        { id: "wapiti_wp_enum", display: "Wapiti: WordPress Enum", category: "Wapiti", inputType: "url", description: "Enumerate WordPress plugins, themes, and vulnerable component versions" },
        { id: "wapiti_wapp", display: "Wapiti: Wappalyzer", category: "Wapiti", inputType: "url", description: "Identify web technologies using Wappalyzer and map to known CVEs" },
        { id: "wapiti_htp", display: "Wapiti: HashThePlanet", category: "Wapiti", inputType: "url", description: "Fingerprint web server technologies using HashThePlanet database" },
        { id: "wapiti_network_device", display: "Wapiti: Network Devices", category: "Wapiti", inputType: "url", description: "Detect network appliances, Citrix, Fortinet, Checkpoint, and Palo Alto" },
        { id: "wapiti_printer", display: "Wapiti: Printers", category: "Wapiti", inputType: "url", description: "Detect networked printer interfaces and embedded firmware disclosure" },
        { id: "wapiti_cookieflags", display: "Wapiti: Cookie Flags", category: "Wapiti", inputType: "url", description: "Audit Secure, HttpOnly, and SameSite flags on session cookies" },
        { id: "wapiti_csp", display: "Wapiti: CSP Evaluator", category: "Wapiti", inputType: "url", description: "Evaluate Content Security Policy (CSP) presence and configuration weaknesses" },
        { id: "wapiti_http_headers", display: "Wapiti: Security Headers", category: "Wapiti", inputType: "url", description: "Audit HTTP security headers (HSTS, X-Frame-Options, X-Content-Type-Options)" },
        { id: "wapiti_https_redirect", display: "Wapiti: HTTPS Redirect", category: "Wapiti", inputType: "url", description: "Verify strict redirection from insecure HTTP connections to HTTPS" }
    ]

    property var toolEnabled: ({
        "sherlock":     true,
        "theharvester": true,
        "sublist3r":    true,
        "nmap":         true,
        "rustscan":     true,
        "nikto":        true,
        "whatweb":      true,
        "sqlmap":       true,
        "wapiti":       true,
        "metasploit":   true,
        "msf_rpc":      true,
        "msfvenom":     true,
        "msf_listener": false,
        "nuclei":       true,
        "gobuster":     true,
        "netexec":      true,
        "enum4linux-ng": true,
        "gitleaks":     true,
        "scoutsuite":   true,
        "prowler":      true,
        "pacu":         true,
        "trivy":        true,
        "checkov":      true,
        "aircrack-ng":  true,
        "airodump-ng":  true,
        "airmon-ng":    true,
        "wifite":       true,
        "kismet":       true,
        "jadx":         true,
        "apktool":      true,
        "binwalk":      true,
        "radare2":      true
    })

    property var categories: ["OSINT", "Network", "Web", "Vulnerability", "Wapiti", "Cloud", "Wireless", "Reverse Eng", "Exploit/Audit"]
    property var expandedCategories: ({ "OSINT": false, "Network": false, "Web": false, "Vulnerability": false, "Wapiti": false, "Cloud": false, "Wireless": false, "Reverse Eng": false, "Exploit/Audit": false })

    // Resolve backend path once at startup — avoids URL-encoding issues with Qt.resolvedUrl
    property string backendPath: ""

    // ── Backend Process ────────────────────────────────────────────────────────
    Process {
        id: backendProcess

        onRunningChanged: {
            if (!running) {
                isRunning = false
                consoleView.info("Backend process finished.")
            }
        }

        // SplitParser fires onRead once per complete line (delimiter = \n by default).
        // Do NOT buffer here — data is already one complete JSON line.
        stdout: SplitParser {
            onRead: function(data) {
                var line = data.trim()
                if (line.length === 0) return
                try {
                    var ev = JSON.parse(line)
                    handleEvent(ev)
                } catch (e) {
                    consoleView.output("raw", line)
                }
            }
        }

        stderr: SplitParser {
            onRead: function(data) {
                var trimmed = data.trim()
                if (trimmed.length > 0)
                    consoleView.warn(trimmed)
            }
        }
    }

    // ── Status check process ───────────────────────────────────────────────────
    Process {
        id: statusProcess

        onRunningChanged: {
            if (!running) {
                consoleView.info("Tool status check complete.")
            }
        }

        stdout: SplitParser {
            onRead: function(data) {
                var line = data.trim()
                if (line.length === 0) return
                try {
                    var ev = JSON.parse(line)
                    if (ev.event === "status") {
                        var tools = ev.tools
                        var keys  = Object.keys(tools)

                        // Update toolStatusModel (ListModel — reliably reactive)
                        for (var i = 0; i < keys.length; i++) {
                            setToolStatus(keys[i], tools[keys[i]] === true)
                        }

                        var installed = keys.filter(function(k) { return tools[k] })
                        var missing   = keys.filter(function(k) { return !tools[k] })
                        missingTools  = missing

                        consoleView.info("Installed: " + (installed.length > 0 ? installed.join(", ") : "none"))
                        if (missing.length > 0)
                            consoleView.warn("Missing: " + missing.join(", ") + " — will auto-install when used.")
                    }
                } catch (e) {
                    consoleView.warn("Status parse error: " + e + " | raw: " + line)
                }
            }
        }

        stderr: SplitParser {
            onRead: function(data) {
                var trimmed = data.trim()
                if (trimmed.length > 0)
                    consoleView.warn("Status stderr: " + trimmed)
            }
        }
    }

    // ── Event Handler ──────────────────────────────────────────────────────────
    function handleEvent(ev) {
        switch (ev.event) {

        case "audit_start":
            consoleView.info("━━ AUDIT STARTED ━━  Target: " + ev.target)
            break

        case "audit_done":
            consoleView.success("━━ AUDIT COMPLETE ━━")
            isRunning = false
            break

        case "recon_result":
            if (ev.local_ip && ev.local_ip !== "127.0.0.1") {
                if (!targetIp || targetIp.trim() === "") {
                    targetIp = ev.local_ip
                    consoleView.info("Auto-detected local IP: " + ev.local_ip + " (set as Target IP)")
                }
            }
            break

        case "tool_start":
            consoleView.currentTool = ev.tool
            consoleView.addTab(ev.tool, displayFor(ev.tool))
            consoleView.setTabStatus(ev.tool, "running")
            consoleView.info("Starting " + ev.tool + "…")
            setToolState(ev.tool, "running")
            reportView.addResult(ev.tool, displayFor(ev.tool), "running", [])
            break

        case "tool_output":
            consoleView.output(ev.tool, ev.line)
            appendToolLine(ev.tool, ev.line)
            reportView.appendLine(ev.tool, ev.line)
            break

        case "tool_done":
            var ok = (ev.exit_code === 0)
            consoleView.currentTool = ""
            consoleView.setTabStatus(ev.tool, ok ? "done" : "failed")
            if (ok) {
                consoleView.success(ev.tool + " finished successfully.")
                setToolState(ev.tool, "done")
                reportView.updateStatus(ev.tool, "done")
            } else {
                consoleView.error(ev.tool + " exited with code " + ev.exit_code)
                setToolState(ev.tool, "failed")
                reportView.updateStatus(ev.tool, "failed")
            }
            break

        case "tool_error":
            consoleView.error("[" + ev.tool + "] " + ev.message)
            consoleView.setTabStatus(ev.tool, "failed")
            setToolState(ev.tool, "failed")
            reportView.updateStatus(ev.tool, "failed")
            break

        case "tool_missing":
            consoleView.warn("[" + ev.tool + "] not found — attempting auto-install…")
            break

        case "install_start":
            consoleView.info("Installing " + ev.tool + "…")
            break

        case "install_done":
            if (ev.success) {
                consoleView.success(ev.tool + " installed successfully.")
                setToolStatus(ev.tool, true)
                // Remove from missingTools
                var idx = missingTools.indexOf(ev.tool)
                if (idx !== -1) {
                    var m = missingTools.slice()
                    m.splice(idx, 1)
                    missingTools = m
                }
            } else {
                consoleView.error("Failed to install " + ev.tool + ": " + (ev.message || ""))
            }
            break

        default:
            break
        }
    }

    // ── State helpers ──────────────────────────────────────────────────────────
    function setToolState(toolId, state) {
        var s = Object.assign({}, toolRunState)
        s[toolId] = state
        toolRunState = s
    }

    function appendToolLine(toolId, line) {
        var lines = Object.assign({}, toolLines)
        if (!lines[toolId]) lines[toolId] = []
        lines[toolId] = lines[toolId].concat([line])
        toolLines = lines
    }

    function displayFor(toolId) {
        if (toolId === "network_recon") return "Network Recon"
        for (var i = 0; i < toolMeta.length; i++)
            if (toolMeta[i].id === toolId) return toolMeta[i].display
        return toolId
    }

    function enabledTools() {
        return toolMeta.filter(function(t) { return toolEnabled[t.id] }).map(function(t) { return t.id })
    }

    function hasAnyTarget() {
        return (targetIp.trim() !== "" ||
                targetDomain.trim() !== "" ||
                targetUrl.trim() !== "" ||
                targetCloud.trim() !== "" ||
                targetPath.trim() !== "" ||
                targetUsername.trim() !== "" ||
                targetInterface.trim() !== "")
    }

    function getPrimaryTarget() {
        if (targetIp.trim()) return targetIp.trim()
        if (targetDomain.trim()) return targetDomain.trim()
        if (targetUrl.trim()) return targetUrl.trim()
        if (targetCloud.trim()) return targetCloud.trim()
        if (targetPath.trim()) return targetPath.trim()
        if (targetUsername.trim()) return targetUsername.trim()
        if (targetInterface.trim()) return targetInterface.trim()
        return ""
    }

    function targetForTool(toolId) {
        for (var i = 0; i < toolMeta.length; i++) {
            if (toolMeta[i].id === toolId) {
                var itype = (toolMeta[i].inputType || "ip").toLowerCase()
                if (itype === "ip" && targetIp.trim()) return targetIp.trim()
                if (itype === "domain" && targetDomain.trim()) return targetDomain.trim()
                if (itype === "url" && targetUrl.trim()) return targetUrl.trim()
                if (itype === "cloud" && targetCloud.trim()) return targetCloud.trim()
                if (itype === "path" && targetPath.trim()) return targetPath.trim()
                if (itype === "user" || itype === "username") {
                    if (targetUsername.trim()) return targetUsername.trim()
                }
                if (itype === "interface" || itype === "wlan") {
                    if (targetInterface.trim()) return targetInterface.trim()
                    return "wlp0s20f3"
                }

                // Fallbacks
                if (itype === "url") {
                    if (targetDomain.trim()) return "https://" + targetDomain.trim()
                    if (targetIp.trim()) return "http://" + targetIp.trim()
                }
                if (itype === "domain") {
                    if (targetUrl.trim()) {
                        var clean = targetUrl.trim().replace(/^https?:\/\//i, '').split('/')[0].split(':')[0]
                        if (clean) return clean
                    }
                    if (targetIp.trim()) return targetIp.trim()
                }
                if (itype === "ip") {
                    if (targetDomain.trim()) return targetDomain.trim()
                }
                if (itype === "cloud") return "aws"
                if (itype === "path") return "."
                if (itype === "interface") return "wlp0s20f3"
                break
            }
        }
        return getPrimaryTarget()
    }

    // ── Actions ────────────────────────────────────────────────────────────────
    function runSelectedTools(toolIds) {
        if (!hasAnyTarget()) {
            consoleView.error("Please enter a target (IP, Domain, URL, Cloud, Path, Username, or Interface).")
            return
        }
        if (isRunning) {
            consoleView.warn("Already running. Please wait.")
            return
        }
        if (toolIds.length === 0) {
            consoleView.warn("No tools selected.")
            return
        }

        isRunning = true
        toolRunState = {}
        toolLines    = {}
        reportView.clear()
        consoleView.resetTabs()

        var targetsObj = {
            "ip": targetIp.trim(),
            "domain": targetDomain.trim(),
            "url": targetUrl.trim(),
            "cloud": targetCloud.trim(),
            "path": targetPath.trim(),
            "username": targetUsername.trim(),
            "interface": targetInterface.trim()
        }
        var primary = getPrimaryTarget()

        consoleView.system("Launching: " + toolIds.join(", ") + " (Primary Target: " + primary + ")")

        var cmd = [
            "python3", backendPath, "audit", primary,
            "--targets", JSON.stringify(targetsObj),
            "--tools"
        ]
        backendProcess.command = cmd.concat(toolIds)
        backendProcess.running = true
    }

    function runSingleTool(toolId) {
        var specificTarget = targetForTool(toolId)
        if (!specificTarget) {
            consoleView.error("Please enter a target for " + toolId + ".")
            return
        }
        if (isRunning) {
            consoleView.warn("A scan is already running.")
            return
        }

        isRunning = true
        toolRunState = {}
        toolLines    = {}
        reportView.clear()
        consoleView.resetTabs()
        consoleView.addTab(toolId, displayFor(toolId))

        consoleView.system("Launching " + toolId + " on " + specificTarget)

        var cmd = ["python3", backendPath, "run", toolId, specificTarget]
        backendProcess.command = cmd
        backendProcess.running = true
    }

    function checkStatus() {
        var cmd = ["python3", backendPath, "status"]
        consoleView.system("Checking tool status…")
        statusProcess.command = cmd
        statusProcess.running = true
    }

    function runNetworkRecon() {
        if (isRunning) {
            consoleView.warn("A scan or task is already running. Please wait.")
            return
        }

        isRunning = true
        toolRunState = {}
        toolLines    = {}
        reportView.clear()
        consoleView.resetTabs()
        consoleView.addTab("network_recon", "Network Recon")
        activeTab = "console"

        var targetIpOrSubnet = targetIp.trim()
        consoleView.system("Launching Network Recon" + (targetIpOrSubnet ? " on " + targetIpOrSubnet : " (Local Subnet Auto-Discovery)") + "…")

        var cmd = ["python3", backendPath, "recon"]
        if (targetIpOrSubnet) {
            cmd.push(targetIpOrSubnet)
        }
        backendProcess.command = cmd
        backendProcess.running = true
    }

    // ── Window ─────────────────────────────────────────────────────────────────
    FloatingWindow {
        id: mainWindow
        title: "AuditX"
        implicitWidth: 1100
        implicitHeight: 720
        minimumSize: Qt.size(800, 560)
        visible: true

        // ── Background
        Rectangle {
            anchors.fill: parent
            color: "#050505"
        }

        // ── Root layout
        Column {
            anchors { fill: parent; margins: 16 }
            spacing: 14

            // ── Title bar
            Row {
                width: parent.width
                height: 42
                spacing: 12

                Row {
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: 10

                    Rectangle {
                        width: 32; height: 32; radius: 6
                        color: "#0a0a0a"
                        border.color: "#222"; border.width: 1
                        anchors.verticalCenter: parent.verticalCenter
                        Text {
                            anchors.centerIn: parent
                            text: "⬡"; font.pixelSize: 16; color: "#0066ff"
                        }
                    }

                    Column {
                        anchors.verticalCenter: parent.verticalCenter
                        spacing: 2
                        Text {
                            text: "AuditX"
                            font.pixelSize: 18; font.weight: 700
                            font.family: "JetBrains Mono, Fira Mono, monospace"
                            color: "#ffffff"; font.letterSpacing: 1
                        }
                        Text {
                            text: "Security Audit Platform"
                            font.pixelSize: 10; color: "#888888"
                            font.family: "JetBrains Mono, Fira Mono, monospace"
                        }
                    }
                }

                Item { width: 1; height: 1 }

                Row {
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: 6
                    Rectangle {
                        width: 8; height: 8; radius: 4
                        anchors.verticalCenter: parent.verticalCenter
                        color: isRunning ? "#0066ff" : "#333333"
                        SequentialAnimation on opacity {
                            running: isRunning; loops: Animation.Infinite
                            NumberAnimation { to: 0.3; duration: 600 }
                            NumberAnimation { to: 1.0; duration: 600 }
                        }
                    }
                    Text {
                        anchors.verticalCenter: parent.verticalCenter
                        text: isRunning ? "SCANNING" : "IDLE"
                        font.pixelSize: 10
                        font.family: "JetBrains Mono, Fira Mono, monospace"
                        font.weight: 500
                        color: isRunning ? "#0066ff" : "#555555"
                        Behavior on color { ColorAnimation { duration: 200 } }
                    }
                }
            }

            // ── Target Configuration Bar (Multi-Type Input)
            TargetBar {
                id: targetBar
                width: parent.width
                targetIp: root.targetIp
                targetDomain: root.targetDomain
                targetUrl: root.targetUrl
                targetCloud: root.targetCloud
                targetPath: root.targetPath
                targetUsername: root.targetUsername
                targetInterface: root.targetInterface
                isRunning: root.isRunning

                onTargetIpChanged: root.targetIp = targetIp
                onTargetDomainChanged: root.targetDomain = targetDomain
                onTargetUrlChanged: root.targetUrl = targetUrl
                onTargetCloudChanged: root.targetCloud = targetCloud
                onTargetPathChanged: root.targetPath = targetPath
                onTargetUsernameChanged: root.targetUsername = targetUsername
                onTargetInterfaceChanged: root.targetInterface = targetInterface

                onRunSelectedRequested: {
                    activeTab = "console"
                    runSelectedTools(enabledTools())
                }

                onFullAuditRequested: {
                    activeTab = "console"
                    runSelectedTools(toolMeta.map(function(t) { return t.id }))
                }

                onCheckStatusRequested: {
                    checkStatus()
                }

                onNetworkReconRequested: {
                    runNetworkRecon()
                }
            }

            // ── Main content area
            Row {
                width: parent.width
                height: parent.height - 42 - targetBar.height - 28
                spacing: 14

                // ── Left: Tool selection panel
                Column {
                    width: 230
                    height: parent.height
                    spacing: 10

                    Row {
                        spacing: 8
                        Text { text: "TOOLS"; font.pixelSize: 10; font.weight: 700; font.family: "JetBrains Mono, Fira Mono, monospace"; color: "#444444"; font.letterSpacing: 2 }
                        Rectangle { width: 1; height: 12; color: "#222222"; anchors.verticalCenter: parent.verticalCenter }
                        Text { text: enabledTools().length + " selected"; font.pixelSize: 10; font.family: "JetBrains Mono, Fira Mono, monospace"; color: "#666666" }
                    }

                    ScrollView {
                        width: 230
                        height: parent.height - 26
                        clip: true
                        ScrollBar.horizontal.policy: ScrollBar.AlwaysOff
                        ScrollBar.vertical: ScrollBar {
                            policy: ScrollBar.AsNeeded
                            contentItem: Rectangle { implicitWidth: 3; radius: 2; color: "#222222" }
                        }

                        Column {
                            width: 220
                            spacing: 8

                            Repeater {
                                model: categories
                                Column {
                                    width: 220
                                    spacing: 4
                                    property string categoryName: modelData

                                    // Category Folder Header
                                    Rectangle {
                                        width: 220; height: 32; radius: 4
                                        color: catHover.containsMouse ? "#111111" : "#0a0a0a"
                                        border.color: "transparent"; border.width: 0
                                        Behavior on color { ColorAnimation { duration: 150 } }
                                        
                                        Row {
                                            anchors { fill: parent; leftMargin: 12; rightMargin: 12 }
                                            spacing: 8
                                            Text {
                                                text: expandedCategories[categoryName] ? "▼" : "▶"
                                                color: "#0066ff"
                                                font.pixelSize: 9
                                                anchors.verticalCenter: parent.verticalCenter
                                            }
                                            Text {
                                                text: categoryName
                                                font.weight: 600; color: "#ffffff"; font.pixelSize: 11
                                                anchors.verticalCenter: parent.verticalCenter
                                                font.family: "JetBrains Mono, Fira Mono, monospace"
                                                font.letterSpacing: 0.5
                                            }
                                        }
                                        MouseArea {
                                            id: catHover
                                            anchors.fill: parent; cursorShape: Qt.PointingHandCursor
                                            hoverEnabled: true
                                            onClicked: {
                                                var s = Object.assign({}, expandedCategories)
                                                s[categoryName] = !s[categoryName]
                                                expandedCategories = s
                                            }
                                        }
                                    }

                                    // Tools inside category
                                    Column {
                                        width: 220
                                        spacing: 6
                                        visible: expandedCategories[categoryName]
                                        
                                        Repeater {
                                            // .filter is standard JS and supported in QML's V4 engine
                                            model: toolMeta.filter(function(t) { return t.category === categoryName })
                                            
                                            ToolCard {
                                                width: 220
                                                toolName:    modelData.id
                                                displayName: modelData.display
                                                category:    modelData.category
                                                description: modelData.description
                                                inputType:   modelData.inputType || ""
                                                isEnabled:   toolEnabled[modelData.id] || false
                                                isInstalled: {
                                                    var _dep = toolStatusModel.count
                                                    return toolIsInstalled(modelData.id)
                                                }
                                                isRunning:   (toolRunState && toolRunState[modelData.id] === "running")
                                                isDone:      (toolRunState && toolRunState[modelData.id] === "done")
                                                hasFailed:   (toolRunState && toolRunState[modelData.id] === "failed")

                                                onToggled: function(enabled) {
                                                    var s = Object.assign({}, toolEnabled)
                                                    s[modelData.id] = enabled
                                                    toolEnabled = s
                                                }
                                            }
                                        }
                                    }
                                }
                            }

                            Text {
                                visible: missingTools.length > 0
                                text: "Missing: " + missingTools.join(", ")
                                font.pixelSize: 10; color: "#ff8080"; wrapMode: Text.Wrap; width: 210
                            }

                            Row {
                                spacing: 8; width: parent.width
                                Repeater {
                                    model: [["All", true], ["None", false]]
                                    Rectangle {
                                        width: 100; height: 28; radius: 4
                                        color: selHover.containsMouse ? "#111111" : "#0a0a0a"
                                        border.color: "#222222"; border.width: 1
                                        Text { anchors.centerIn: parent; text: modelData[0]; font.pixelSize: 10; font.family: "JetBrains Mono, Fira Mono, monospace"; color: "#888888" }
                                        MouseArea {
                                            id: selHover; anchors.fill: parent; hoverEnabled: true
                                            cursorShape: Qt.PointingHandCursor
                                            onClicked: {
                                                var val = modelData[1]
                                                var s = {}
                                                toolMeta.forEach(function(t) { s[t.id] = val })
                                                toolEnabled = s
                                            }
                                        }
                                    }
                                }
                            }
                        }
                    }
                }

                // ── Right: Output panel
                Column {
                    width: parent.width - 230 - 14
                    height: parent.height
                    spacing: 10

                    Row {
                        spacing: 4
                        Repeater {
                            model: [["console", "Console"], ["report", "Report"], ["terminal", "Terminal"]]
                            Rectangle {
                                width: 100; height: 28; radius: 4
                                color: activeTab === modelData[0] ? "#111111" : "#0a0a0a"
                                border.color: activeTab === modelData[0] ? "#0066ff" : "#222222"
                                border.width: 1
                                Behavior on color { ColorAnimation { duration: 150 } }
                                Text {
                                    anchors.centerIn: parent; text: modelData[1]
                                    font.pixelSize: 11
                                    font.weight: activeTab === modelData[0] ? 600 : 400
                                    font.family: "JetBrains Mono, Fira Mono, monospace"
                                    color: activeTab === modelData[0] ? "#0066ff" : "#666666"
                                    Behavior on color { ColorAnimation { duration: 150 } }
                                }
                                MouseArea {
                                    anchors.fill: parent; cursorShape: Qt.PointingHandCursor
                                    onClicked: activeTab = modelData[0]
                                }
                            }
                        }
                    }

                    Item {
                        width: parent.width
                        height: parent.height - 38

                        ConsoleView {
                            id: consoleView
                            anchors.fill: parent
                            visible: activeTab === "console"
                            opacity: activeTab === "console" ? 1 : 0
                            Behavior on opacity { NumberAnimation { duration: 150 } }
                        }

                        ReportView {
                            id: reportView
                            anchors.fill: parent
                            target: target
                            visible: activeTab === "report"
                            opacity: activeTab === "report" ? 1 : 0
                            Behavior on opacity { NumberAnimation { duration: 150 } }
                        }

                        TerminalView {
                            id: terminalView
                            anchors.fill: parent
                            backendPath: root.backendPath
                            targetIp: root.targetIp
                            targetDomain: root.targetDomain
                            targetUrl: root.targetUrl
                            targetCloud: root.targetCloud
                            targetPath: root.targetPath
                            targetUsername: root.targetUsername
                            targetInterface: root.targetInterface
                            visible: activeTab === "terminal"
                            opacity: activeTab === "terminal" ? 1 : 0
                            Behavior on opacity { NumberAnimation { duration: 150 } }
                        }
                    }
                }
            }
        }
    }

    // ── Boot ───────────────────────────────────────────────────────────────────
    Component.onCompleted: {
        // Resolve backend path safely without Qt.resolvedUrl URL-encoding issues
        var url = Qt.resolvedUrl("backend/audit.py").toString()
        // Strip file:// prefix correctly (file:///home/... → /home/...)
        if (url.startsWith("file:///"))
            backendPath = url.slice(7)   // keeps leading /
        else if (url.startsWith("file://"))
            backendPath = url.slice(7)
        else
            backendPath = url

        consoleView.system("AuditX initialized. Backend: " + backendPath)
        consoleView.system("Checking tool availability…")
        checkStatus()
    }
}
