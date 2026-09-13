import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import "components"

// ─── AuditX — Security Audit Tool (Quickshell / QML) ─────────────────────────
ShellRoot {

    // ── State ──────────────────────────────────────────────────────────────────
    property string target: ""
    property bool   isRunning: false
    property string activeTab: "console"   // "console" | "report"
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
        { id: "sherlock",     display: "Sherlock",      category: "OSINT",   description: "Username search across hundreds of platforms" },
        { id: "theharvester", display: "theHarvester",  category: "OSINT",   description: "Email, subdomain & IP harvesting" },
        { id: "sublist3r",    display: "Sublist3r",     category: "OSINT",   description: "Fast subdomain enumeration" },
        { id: "nmap",         display: "Nmap",          category: "Network", description: "Port scanning & service detection" },
        { id: "rustscan",     display: "RustScan",      category: "Network", description: "Ultra-fast port scanner" },
        { id: "nikto",        display: "Nikto",         category: "Web",     description: "Web server vulnerability scanner" },
        { id: "whatweb",      display: "WhatWeb",       category: "Web",           description: "Web technology fingerprinting" },
        { id: "sqlmap",       display: "SQLMap",        category: "Web",           description: "SQL injection detection & exploitation" },
        { id: "metasploit",   display: "Metasploit Aux", category: "Network",       description: "MSF service & SMB fingerprinting scanner" },
        { id: "msf_rpc",      display: "Metasploit RPC", category: "Exploit/Audit", description: "MSF RPC API orchestrator via msfrpcd" },
        { id: "msfvenom",     display: "Msfvenom",      category: "Exploit/Audit", description: "Generate Linux meterpreter reverse TCP payload" },
        { id: "msf_listener", display: "MSF Listener",  category: "Exploit/Audit", description: "Start reverse TCP handler (linux/x64/meterpreter)" },
        { id: "nuclei",       display: "Nuclei",        category: "Vulnerability", description: "Fast template-based vulnerability scanner" },
        { id: "gobuster",     display: "Gobuster",      category: "Web",           description: "Directory and file fuzzing tool" },
        { id: "netexec",      display: "NetExec",       category: "Network",       description: "AD / SMB environment pentesting tool" },
        { id: "enum4linux-ng", display: "Enum4Linux-NG", category: "Network",      description: "Windows / Samba enumeration tool" },
        { id: "gitleaks",     display: "Gitleaks",      category: "OSINT",         description: "Detect secrets and passwords in repositories" }
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
        "metasploit":   true,
        "msf_rpc":      true,
        "msfvenom":     true,
        "msf_listener": false,
        "nuclei":       true,
        "gobuster":     true,
        "netexec":      true,
        "enum4linux-ng": true,
        "gitleaks":     true
    })

    property var categories: ["OSINT", "Network", "Web", "Vulnerability", "Exploit/Audit"]
    property var expandedCategories: ({ "OSINT": true, "Network": true, "Web": true, "Vulnerability": true, "Exploit/Audit": true })

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

        case "tool_start":
            consoleView.currentTool = ev.tool
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
        for (var i = 0; i < toolMeta.length; i++)
            if (toolMeta[i].id === toolId) return toolMeta[i].display
        return toolId
    }

    function enabledTools() {
        return toolMeta.filter(function(t) { return toolEnabled[t.id] }).map(function(t) { return t.id })
    }

    // ── Actions ────────────────────────────────────────────────────────────────
    function runSelectedTools(toolIds) {
        if (!target.trim()) {
            consoleView.error("Please enter a target first.")
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

        consoleView.system("Launching: " + toolIds.join(", "))

        var cmd = ["python3", backendPath, "audit", target.trim(), "--tools"]
        backendProcess.command = cmd.concat(toolIds)
        backendProcess.running = true
    }

    function runSingleTool(toolId) {
        if (!target.trim()) {
            consoleView.error("Please enter a target first.")
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

        var cmd = ["python3", backendPath, "run", toolId, target.trim()]
        backendProcess.command = cmd
        backendProcess.running = true
    }

    function checkStatus() {
        var cmd = ["python3", backendPath, "status"]
        consoleView.system("Checking tool status…")
        statusProcess.command = cmd
        statusProcess.running = true
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

            // ── Target input + action buttons
            Row {
                width: parent.width
                height: 46
                spacing: 10

                Rectangle {
                    height: 46
                    width: parent.width - runSelectedBtn.width - fullAuditBtn.width - statusBtn.width - 40
                    radius: 6
                    color: "#0a0a0a"
                    border.color: targetInput.activeFocus ? "#0066ff" : "#222222"
                    border.width: 1
                    Behavior on border.color { ColorAnimation { duration: 150 } }

                    Row {
                        anchors { left: parent.left; right: parent.right; verticalCenter: parent.verticalCenter; leftMargin: 14; rightMargin: 14 }
                        spacing: 8
                        Text { text: "▶"; font.pixelSize: 10; color: "#555555"; anchors.verticalCenter: parent.verticalCenter }
                        TextInput {
                            id: targetInput
                            width: parent.width - 24
                            font.pixelSize: 13
                            font.family: "JetBrains Mono, Fira Mono, monospace"
                            color: "#ffffff"; selectionColor: "#0066ff"
                            text: target
                            onTextChanged: target = text
                            Keys.onReturnPressed: {
                                if (event.modifiers & Qt.ControlModifier)
                                    runSelectedTools(enabledTools())
                            }
                            Text {
                                visible: targetInput.text.length === 0
                                text: "Enter target: IP address, domain, URL, or username…"
                                font: targetInput.font; color: "#444444"
                                anchors.verticalCenter: parent.verticalCenter
                            }
                        }
                    }
                }

                // Run Selected
                Rectangle {
                    id: runSelectedBtn
                    height: 46; width: 140; radius: 6
                    color: runSelectedHover.containsMouse && !isRunning ? "#0066ff" : "#0047b3"
                    border.color: "transparent"; border.width: 0
                    opacity: isRunning ? 0.5 : 1
                    Behavior on color { ColorAnimation { duration: 120 } }
                    Column {
                        anchors.centerIn: parent; spacing: 2
                        Text { anchors.horizontalCenter: parent.horizontalCenter; text: "Run Selected"; font.pixelSize: 12; font.weight: 600; font.family: "JetBrains Mono, Fira Mono, monospace"; color: "#ffffff" }
                        Text { anchors.horizontalCenter: parent.horizontalCenter; text: "Ctrl+Enter"; font.pixelSize: 9; font.family: "JetBrains Mono, Fira Mono, monospace"; color: "#bbccff" }
                    }
                    MouseArea {
                        id: runSelectedHover; anchors.fill: parent; hoverEnabled: true
                        cursorShape: isRunning ? Qt.ArrowCursor : Qt.PointingHandCursor
                        onClicked: { if (!isRunning) { activeTab = "console"; runSelectedTools(enabledTools()) } }
                    }
                }

                // Full Audit
                Rectangle {
                    id: fullAuditBtn
                    height: 46; width: 130; radius: 6
                    color: fullAuditHover.containsMouse && !isRunning ? "#111111" : "#0a0a0a"
                    border.color: isRunning ? "#111" : "#222222"; border.width: 1
                    opacity: isRunning ? 0.5 : 1
                    Behavior on color { ColorAnimation { duration: 120 } }
                    Column {
                        anchors.centerIn: parent; spacing: 2
                        Text { anchors.horizontalCenter: parent.horizontalCenter; text: "Full Audit"; font.pixelSize: 12; font.weight: 600; font.family: "JetBrains Mono, Fira Mono, monospace"; color: "#0066ff" }
                        Text { anchors.horizontalCenter: parent.horizontalCenter; text: "All tools"; font.pixelSize: 9; font.family: "JetBrains Mono, Fira Mono, monospace"; color: "#555555" }
                    }
                    MouseArea {
                        id: fullAuditHover; anchors.fill: parent; hoverEnabled: true
                        cursorShape: isRunning ? Qt.ArrowCursor : Qt.PointingHandCursor
                        onClicked: { if (!isRunning) { activeTab = "console"; runSelectedTools(toolMeta.map(function(t) { return t.id })) } }
                    }
                }

                // Status
                Rectangle {
                    id: statusBtn
                    height: 46; width: 90; radius: 6
                    color: statusHover.containsMouse ? "#111111" : "#0a0a0a"
                    border.color: "#222222"; border.width: 1
                    Behavior on color { ColorAnimation { duration: 120 } }
                    Column {
                        anchors.centerIn: parent; spacing: 2
                        Text { anchors.horizontalCenter: parent.horizontalCenter; text: "Status"; font.pixelSize: 12; font.weight: 600; font.family: "JetBrains Mono, Fira Mono, monospace"; color: "#888888" }
                        Text { anchors.horizontalCenter: parent.horizontalCenter; text: "check tools"; font.pixelSize: 9; font.family: "JetBrains Mono, Fira Mono, monospace"; color: "#555555" }
                    }
                    MouseArea {
                        id: statusHover; anchors.fill: parent; hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: checkStatus()
                    }
                }
            }

            // ── Main content area
            Row {
                width: parent.width
                height: parent.height - 42 - 46 - 28
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
                            model: [["console", "Console"], ["report", "Report"]]
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
