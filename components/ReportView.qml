import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

// ReportView.qml — Structured audit report with Rule-Based Executive Summarizer
Rectangle {
    id: root

    property string target: ""
    property string activeView: "summary"   // "summary" | "detail"

    // Summary state properties computed deterministically from tool logs
    property string overallRisk: "CLEAN"
    property string riskColor: "#00cc44"
    property int    portsCount: 0
    property int    vulnCount: 0
    property int    critVulnCount: 0
    property int    highVulnCount: 0
    property int    medVulnCount: 0
    property int    lowVulnCount: 0
    property int    secretsCount: 0
    property int    endpointsCount: 0
    property int    cloudMisconfigCount: 0

    // Parsed finding lists
    property var parsedPorts: []
    property var parsedVulns: []
    property var parsedSecrets: []
    property var parsedEndpoints: []
    property var parsedCloudIssues: []
    property var recommendations: []

    // Internal ListModel — reactive list of per-tool execution records
    ListModel {
        id: resultsModel
    }

    color: "#050505"
    radius: 6
    clip: true
    border.color: "#111111"
    border.width: 1

    // ── Header Bar ─────────────────────────────────────────────────────────────
    Rectangle {
        id: reportHeader
        anchors { top: parent.top; left: parent.left; right: parent.right }
        height: 38
        color: "#0a0a0a"
        radius: 6

        Rectangle {
            anchors { bottom: parent.bottom; left: parent.left; right: parent.right }
            height: 10; color: parent.color
        }

        // Left: Title + Sub-tabs (bounded by rightActionsRow to prevent text collision)
        Row {
            id: leftHeaderRow
            anchors {
                left: parent.left; leftMargin: 12
                right: rightActionsRow.left; rightMargin: 12
                verticalCenter: parent.verticalCenter
            }
            spacing: 10
            clip: true

            Text {
                anchors.verticalCenter: parent.verticalCenter
                text: "AUDIT REPORT"
                font.pixelSize: 11
                font.family: "JetBrains Mono, Fira Mono, monospace"
                font.weight: 700
                color: "#ffffff"
                font.letterSpacing: 0.5
                visible: parent.width > 340
            }

            Rectangle {
                width: 1; height: 16
                color: "#222222"
                anchors.verticalCenter: parent.verticalCenter
                visible: parent.width > 340
            }

            // Sub-tabs: Summary vs Detailed Output
            Row {
                anchors.verticalCenter: parent.verticalCenter
                spacing: 6

                Repeater {
                    model: [
                        ["summary", reportHeader.width > 560 ? "Executive Summary" : "Summary"],
                        ["detail",  reportHeader.width > 560 ? "Detailed Logs" : "Logs"]
                    ]

                    Rectangle {
                        height: 24
                        width: subTabText.implicitWidth + 16
                        radius: 4
                        color: activeView === modelData[0] ? "#141414" : (subHover.containsMouse ? "#0f0f0f" : "transparent")
                        border.color: activeView === modelData[0] ? "#0066ff" : (subHover.containsMouse ? "#222222" : "transparent")
                        border.width: 1
                        Behavior on color { ColorAnimation { duration: 100 } }

                        Text {
                            id: subTabText
                            anchors.centerIn: parent
                            text: modelData[1]
                            font.pixelSize: 10
                            font.family: "JetBrains Mono, Fira Mono, monospace"
                            font.weight: activeView === modelData[0] ? 600 : 400
                            color: activeView === modelData[0] ? "#ffffff" : "#777777"
                        }

                        MouseArea {
                            id: subHover
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: {
                                activeView = modelData[0]
                                if (activeView === "summary") root.computeSummary()
                            }
                        }
                    }
                }
            }
        }

        // Right: Actions (Summarize & Export)
        Row {
            id: rightActionsRow
            anchors { right: parent.right; rightMargin: 10; verticalCenter: parent.verticalCenter }
            spacing: 8

            Rectangle {
                width: 78; height: 22; radius: 4
                color: sumHover.containsMouse ? "#111111" : "transparent"
                border.color: sumHover.containsMouse ? "#222222" : "#1a1a1a"
                border.width: 1
                Behavior on color { ColorAnimation { duration: 100 } }

                Text {
                    anchors.centerIn: parent
                    text: "SUMMARIZE"
                    font.pixelSize: 9
                    font.family: "JetBrains Mono, Fira Mono, monospace"
                    font.weight: 600
                    color: "#0066ff"
                }

                MouseArea {
                    id: sumHover
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: {
                        activeView = "summary"
                        root.computeSummary()
                    }
                }
            }

            Rectangle {
                width: 60; height: 22; radius: 4
                color: exportHover.containsMouse ? "#111111" : "transparent"
                border.color: exportHover.containsMouse ? "#222222" : "#1a1a1a"
                border.width: 1
                Behavior on color { ColorAnimation { duration: 100 } }

                Text {
                    anchors.centerIn: parent
                    text: "EXPORT"
                    font.pixelSize: 9
                    font.family: "JetBrains Mono, Fira Mono, monospace"
                    color: "#aaaaaa"
                }

                MouseArea {
                    id: exportHover
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: root.exportReport()
                }
            }
        }
    }

    // ── Empty State ────────────────────────────────────────────────────────────
    Column {
        anchors.centerIn: parent
        visible: resultsModel.count === 0
        spacing: 12
        opacity: 0.4

        Text {
            anchors.horizontalCenter: parent.horizontalCenter
            text: "⬡"
            font.pixelSize: 32
            color: "#333333"
        }
        Text {
            anchors.horizontalCenter: parent.horizontalCenter
            text: "No audit results yet"
            font.pixelSize: 12
            font.family: "JetBrains Mono, Fira Mono, monospace"
            color: "#666666"
        }
        Text {
            anchors.horizontalCenter: parent.horizontalCenter
            text: "Run tools to generate summary and detailed report"
            font.pixelSize: 10
            color: "#444444"
        }
    }

    // ── VIEW 1: Executive Heuristic Summary ───────────────────────────────────
    ScrollView {
        id: summaryView
        anchors {
            top: reportHeader.bottom; bottom: parent.bottom
            left: parent.left; right: parent.right
            margins: 12
        }
        visible: resultsModel.count > 0 && activeView === "summary"
        clip: true
        contentWidth: availableWidth
        ScrollBar.horizontal.policy: ScrollBar.AlwaysOff
        ScrollBar.vertical: ScrollBar {
            policy: ScrollBar.AsNeeded
            contentItem: Rectangle { implicitWidth: 4; radius: 2; color: "#222222" }
        }

        Column {
            width: summaryView.availableWidth
            spacing: 14

            // Top Bento Metrics Grid
            Grid {
                width: parent.width
                columns: parent.width >= 640 ? 4 : 2
                spacing: 10

                // Card 1: Risk Posture
                Rectangle {
                    width: (parent.width - (parent.columns - 1) * 10) / parent.columns
                    height: 68
                    radius: 6
                    color: "#0a0a0a"; border.color: root.riskColor; border.width: 1
                    clip: true
                    Column {
                        anchors.centerIn: parent; spacing: 3
                        Text { anchors.horizontalCenter: parent.horizontalCenter; text: "OVERALL POSTURE"; font.pixelSize: 9; font.family: "JetBrains Mono, monospace"; color: "#666666" }
                        Text { anchors.horizontalCenter: parent.horizontalCenter; text: root.overallRisk; font.pixelSize: root.overallRisk.length > 10 ? 12 : 14; font.weight: 700; font.family: "JetBrains Mono, monospace"; color: root.riskColor }
                    }
                }

                // Card 2: Exposed Ports
                Rectangle {
                    width: (parent.width - (parent.columns - 1) * 10) / parent.columns
                    height: 68
                    radius: 6
                    color: "#0a0a0a"; border.color: "#1a1a1a"; border.width: 1
                    clip: true
                    Column {
                        anchors.centerIn: parent; spacing: 3
                        Text { anchors.horizontalCenter: parent.horizontalCenter; text: "OPEN PORTS"; font.pixelSize: 9; font.family: "JetBrains Mono, monospace"; color: "#666666" }
                        Text { anchors.horizontalCenter: parent.horizontalCenter; text: root.portsCount.toString(); font.pixelSize: 16; font.weight: 700; font.family: "JetBrains Mono, monospace"; color: root.portsCount > 0 ? "#0066ff" : "#555555" }
                    }
                }

                // Card 3: Vulnerabilities
                Rectangle {
                    width: (parent.width - (parent.columns - 1) * 10) / parent.columns
                    height: 68
                    radius: 6
                    color: "#0a0a0a"; border.color: "#1a1a1a"; border.width: 1
                    clip: true
                    Column {
                        anchors.centerIn: parent; spacing: 3
                        Text { anchors.horizontalCenter: parent.horizontalCenter; text: "VULNERABILITIES"; font.pixelSize: 9; font.family: "JetBrains Mono, monospace"; color: "#666666" }
                        Row {
                            anchors.horizontalCenter: parent.horizontalCenter; spacing: 6
                            Text { text: root.critVulnCount + " Crit"; font.pixelSize: 10; font.weight: 700; font.family: "JetBrains Mono, monospace"; color: root.critVulnCount > 0 ? "#ff3333" : "#444444" }
                            Text { text: root.highVulnCount + " High"; font.pixelSize: 10; font.weight: 700; font.family: "JetBrains Mono, monospace"; color: root.highVulnCount > 0 ? "#ff6633" : "#444444" }
                            Text { text: root.medVulnCount  + " Med";  font.pixelSize: 10; font.weight: 700; font.family: "JetBrains Mono, monospace"; color: root.medVulnCount > 0  ? "#ffcc00" : "#444444" }
                        }
                    }
                }

                // Card 4: Secrets & Cloud Posture
                Rectangle {
                    width: (parent.width - (parent.columns - 1) * 10) / parent.columns
                    height: 68
                    radius: 6
                    color: "#0a0a0a"; border.color: "#1a1a1a"; border.width: 1
                    clip: true
                    Column {
                        anchors.centerIn: parent; spacing: 3
                        Text { anchors.horizontalCenter: parent.horizontalCenter; text: "SECRETS & CLOUD"; font.pixelSize: 9; font.family: "JetBrains Mono, monospace"; color: "#666666" }
                        Row {
                            anchors.horizontalCenter: parent.horizontalCenter; spacing: 6
                            Text { text: root.secretsCount + " Leaks"; font.pixelSize: 10; font.weight: 700; font.family: "JetBrains Mono, monospace"; color: root.secretsCount > 0 ? "#ff3333" : "#555555" }
                            Text { text: "|"; color: "#333333"; font.pixelSize: 10 }
                            Text { text: root.cloudMisconfigCount + " Misconf"; font.pixelSize: 10; font.weight: 700; font.family: "JetBrains Mono, monospace"; color: root.cloudMisconfigCount > 0 ? "#ff9900" : "#555555" }
                        }
                    }
                }
            }

            // Section 1: Open Ports & Exposed Services
            Rectangle {
                width: parent.width
                implicitHeight: portsCol.implicitHeight + 24
                height: implicitHeight
                radius: 6; color: "#0a0a0a"; border.color: "#151515"; border.width: 1
                clip: true

                Column {
                    id: portsCol
                    anchors {
                        top: parent.top; topMargin: 12
                        left: parent.left; leftMargin: 12
                        right: parent.right; rightMargin: 12
                    }
                    spacing: 8

                    Row {
                        spacing: 8
                        Text { text: "EXPOSED SERVICES & PORTS"; font.pixelSize: 11; font.weight: 700; font.family: "JetBrains Mono, monospace"; color: "#0066ff" }
                        Text { text: "(" + root.parsedPorts.length + " detected)"; font.pixelSize: 10; font.family: "JetBrains Mono, monospace"; color: "#555555" }
                    }
                    Rectangle { width: parent.width; height: 1; color: "#161616" }

                    Flow {
                        width: parent.width; spacing: 6
                        visible: root.parsedPorts.length > 0
                        Repeater {
                            model: root.parsedPorts
                            Rectangle {
                                height: 22; width: portLabel.implicitWidth + 12; radius: 4
                                color: "#111827"; border.color: "#1e3a8a"; border.width: 1
                                Text { id: portLabel; anchors.centerIn: parent; text: modelData; font.pixelSize: 10; font.family: "JetBrains Mono, monospace"; color: "#60a5fa" }
                            }
                        }
                    }
                    Text {
                        visible: root.parsedPorts.length === 0
                        text: "No open ports identified in the executed scan results."
                        font.pixelSize: 10; font.family: "JetBrains Mono, monospace"; color: "#555555"
                    }
                }
            }

            // Section 2: Key Security Findings & Vulnerabilities
            Rectangle {
                width: parent.width
                implicitHeight: vulnCol.implicitHeight + 24
                height: implicitHeight
                radius: 6; color: "#0a0a0a"; border.color: "#151515"; border.width: 1
                clip: true

                Column {
                    id: vulnCol
                    anchors {
                        top: parent.top; topMargin: 12
                        left: parent.left; leftMargin: 12
                        right: parent.right; rightMargin: 12
                    }
                    spacing: 8

                    Row {
                        spacing: 8
                        Text { text: "VULNERABILITY & EXPLOIT FINDINGS"; font.pixelSize: 11; font.weight: 700; font.family: "JetBrains Mono, monospace"; color: root.vulnCount > 0 ? "#ff3333" : "#888888" }
                        Text { text: "(" + root.vulnCount + " items)"; font.pixelSize: 10; font.family: "JetBrains Mono, monospace"; color: "#555555" }
                    }
                    Rectangle { width: parent.width; height: 1; color: "#161616" }

                    Column {
                        width: parent.width; spacing: 6
                        visible: root.parsedVulns.length > 0

                        Repeater {
                            model: root.parsedVulns.slice(0, 15)
                            Item {
                                width: parent.width
                                implicitHeight: Math.max(16, vulnText.implicitHeight)
                                height: implicitHeight

                                Rectangle {
                                    id: vulnDot
                                    width: 6; height: 6; radius: 3
                                    y: 4
                                    anchors.left: parent.left
                                    color: modelData.indexOf("[critical]") !== -1 ? "#ff3333" : (modelData.indexOf("[high]") !== -1 ? "#ff6633" : "#ffcc00")
                                }

                                Text {
                                    id: vulnText
                                    anchors {
                                        left: vulnDot.right; leftMargin: 8
                                        right: parent.right
                                        top: parent.top
                                    }
                                    text: modelData
                                    font.pixelSize: 10
                                    font.family: "JetBrains Mono, monospace"
                                    color: "#cccccc"
                                    wrapMode: Text.WrapAnywhere
                                }
                            }
                        }
                    }

                    Text {
                        visible: root.parsedVulns.length === 0
                        text: "No high/critical vulnerabilities discovered."
                        font.pixelSize: 10; font.family: "JetBrains Mono, monospace"; color: "#555555"
                    }
                }
            }

            // Section 3: Cloud & Secret Audits
            Rectangle {
                width: parent.width
                implicitHeight: cloudCol.implicitHeight + 24
                height: implicitHeight
                radius: 6; color: "#0a0a0a"; border.color: "#151515"; border.width: 1
                clip: true

                Column {
                    id: cloudCol
                    anchors {
                        top: parent.top; topMargin: 12
                        left: parent.left; leftMargin: 12
                        right: parent.right; rightMargin: 12
                    }
                    spacing: 8

                    Row {
                        spacing: 8
                        Text { text: "CLOUD MISCONFIGURATIONS & SECRETS LEAK"; font.pixelSize: 11; font.weight: 700; font.family: "JetBrains Mono, monospace"; color: (root.cloudMisconfigCount > 0 || root.secretsCount > 0) ? "#ff9900" : "#888888" }
                    }
                    Rectangle { width: parent.width; height: 1; color: "#161616" }

                    Column {
                        width: parent.width; spacing: 6
                        visible: root.parsedSecrets.length > 0 || root.parsedCloudIssues.length > 0

                        Repeater {
                            model: (root.parsedSecrets.concat(root.parsedCloudIssues)).slice(0, 10)
                            Item {
                                width: parent.width
                                implicitHeight: Math.max(16, cloudText.implicitHeight)
                                height: implicitHeight

                                Text {
                                    id: bulletDot
                                    anchors { left: parent.left; top: parent.top }
                                    text: "•"
                                    color: "#ff9900"
                                    font.pixelSize: 12
                                }

                                Text {
                                    id: cloudText
                                    anchors {
                                        left: bulletDot.right; leftMargin: 6
                                        right: parent.right
                                        top: parent.top
                                    }
                                    text: modelData
                                    font.pixelSize: 10
                                    font.family: "JetBrains Mono, monospace"
                                    color: "#bbbbbb"
                                    wrapMode: Text.WrapAnywhere
                                }
                            }
                        }
                    }

                    Text {
                        visible: root.parsedSecrets.length === 0 && root.parsedCloudIssues.length === 0
                        text: "No credentials leaks or cloud misconfigurations flagged."
                        font.pixelSize: 10; font.family: "JetBrains Mono, monospace"; color: "#555555"
                    }
                }
            }

            // Section 4: Deterministic Hardening Recommendations
            Rectangle {
                width: parent.width
                implicitHeight: recCol.implicitHeight + 24
                height: implicitHeight
                radius: 6; color: "#0a0a0a"; border.color: "#151515"; border.width: 1
                clip: true

                Column {
                    id: recCol
                    anchors {
                        top: parent.top; topMargin: 12
                        left: parent.left; leftMargin: 12
                        right: parent.right; rightMargin: 12
                    }
                    spacing: 8

                    Row {
                        spacing: 8
                        Text { text: "ACTIONABLE HARDENING CHECKLIST"; font.pixelSize: 11; font.weight: 700; font.family: "JetBrains Mono, monospace"; color: "#00cc44" }
                    }
                    Rectangle { width: parent.width; height: 1; color: "#161616" }

                    Column {
                        width: parent.width; spacing: 6

                        Repeater {
                            model: root.recommendations
                            Item {
                                width: parent.width
                                implicitHeight: Math.max(16, recText.implicitHeight)
                                height: implicitHeight

                                Text {
                                    id: checkIcon
                                    anchors { left: parent.left; top: parent.top }
                                    text: "✔"
                                    color: "#00cc44"
                                    font.pixelSize: 10
                                }

                                Text {
                                    id: recText
                                    anchors {
                                        left: checkIcon.right; leftMargin: 8
                                        right: parent.right
                                        top: parent.top
                                    }
                                    text: modelData
                                    font.pixelSize: 10
                                    font.family: "Inter, sans-serif"
                                    color: "#cccccc"
                                    wrapMode: Text.WordWrap
                                }
                            }
                        }
                    }
                }
            }
        }
    }

    // ── VIEW 2: Raw / Detailed Output List ─────────────────────────────────────
    ListView {
        id: resultList
        anchors {
            top: reportHeader.bottom; bottom: parent.bottom
            left: parent.left; right: parent.right
            margins: 10; topMargin: 12
        }
        visible: resultsModel.count > 0 && activeView === "detail"
        spacing: 8
        clip: true
        model: resultsModel

        ScrollBar.vertical: ScrollBar {
            policy: ScrollBar.AsNeeded
            contentItem: Rectangle { implicitWidth: 4; radius: 2; color: "#222222" }
        }

        delegate: Rectangle {
            width: resultList.width
            height: entryCol.implicitHeight + 24
            radius: 4
            color: {
                if (model.status === "done")    return "#050a11"
                if (model.status === "failed")  return "#110505"
                if (model.status === "running") return "#050a11"
                return "#0a0a0a"
            }
            border.color: {
                if (model.status === "done")    return "#003366"
                if (model.status === "failed")  return "#330000"
                if (model.status === "running") return "#0047b3"
                return "#111111"
            }
            border.width: 1

            Column {
                id: entryCol
                anchors { left: parent.left; right: parent.right; top: parent.top; margins: 12 }
                spacing: 8

                Row {
                    width: parent.width
                    spacing: 8

                    Rectangle {
                        width: 8; height: 8; radius: 4
                        anchors.verticalCenter: parent.verticalCenter
                        color: {
                            if (model.status === "done")    return "#0066ff"
                            if (model.status === "failed")  return "#ff3333"
                            if (model.status === "running") return "#0066ff"
                            return "#555555"
                        }
                        SequentialAnimation on opacity {
                            running: model.status === "running"
                            loops: Animation.Infinite
                            NumberAnimation { to: 0.3; duration: 600 }
                            NumberAnimation { to: 1.0; duration: 600 }
                        }
                    }

                    Text {
                        text: (model.display || model.tool || "").toUpperCase()
                        font.pixelSize: 12
                        font.weight: 700
                        font.family: "JetBrains Mono, Fira Mono, monospace"
                        color: "#ffffff"
                    }

                    Item { width: 1; height: 1 }

                    Text {
                        anchors.verticalCenter: parent.verticalCenter
                        text: {
                            if (model.status === "done")    return "✓ Done"
                            if (model.status === "failed")  return "✗ Failed"
                            if (model.status === "running") return "⟳ Running"
                            return "Pending"
                        }
                        font.pixelSize: 10
                        font.family: "JetBrains Mono, Fira Mono, monospace"
                        color: {
                            if (model.status === "done")    return "#0066ff"
                            if (model.status === "failed")  return "#ff3333"
                            if (model.status === "running") return "#0066ff"
                            return "#555555"
                        }
                    }
                }

                Rectangle { width: parent.width; height: 1; color: "#111111" }

                Column {
                    width: parent.width
                    spacing: 2

                    Repeater {
                        model: {
                            try {
                                var arr = JSON.parse(model.linesJson || "[]")
                                return arr.slice(-10)
                            } catch(e) { return [] }
                        }
                        Text {
                            width: parent.width
                            text: modelData
                            font.pixelSize: 10
                            font.family: "JetBrains Mono, Fira Mono, monospace"
                            color: "#888888"
                            wrapMode: Text.WrapAnywhere
                            lineHeight: 1.3
                        }
                    }

                    Text {
                        visible: {
                            try { return JSON.parse(model.linesJson || "[]").length > 10 } catch(e) { return false }
                        }
                        text: {
                            try { return "... " + (JSON.parse(model.linesJson || "[]").length - 10) + " more lines in console" } catch(e) { return "" }
                        }
                        font.pixelSize: 9
                        color: "#555555"
                    }
                }
            }
        }
    }

    // ── Deterministic Rule-Based Summarizer Logic ──────────────────────────────
    function computeSummary() {
        var ports = []
        var vulns = []
        var secrets = []
        var endpoints = []
        var cloudIssues = []
        var recs = []

        var critCount = 0
        var highCount = 0
        var medCount = 0
        var lowCount = 0

        for (var i = 0; i < resultsModel.count; i++) {
            var item = resultsModel.get(i)
            var tool = (item.tool || "").toLowerCase()
            var lines = []
            try {
                lines = JSON.parse(item.linesJson || "[]")
            } catch(e) { lines = [] }

            for (var j = 0; j < lines.length; j++) {
                var l = lines[j].trim()
                if (!l) continue

                // 1. Port Scanning patterns (Nmap / Rustscan / Metasploit)
                var portMatch = l.match(/^(\d+\/(?:tcp|udp))\s+open\s+([\w\-\/\.]+)/i)
                if (portMatch) {
                    var pStr = portMatch[1] + " (" + portMatch[2] + ")"
                    if (ports.indexOf(pStr) === -1) ports.push(pStr)
                }

                // 2. Nuclei vulnerability patterns
                if (l.indexOf("[critical]") !== -1) {
                    critCount++
                    vulns.push("[critical] " + l.replace(/^\[.*?\]\s*/, ""))
                } else if (l.indexOf("[high]") !== -1) {
                    highCount++
                    vulns.push("[high] " + l.replace(/^\[.*?\]\s*/, ""))
                } else if (l.indexOf("[medium]") !== -1) {
                    medCount++
                    vulns.push("[medium] " + l.replace(/^\[.*?\]\s*/, ""))
                } else if (l.indexOf("[low]") !== -1) {
                    lowCount++
                    vulns.push("[low] " + l.replace(/^\[.*?\]\s*/, ""))
                }

                // 3. Nikto & SQLMap findings
                if (tool === "nikto" && (l.indexOf("+ OSVDB") !== -1 || l.indexOf("vulnerable") !== -1 || l.indexOf("anti-clickjacking") !== -1)) {
                    if (vulns.indexOf("[nikto] " + l) === -1) {
                        medCount++
                        vulns.push("[nikto] " + l)
                    }
                }
                if (tool === "sqlmap" && (l.indexOf("is vulnerable") !== -1 || l.indexOf("injection point") !== -1)) {
                    highCount++
                    vulns.push("[sqlmap] " + l)
                }

                // 3b. Wapiti web vulnerability findings (All 30 modules)
                if (tool === "wapiti" && (l.indexOf("Wapiti Vuln:") !== -1 || l.indexOf("via injection") !== -1 || l.indexOf("Evil url:") !== -1 || l.indexOf("vulnerability") !== -1)) {
                    var lLow = l.toLowerCase()
                    if (lLow.indexOf("command execution") !== -1 || lLow.indexOf("sql injection") !== -1 || lLow.indexOf("log4shell") !== -1 || lLow.indexOf("spring4shell") !== -1 || lLow.indexOf("shellshock") !== -1 || lLow.indexOf("ssrf") !== -1 || lLow.indexOf("server side request forgery") !== -1 || lLow.indexOf("xxe") !== -1 || lLow.indexOf("ldap") !== -1 || lLow.indexOf("file inclusion") !== -1 || lLow.indexOf("path traversal") !== -1 || lLow.indexOf("file upload") !== -1) {
                        critCount++
                        vulns.push("[wapiti-critical] " + l)
                    } else if (lLow.indexOf("cross site scripting") !== -1 || lLow.indexOf("xss") !== -1 || lLow.indexOf("csrf") !== -1 || lLow.indexOf("crlf") !== -1 || lLow.indexOf("open redirect") !== -1 || lLow.indexOf("weak credentials") !== -1 || lLow.indexOf("htaccess") !== -1) {
                        highCount++
                        vulns.push("[wapiti-high] " + l)
                    } else if (lLow.indexOf("backup file") !== -1 || lLow.indexOf("information disclosure") !== -1 || lLow.indexOf("full path") !== -1) {
                        medCount++
                        vulns.push("[wapiti-med] " + l)
                    } else if (l.indexOf("Wapiti Vuln:") !== -1) {
                        medCount++
                        vulns.push("[wapiti] " + l)
                    }
                }

                // 4. Gobuster endpoints (Status 200 / 301)
                if (tool === "gobuster" && (l.indexOf("Status: 200") !== -1 || l.indexOf("Status: 301") !== -1)) {
                    if (endpoints.indexOf(l) === -1) endpoints.push(l)
                }

                // 5. Gitleaks secrets detection
                if (tool === "gitleaks" && (l.indexOf("Finding:") !== -1 || l.indexOf("Secret:") !== -1 || l.indexOf("RuleID:") !== -1)) {
                    if (secrets.indexOf(l) === -1) secrets.push(l)
                }

                // 6. Cloud security issues (Trivy / Checkov / Prowler / ScoutSuite)
                if (tool === "trivy" && (l.indexOf("CRITICAL:") !== -1 || l.indexOf("HIGH:") !== -1 || l.indexOf("FAILED") !== -1)) {
                    cloudIssues.push("[trivy] " + l)
                }
                if (tool === "checkov" && (l.indexOf("FAILED for resource:") !== -1 || l.indexOf("Check: CKV_") !== -1)) {
                    cloudIssues.push("[checkov] " + l)
                }
                if (tool === "prowler" && (l.indexOf("[FAIL]") !== -1 || l.indexOf("CRITICAL") !== -1)) {
                    cloudIssues.push("[prowler] " + l)
                }

                // 7. Wireless findings (Aircrack / Wifite / Kismet)
                if (tool === "aircrack-ng" && (l.indexOf("KEY FOUND!") !== -1 || l.indexOf("WPA (1 handshake)") !== -1)) {
                    critCount++
                    vulns.push("[aircrack-ng] " + l)
                }
                if (tool === "wifite" && (l.indexOf("captured handshake") !== -1 || l.indexOf("PMKID captured") !== -1 || l.indexOf("cracked") !== -1)) {
                    critCount++
                    vulns.push("[wifite] " + l)
                }
                if (tool === "kismet" && (l.indexOf("ALERT") !== -1 || l.indexOf("Detected") !== -1)) {
                    medCount++
                    vulns.push("[kismet] " + l)
                }

                // 8. Reverse engineering findings (jadx / apktool / binwalk / radare2)
                if (tool === "jadx" && (l.indexOf("ERROR:") !== -1 || l.indexOf("WARN:") !== -1)) {
                    if (l.indexOf("ERROR:") !== -1) {
                        highCount++
                        vulns.push("[jadx] " + l)
                    }
                }
                if (tool === "apktool" && l.indexOf("W: ") !== -1) {
                    medCount++
                    vulns.push("[apktool] " + l)
                }
                if (tool === "binwalk" && (l.indexOf("private key") !== -1 || l.indexOf("certificate") !== -1 || l.indexOf("Squashfs") !== -1)) {
                    if (l.indexOf("private key") !== -1 || l.indexOf("certificate") !== -1) {
                        critCount++
                        secrets.push("[binwalk] " + l)
                    } else {
                        lowCount++
                        vulns.push("[binwalk] " + l)
                    }
                }
                if (tool === "radare2" && (l.indexOf("canary") !== -1 || l.indexOf("nx") !== -1 || l.indexOf("pic") !== -1 || l.indexOf("crypto") !== -1)) {
                    vulns.push("[radare2] " + l)
                }
            }
        }

        // Compute Overall Risk Level
        var totalVulns = critCount + highCount + medCount + lowCount
        if (critCount > 0 || secrets.length > 0) {
            overallRisk = "CRITICAL RISK"
            riskColor = "#ff3333"
        } else if (highCount > 0 || cloudIssues.length > 3) {
            overallRisk = "HIGH RISK"
            riskColor = "#ff6633"
        } else if (medCount > 0 || cloudIssues.length > 0) {
            overallRisk = "MEDIUM RISK"
            riskColor = "#ffcc00"
        } else if (ports.length > 0 || lowCount > 0) {
            overallRisk = "LOW RISK"
            riskColor = "#0066ff"
        } else {
            overallRisk = "CLEAN / SAFE"
            riskColor = "#00cc44"
        }

        // Generate Actionable Recommendations
        if (critCount > 0 || highCount > 0) {
            recs.push("Segera mitigasi temuan kerentanan berisiko Critical dan High yang terdeteksi oleh Nuclei/SQLMap/Aircrack/Jadx.")
        }
        if (secrets.length > 0) {
            recs.push("Lakukan rotasi segera terhadap API keys / credentials / sertifikat yang terdeteksi bocor oleh Gitleaks/Binwalk.")
        }
        if (ports.indexOf("21/tcp (ftp)") !== -1 || ports.indexOf("23/tcp (telnet)") !== -1) {
            recs.push("Tutup port tidak terenkripsi (FTP/Telnet) dan beralih ke SSH/SFTP yang aman.")
        }
        if (ports.indexOf("445/tcp (microsoft-ds)") !== -1 || ports.indexOf("139/tcp (netbios-ssn)") !== -1) {
            recs.push("Batasi akses port SMB (139/445) hanya pada subnet tepercaya dan pastikan SMB Signing aktif.")
        }
        if (cloudIssues.length > 0) {
            recs.push("Terapkan perbaikan template IaC (Terraform/CloudFormation) yang gagal dalam pemeriksaan Trivy/Checkov.")
        }
        if (vulns.some(function(v){ return v.indexOf("[aircrack") !== -1 || v.indexOf("[wifite") !== -1 })) {
            recs.push("Handshake wireless berhasil ditangkap/ditembus. Tingkatkan enkripsi ke WPA3-SAE dan gunakan passphrase kompleks.")
        }
        if (vulns.some(function(v){ return v.indexOf("[radare2") !== -1 || v.indexOf("[binwalk") !== -1 })) {
            recs.push("Analisis artefak biner menemukan firmware/binary protections perlu ditinjau (aktifkan Stack Canary, PIE, dan NX).")
        }
        if (vulns.some(function(v){ return v.indexOf("[wapiti") !== -1 })) {
            recs.push("Kerentanan web terdeteksi oleh Wapiti (SQLi/XSS/SSRF/RCE/Upload). Validasi dan sanitasi semua input pengguna serta terapkan WAF.")
        }
        if (recs.length === 0) {
            recs.push("Tidak ada ancaman kritis yang teridentifikasi secara langsung. Tetap terapkan prinsip Least Privilege.")
        }

        parsedPorts = ports
        parsedVulns = vulns
        parsedSecrets = secrets
        parsedEndpoints = endpoints
        parsedCloudIssues = cloudIssues
        recommendations = recs

        portsCount = ports.length
        vulnCount = totalVulns
        critVulnCount = critCount
        highVulnCount = highCount
        medVulnCount = medCount
        lowVulnCount = lowCount
        secretsCount = secrets.length
        endpointsCount = endpoints.length
        cloudMisconfigCount = cloudIssues.length
    }

    // ── Public API called from shell.qml ──────────────────────────────────────
    function clear() {
        resultsModel.clear()
        overallRisk = "CLEAN"
        riskColor = "#00cc44"
        portsCount = 0
        vulnCount = 0
        critVulnCount = 0
        highVulnCount = 0
        medVulnCount = 0
        lowVulnCount = 0
        secretsCount = 0
        endpointsCount = 0
        cloudMisconfigCount = 0
        parsedPorts = []
        parsedVulns = []
        parsedSecrets = []
        parsedEndpoints = []
        parsedCloudIssues = []
        recommendations = []
    }

    function addResult(toolName, displayName, status, lines) {
        for (var i = 0; i < resultsModel.count; i++) {
            if (resultsModel.get(i).tool === toolName) {
                resultsModel.setProperty(i, "status", status)
                resultsModel.setProperty(i, "linesJson", JSON.stringify(lines || []))
                root.computeSummary()
                return
            }
        }
        resultsModel.append({
            tool:      toolName,
            display:   displayName,
            status:    status,
            linesJson: JSON.stringify(lines || [])
        })
        root.computeSummary()
    }

    function updateStatus(toolName, newStatus) {
        for (var i = 0; i < resultsModel.count; i++) {
            if (resultsModel.get(i).tool === toolName) {
                resultsModel.setProperty(i, "status", newStatus)
                root.computeSummary()
                return
            }
        }
    }

    function appendLine(toolName, line) {
        for (var i = 0; i < resultsModel.count; i++) {
            if (resultsModel.get(i).tool === toolName) {
                try {
                    var arr = JSON.parse(resultsModel.get(i).linesJson || "[]")
                    arr.push(line)
                    resultsModel.setProperty(i, "linesJson", JSON.stringify(arr))
                } catch(e) {
                    resultsModel.setProperty(i, "linesJson", JSON.stringify([line]))
                }
                return
            }
        }
    }

    function buildFullReport() {
        root.computeSummary()
        var now = new Date()
        var dateFormatted = now.toLocaleString("id-ID", { dateStyle: "full", timeStyle: "medium" })

        var lines = [
            "---",
            "title: \"AuditX Security Assessment Report\"",
            "target: \"" + (root.target ? root.target : "All Executed Scans") + "\"",
            "date: \"" + dateFormatted + "\"",
            "posture: \"" + root.overallRisk + "\"",
            "tool_count: " + resultsModel.count,
            "vulnerabilities: " + root.vulnCount,
            "leaks_detected: " + root.secretsCount,
            "---",
            "",
            "# 🛡️ AuditX — Security Audit Report",
            "",
            "> **Generated on**: `" + dateFormatted + "`  ",
            "> **Primary Target**: `" + (root.target ? root.target : "General / Local") + "`  ",
            "> **Overall Risk Posture**: **" + root.overallRisk + "**  ",
            "> **Audit Platform**: `AuditX Platform v1.8.0-cli & GUI`",
            "",
            "---",
            "",
            "## 📊 1. Executive Summary & Metrics",
            "",
            "| Metrik Keamanan | Nilai / Temuan | Keterangan |",
            "|---|---|---|",
            "| **Overall Risk Posture** | `" + root.overallRisk + "` | Status risiko menyeluruh |",
            "| **Total Kerentanan** | `" + root.vulnCount + "` | Critical: " + root.critVulnCount + ", High: " + root.highVulnCount + ", Med: " + root.medVulnCount + ", Low: " + root.lowVulnCount + " |",
            "| **Data Bocor / Kredensial** | `" + root.secretsCount + "` | Secrets, passwords, API tokens & keys |",
            "| **Port & Layanan Terbuka** | `" + root.portsCount + "` | Exposed listening network services |",
            "| **Miskonfigurasi Cloud / IaC** | `" + root.cloudMisconfigCount + "` | CIS benchmarks & IaC rules failed |",
            "| **Total Tools Dijalankan** | `" + resultsModel.count + "` | Eksekusi perkakas audit keamanan |",
            "",
            "---",
            "",
            "## 🔑 2. Data Bocor & Kredensial Terekspos (Leaked Data & Secrets)",
            ""
        ]

        if (root.parsedSecrets.length > 0) {
            lines.push("> [!CAUTION]")
            lines.push("> **PERINGATAN KRITIS**: Ditemukan " + root.parsedSecrets.length + " data rahasia/kredensial terekspos. Segera lakukan rotasi!")
            lines.push("")
            for (var s = 0; s < root.parsedSecrets.length; s++) {
                lines.push("- **[LEAK #" + (s + 1) + "]**: `" + root.parsedSecrets[s] + "`")
            }
        } else {
            lines.push("Tidak ada kredensial atau rahasia yang terdeteksi bocor secara langsung.")
        }

        lines.push("")
        lines.push("---")
        lines.push("")
        lines.push("## 🚨 3. Temuan Kerentanan & CVE (Vulnerabilities)")
        lines.push("")

        if (root.parsedVulns.length > 0) {
            for (var v = 0; v < root.parsedVulns.length; v++) {
                lines.push("- " + root.parsedVulns[v])
            }
        } else {
            lines.push("Tidak ada kerentanan critical/high aktif yang terdeteksi pada target.")
        }

        lines.push("")
        lines.push("---")
        lines.push("")
        lines.push("## ☁️ 4. Miskonfigurasi Cloud & Postur IaC")
        lines.push("")

        if (root.parsedCloudIssues.length > 0) {
            for (var c = 0; c < root.parsedCloudIssues.length; c++) {
                lines.push("- " + root.parsedCloudIssues[c])
            }
        } else {
            lines.push("Tidak ada kegagalan konfigurasi cloud/IaC yang dilaporkan.")
        }

        lines.push("")
        lines.push("---")
        lines.push("")
        lines.push("## ⚡ 5. Port Terbuka & Layanan Jaringan (Open Ports)")
        lines.push("")

        if (root.parsedPorts.length > 0) {
            for (var p = 0; p < root.parsedPorts.length; p++) {
                lines.push("- `" + root.parsedPorts[p] + "`")
            }
        } else {
            lines.push("Tidak ada port terbuka yang terdeteksi.")
        }

        lines.push("")
        lines.push("---")
        lines.push("")
        lines.push("## 🌐 6. Endpoint Web & Subdomain Terekspos")
        lines.push("")

        if (root.parsedEndpoints.length > 0) {
            for (var ep = 0; ep < root.parsedEndpoints.length; ep++) {
                lines.push("- `" + root.parsedEndpoints[ep] + "`")
            }
        } else {
            lines.push("Tidak ada endpoint tambahan yang ditemukan.")
        }

        lines.push("")
        lines.push("---")
        lines.push("")
        lines.push("## 📋 7. Rekomendasi Pengerasan Sistem (Actionable Checklist)")
        lines.push("")

        if (root.recommendations.length > 0) {
            for (var rc = 0; rc < root.recommendations.length; rc++) {
                lines.push("- [ ] " + root.recommendations[rc])
            }
        } else {
            lines.push("- [x] Seluruh kriteria dasar pengerasan sistem telah terpenuhi.")
        }

        lines.push("")
        lines.push("---")
        lines.push("")
        lines.push("## 📜 8. Log Lengkap Forensik Tiap Perkakas (Raw Execution Logs)")
        lines.push("")

        for (var i = 0; i < resultsModel.count; i++) {
            var r = resultsModel.get(i)
            lines.push("### Perkakas: " + (r.display || r.tool) + " `[" + (r.status || "IDLE").toUpperCase() + "]`")
            lines.push("")
            lines.push("```text")
            try {
                var arr = JSON.parse(r.linesJson || "[]")
                if (arr.length > 0) {
                    for (var k = 0; k < arr.length; k++) {
                        lines.push(arr[k])
                    }
                } else {
                    lines.push("(Tidak ada output terminal tercatat)")
                }
            } catch(e) {
                lines.push("(Gagal memuat log)")
            }
            lines.push("```")
            lines.push("")
        }

        return lines.join("\n")
    }

    function exportReport() {
        root.computeSummary()
        exportModal.target = root.target
        exportModal.overallRisk = root.overallRisk
        exportModal.riskColor = root.riskColor
        exportModal.secretsCount = root.secretsCount
        exportModal.vulnCount = root.vulnCount
        exportModal.portsCount = root.portsCount
        exportModal.reportContent = root.buildFullReport()
        exportModal.openModal()
    }

    // Modal dialog for selecting save destination and exporting report
    ExportModal {
        id: exportModal
        target: root.target
        overallRisk: root.overallRisk
        riskColor: root.riskColor
        secretsCount: root.secretsCount
        vulnCount: root.vulnCount
        portsCount: root.portsCount
    }
}
