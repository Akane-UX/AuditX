import QtQuick
import QtQuick.Controls
import Quickshell
import Quickshell.Io

// TerminalView.qml — Interactive terminal tab
Rectangle {
    id: root

    property string backendPath: ""
    property string targetIp: ""
    property string targetDomain: ""
    property string targetUrl: ""
    property string targetCloud: ""
    property string targetPath: ""
    property string targetUsername: ""
    property string targetInterface: ""

    readonly property string primaryTarget: (targetIp || targetDomain || targetUrl || targetCloud || targetPath || targetUsername || targetInterface || "127.0.0.1")

    property bool   isProcessRunning: false
    property int    activePid: 0
    property string activeCmd: ""
    property var    commandHistory: []
    property int    historyIndex: -1
    property string savedDraftInput: ""

    color: "#050505"
    radius: 6
    clip: true
    border.color: "#111111"
    border.width: 1

    // Log model
    ListModel {
        id: terminalModel

        Component.onCompleted: {
            appendWelcomeBanner()
        }
    }

    function appendWelcomeBanner() {
        terminalModel.append({
            timestamp: getTimestamp(),
            lineType: "system",
            text: "<span style='color:#0066ff;font-weight:bold;'>┌──[ AuditX Interactive Cyber Terminal ]</span>",
            raw: "┌──[ AuditX Interactive Cyber Terminal ]"
        })
        terminalModel.append({
            timestamp: getTimestamp(),
            lineType: "system",
            text: "<span style='color:#0066ff;'>│</span>  <span style='color:#aaaaaa;'>PTY-Allocated Bash Shell with live ANSI coloring &amp; stdin streaming.</span>",
            raw: "│  PTY-Allocated Bash Shell with live ANSI coloring & stdin streaming."
        })
        terminalModel.append({
            timestamp: getTimestamp(),
            lineType: "system",
            text: "<span style='color:#0066ff;'>│</span>  <span style='color:#50fa7b;'>Active Targets:</span> <span style='color:#8be9fd;'>$TARGET</span>, <span style='color:#8be9fd;'>$IP</span>, <span style='color:#8be9fd;'>$DOMAIN</span>, <span style='color:#8be9fd;'>$URL</span>, <span style='color:#8be9fd;'>$PATH_TARGET</span>",
            raw: "│  Active Targets: $TARGET, $IP, $DOMAIN, $URL, $PATH_TARGET"
        })
        terminalModel.append({
            timestamp: getTimestamp(),
            lineType: "system",
            text: "<span style='color:#0066ff;'>└──[</span> <span style='color:#f1fa8c;'>Ready. Type a command or click a quick action below.</span> <span style='color:#0066ff;'>]</span>",
            raw: "└──[ Ready. Type a command or click a quick action below. ]"
        })
    }

    function getTimestamp() {
        var d = new Date()
        return String(d.getHours()).padStart(2, "0") + ":" +
               String(d.getMinutes()).padStart(2, "0") + ":" +
               String(d.getSeconds()).padStart(2, "0")
    }

    // PTY Process
    Process {
        id: ptyProcess
        stdinEnabled: true

        onRunningChanged: {
            if (!running) {
                if (isProcessRunning) {
                    isProcessRunning = false
                    activePid = 0
                }
            }
        }

        stdout: SplitParser {
            onRead: function(data) {
                var line = data.trim()
                if (line.length === 0) return
                try {
                    var ev = JSON.parse(line)
                    handlePtyEvent(ev)
                } catch (e) {
                    appendLine("out", line, line)
                }
            }
        }

        stderr: SplitParser {
            onRead: function(data) {
                var trimmed = data.trim()
                if (trimmed.length > 0) {
                    appendLine("err", "<span style='color:#ff5555;'>" + trimmed + "</span>", trimmed)
                }
            }
        }
    }

    // PTY event handler
    function handlePtyEvent(ev) {
        if (!ev || !ev.event) return

        if (ev.event === "start") {
            isProcessRunning = true
            activePid = ev.pid || 0
            activeCmd = ev.cmd || ""
        } else if (ev.event === "output") {
            appendLine("out", ev.text, ev.raw || "")
        } else if (ev.event === "exit") {
            isProcessRunning = false
            activePid = 0
            var code = ev.code
            var color = code === 0 ? "#50fa7b" : "#ff5555"
            var msg = "<span style='color:" + color + ";font-weight:bold;'>[Process finished with exit code " + code + "]</span>"
            appendLine("exit", msg, "[Exit: " + code + "]")
        } else if (ev.event === "error") {
            appendLine("err", "<span style='color:#ff5555;font-weight:bold;'>[ERROR] " + ev.message + "</span>", "[ERROR] " + ev.message)
        }
    }

    function appendLine(type, styledText, rawText) {
        terminalModel.append({
            timestamp: getTimestamp(),
            lineType: type,
            text: styledText || "",
            raw: rawText || ""
        })
        if (terminalModel.count > 1500) {
            terminalModel.remove(0, 100)
        }
    }

    // Command execution
    function executeCommand(cmdStr) {
        var raw = (cmdStr !== undefined ? cmdStr : cmdInput.text).trim()
        if (!raw) return

        if (isProcessRunning) {
            sendStdin(raw)
            cmdInput.text = ""
            return
        }

        if (commandHistory.length === 0 || commandHistory[commandHistory.length - 1] !== raw) {
            commandHistory.push(raw)
        }
        historyIndex = -1
        savedDraftInput = ""

        appendLine("cmd", "<span style='color:#0066ff;font-weight:bold;'>auditx:~$ </span><span style='color:#ffffff;font-weight:600;'>" + raw + "</span>", "auditx:~$ " + raw)
        cmdInput.text = ""

        var targetsObj = {
            "ip": targetIp.trim(),
            "domain": targetDomain.trim(),
            "url": targetUrl.trim(),
            "cloud": targetCloud.trim(),
            "path": targetPath.trim(),
            "username": targetUsername.trim(),
            "interface": targetInterface.trim()
        }

        var cmdArgs = [
            "python3", backendPath, "terminal-exec",
            "--command", raw,
            "--targets", JSON.stringify(targetsObj)
        ]

        activeCmd = raw
        isProcessRunning = true
        ptyProcess.command = cmdArgs
        ptyProcess.running = true
    }

    // Stdin forwarding
    function sendStdin(inputStr) {
        if (!ptyProcess.running) return
        ptyProcess.write(inputStr + "\n")
        appendLine("out", "<span style='color:#888888;'>&gt; " + inputStr + "</span>", "> " + inputStr)
    }

    // Signal interrupt
    function interruptProcess() {
        if (!isProcessRunning && !ptyProcess.running) return
        appendLine("system", "<span style='color:#ff5555;font-weight:bold;'>^C [Interrupt Signal Sent]</span>", "^C")
        try {
            ptyProcess.write("__AUDITX_SIGNAL_INT__\n")
            ptyProcess.signal(2) // SIGINT
        } catch (e) {
            console.warn("Signal error: " + e)
        }
    }

    function clearTerminal() {
        terminalModel.clear()
        appendWelcomeBanner()
    }

    function copyAllOutput() {
        var full = ""
        for (var i = 0; i < terminalModel.count; i++) {
            var item = terminalModel.get(i)
            full += (item.raw || "") + "\n"
        }
        try {
            Quickshell.clipboardText = full
            appendLine("system", "<span style='color:#50fa7b;'>[✓] Terminal buffer copied to clipboard.</span>", "[✓] Copied.")
        } catch (e) {
            console.warn("Clipboard error: " + e)
        }
    }

    // Header bar
    Rectangle {
        id: header
        anchors { top: parent.top; left: parent.left; right: parent.right }
        height: 38
        color: "#0a0a0a"
        radius: 6

        Rectangle {
            anchors { bottom: parent.bottom; left: parent.left; right: parent.right }
            height: 10
            color: parent.color
        }

        Row {
            id: titleRow
            anchors { left: parent.left; leftMargin: 12; verticalCenter: parent.verticalCenter }
            spacing: 8

            Rectangle {
                width: 7; height: 7; radius: 3.5
                color: isProcessRunning ? "#0066ff" : "#50fa7b"
                anchors.verticalCenter: parent.verticalCenter
                SequentialAnimation on opacity {
                    running: isProcessRunning
                    loops: Animation.Infinite
                    NumberAnimation { to: 0.2; duration: 400 }
                    NumberAnimation { to: 1.0; duration: 400 }
                }
            }
            Text {
                anchors.verticalCenter: parent.verticalCenter
                text: "TERMINAL"
                font.pixelSize: 11
                font.family: "JetBrains Mono, Fira Mono, monospace"
                font.weight: 700
                color: "#ffffff"
                font.letterSpacing: 0.5
            }
            Rectangle {
                width: 1; height: 16
                color: "#222222"
                anchors.verticalCenter: parent.verticalCenter
            }

            Rectangle {
                height: 20
                width: shellText.implicitWidth + 12
                radius: 4
                color: "#111111"
                border.color: "#222222"
                border.width: 1
                anchors.verticalCenter: parent.verticalCenter

                Text {
                    id: shellText
                    anchors.centerIn: parent
                    text: isProcessRunning ? ("BASH [PID " + activePid + "]") : "BASH / PTY"
                    font.pixelSize: 9
                    font.family: "JetBrains Mono, Fira Mono, monospace"
                    font.weight: 600
                    color: isProcessRunning ? "#0066ff" : "#888888"
                }
            }

            Rectangle {
                height: 20
                width: targetLabel.implicitWidth + 14
                radius: 4
                color: "#0f172a"
                border.color: "#1e293b"
                border.width: 1
                anchors.verticalCenter: parent.verticalCenter

                Text {
                    id: targetLabel
                    anchors.centerIn: parent
                    text: "$TARGET: " + (primaryTarget || "none")
                    font.pixelSize: 9
                    font.family: "JetBrains Mono, Fira Mono, monospace"
                    font.weight: 500
                    color: "#38bdf8"
                }
            }
        }

        Row {
            id: actionsRow
            anchors { right: parent.right; rightMargin: 10; verticalCenter: parent.verticalCenter }
            spacing: 8

            Text {
                anchors.verticalCenter: parent.verticalCenter
                text: terminalModel.count + " lines"
                font.pixelSize: 9
                font.family: "JetBrains Mono, Fira Mono, monospace"
                color: "#555555"
            }

            Rectangle {
                width: 64; height: 22; radius: 4
                visible: isProcessRunning
                color: intHover.containsMouse ? "#3b1111" : "#220a0a"
                border.color: "#ff4444"
                border.width: 1
                Behavior on color { ColorAnimation { duration: 100 } }

                Row {
                    anchors.centerIn: parent
                    spacing: 4
                    Text {
                        text: "■"
                        font.pixelSize: 8
                        color: "#ff5555"
                        anchors.verticalCenter: parent.verticalCenter
                    }
                    Text {
                        text: "CTRL+C"
                        font.pixelSize: 9
                        font.family: "JetBrains Mono, Fira Mono, monospace"
                        font.weight: 700
                        color: "#ff8888"
                        anchors.verticalCenter: parent.verticalCenter
                    }
                }

                MouseArea {
                    id: intHover
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: root.interruptProcess()
                }
            }

            Rectangle {
                width: 48; height: 22; radius: 4
                color: copyHover.containsMouse ? "#111111" : "transparent"
                border.color: copyHover.containsMouse ? "#222222" : "transparent"
                border.width: 1
                Behavior on color { ColorAnimation { duration: 100 } }

                Text {
                    anchors.centerIn: parent
                    text: "COPY"
                    font.pixelSize: 9
                    font.family: "JetBrains Mono, Fira Mono, monospace"
                    font.weight: 500
                    color: "#777777"
                }

                MouseArea {
                    id: copyHover
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: root.copyAllOutput()
                }
            }

            Rectangle {
                width: 52; height: 22; radius: 4
                color: clearHover.containsMouse ? "#111111" : "transparent"
                border.color: clearHover.containsMouse ? "#222222" : "transparent"
                border.width: 1
                Behavior on color { ColorAnimation { duration: 100 } }

                Text {
                    anchors.centerIn: parent
                    text: "CLEAR"
                    font.pixelSize: 9
                    font.family: "JetBrains Mono, Fira Mono, monospace"
                    font.weight: 500
                    color: "#777777"
                }

                MouseArea {
                    id: clearHover
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: root.clearTerminal()
                }
            }
        }
    }

    // Output view
    ListView {
        id: outputView
        anchors {
            top: header.bottom; bottom: quickActionBar.top
            left: parent.left; right: parent.right
            margins: 6; topMargin: 4; bottomMargin: 4
        }
        model: terminalModel
        clip: true
        spacing: 2

        ScrollBar.vertical: ScrollBar {
            policy: ScrollBar.AsNeeded
            contentItem: Rectangle {
                implicitWidth: 4
                radius: 2
                color: "#222222"
            }
        }

        delegate: Row {
            width: outputView.width - 16
            x: 8
            spacing: 8

            Text {
                text: model.timestamp || ""
                font.pixelSize: 9
                font.family: "JetBrains Mono, Fira Mono, monospace"
                color: "#333333"
                topPadding: 2
            }

            Text {
                text: model.text || ""
                textFormat: Text.RichText
                font.pixelSize: 11
                font.family: "JetBrains Mono, Fira Mono, monospace"
                color: "#cccccc"
                width: outputView.width - 90
                wrapMode: Text.WrapAnywhere
                lineHeight: 1.35
            }
        }

        onCountChanged: {
            Qt.callLater(() => outputView.positionViewAtEnd())
        }
    }

    // Quick snippets
    Rectangle {
        id: quickActionBar
        anchors { bottom: inputContainer.top; left: parent.left; right: parent.right }
        height: 30
        color: "#080808"
        border.color: "#141414"
        border.width: 1

        ScrollView {
            anchors.fill: parent
            anchors.leftMargin: 8; anchors.rightMargin: 8
            clip: true
            ScrollBar.vertical.policy: ScrollBar.AlwaysOff
            ScrollBar.horizontal.policy: ScrollBar.AlwaysOff

            Row {
                spacing: 6
                height: 30
                anchors.verticalCenter: parent.verticalCenter

                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    text: "SNIPPETS:"
                    font.pixelSize: 9
                    font.family: "JetBrains Mono, Fira Mono, monospace"
                    font.weight: 700
                    color: "#444444"
                }

                Repeater {
                    model: [
                        ["Ping $IP", "ping -c 3 $IP"],
                        ["Curl -I $URL", "curl -sI $URL"],
                        ["Nmap Fast $IP", "nmap -F -sV $IP"],
                        ["Whois $DOMAIN", "whois $DOMAIN"],
                        ["WhatWeb $URL", "whatweb $URL"],
                        ["Nikto $URL", "nikto -h $URL"],
                        ["Dig $DOMAIN", "dig +short $DOMAIN ANY"],
                        ["Traceroute $IP", "traceroute $IP"]
                    ]

                    Rectangle {
                        height: 20
                        width: snipText.implicitWidth + 12
                        radius: 3
                        color: snipHover.containsMouse ? "#181818" : "#0d0d0d"
                        border.color: snipHover.containsMouse ? "#0066ff" : "#1a1a1a"
                        border.width: 1
                        anchors.verticalCenter: parent.verticalCenter
                        Behavior on color { ColorAnimation { duration: 100 } }
                        Behavior on border.color { ColorAnimation { duration: 100 } }

                        Text {
                            id: snipText
                            anchors.centerIn: parent
                            text: modelData[0]
                            font.pixelSize: 9
                            font.family: "JetBrains Mono, Fira Mono, monospace"
                            color: snipHover.containsMouse ? "#ffffff" : "#888888"
                        }

                        MouseArea {
                            id: snipHover
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: {
                                cmdInput.text = modelData[1]
                                cmdInput.forceActiveFocus()
                            }
                        }
                    }
                }
            }
        }
    }

    // Input prompt
    Rectangle {
        id: inputContainer
        anchors { bottom: parent.bottom; left: parent.left; right: parent.right }
        height: 42
        color: "#0a0a0a"
        border.color: "#1a1a1a"
        border.width: 1

        Row {
            anchors { fill: parent; leftMargin: 12; rightMargin: 8 }
            spacing: 8

            Row {
                anchors.verticalCenter: parent.verticalCenter
                spacing: 4

                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    text: isProcessRunning ? "stdin>" : "auditx:~$ "
                    font.pixelSize: 11
                    font.family: "JetBrains Mono, Fira Mono, monospace"
                    font.weight: 700
                    color: isProcessRunning ? "#f1fa8c" : "#0066ff"
                }
            }

            Item {
                width: parent.width - 150
                height: parent.height
                anchors.verticalCenter: parent.verticalCenter

                TextInput {
                    id: cmdInput
                    anchors {
                        left: parent.left; right: parent.right
                        verticalCenter: parent.verticalCenter
                    }
                    font.pixelSize: 11
                    font.family: "JetBrains Mono, Fira Mono, monospace"
                    color: "#ffffff"
                    selectionColor: "#0066ff"
                    selectedTextColor: "#ffffff"
                    clip: true
                    activeFocusOnPress: true

                    Text {
                        anchors.left: parent.left
                        anchors.verticalCenter: parent.verticalCenter
                        text: isProcessRunning ? "Send input to process stdin..." : "Enter bash command or tool... (Up/Down for history)"
                        font.pixelSize: 11
                        font.family: "JetBrains Mono, Fira Mono, monospace"
                        color: "#444444"
                        visible: !cmdInput.text && !cmdInput.activeFocus
                    }

                    Keys.onReturnPressed: root.executeCommand()
                    Keys.onEnterPressed: root.executeCommand()

                    Keys.onUpPressed: {
                        if (commandHistory.length === 0) return
                        if (historyIndex === -1) {
                            savedDraftInput = cmdInput.text
                            historyIndex = commandHistory.length - 1
                        } else if (historyIndex > 0) {
                            historyIndex--
                        }
                        cmdInput.text = commandHistory[historyIndex]
                        cmdInput.cursorPosition = cmdInput.text.length
                    }

                    Keys.onDownPressed: {
                        if (historyIndex === -1) return
                        if (historyIndex < commandHistory.length - 1) {
                            historyIndex++
                            cmdInput.text = commandHistory[historyIndex]
                        } else {
                            historyIndex = -1
                            cmdInput.text = savedDraftInput
                        }
                        cmdInput.cursorPosition = cmdInput.text.length
                    }

                    Keys.onEscapePressed: {
                        cmdInput.text = ""
                        historyIndex = -1
                    }
                }
            }

            Rectangle {
                width: 60; height: 26
                radius: 4
                anchors.verticalCenter: parent.verticalCenter
                color: runHover.containsMouse ? (isProcessRunning ? "#ca8a04" : "#0052cc") : (isProcessRunning ? "#854d0e" : "#0066ff")
                Behavior on color { ColorAnimation { duration: 120 } }

                Text {
                    anchors.centerIn: parent
                    text: isProcessRunning ? "SEND ↵" : "RUN ↵"
                    font.pixelSize: 10
                    font.family: "JetBrains Mono, Fira Mono, monospace"
                    font.weight: 700
                    color: "#ffffff"
                }

                MouseArea {
                    id: runHover
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: root.executeCommand()
                }
            }
        }
    }
}
