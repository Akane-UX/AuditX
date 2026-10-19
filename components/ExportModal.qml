import QtQuick
import QtQuick.Controls
import Quickshell.Io

Item {
    id: root

    property bool   isVisible: false
    property string target: ""
    property string overallRisk: "CLEAN"
    property string riskColor: "#00cc44"
    property int    secretsCount: 0
    property int    vulnCount: 0
    property int    portsCount: 0
    property string reportContent: ""
    property string filePath: ""
    property string selectedFormat: "md" // "md" | "json" | "txt"

    property string statusMessage: ""
    property bool   isSuccess: false
    property bool   isBusy: false

    anchors.fill: parent
    visible: isVisible
    z: 9999

    function openModal() {
        generateDefaultPath()
        statusMessage = ""
        isSuccess = false
        isBusy = false
        isVisible = true
    }

    function closeModal() {
        isVisible = false
    }

    function generateDefaultPath() {
        var baseName = (target && target.trim()) ? target.trim().replace(/[^a-zA-Z0-9_\-\.]/g, "_") : "general"
        var now = new Date()
        var y = now.getFullYear()
        var m = String(now.getMonth() + 1).padStart(2, "0")
        var d = String(now.getDate()).padStart(2, "0")
        var hh = String(now.getHours()).padStart(2, "0")
        var mm = String(now.getMinutes()).padStart(2, "0")
        var ss = String(now.getSeconds()).padStart(2, "0")
        var dateStr = y + "-" + m + "-" + d + "_" + hh + mm + ss

        var dir = "/home/avrlln/Documents"
        filePath = dir + "/AuditX_Report_" + baseName + "_" + dateStr + "." + selectedFormat
    }

    function setFolder(newDir) {
        var parts = filePath.split("/")
        var currentFileName = parts[parts.length - 1]
        if (!currentFileName || currentFileName.indexOf(".") === -1) {
            currentFileName = "AuditX_Report." + selectedFormat
        }
        filePath = newDir.replace(/\/+$/, "") + "/" + currentFileName
    }

    function changeFormat(fmt) {
        selectedFormat = fmt
        if (filePath.lastIndexOf(".") !== -1) {
            filePath = filePath.substring(0, filePath.lastIndexOf(".")) + "." + fmt
        } else {
            filePath = filePath + "." + fmt
        }
    }

    // Process to safely write report to disk
    Process {
        id: saveProcess

        stdout: SplitParser {
            onRead: function(data) {
                isBusy = false
                try {
                    var ev = JSON.parse(data.trim())
                    if (ev.success) {
                        isSuccess = true
                        statusMessage = "Report saved: " + ev.path
                    } else {
                        isSuccess = false
                        statusMessage = "Failed: " + (ev.error || "Unknown error")
                    }
                } catch(e) {
                    isSuccess = true
                    statusMessage = "Report saved to destination."
                }
            }
        }

        stderr: SplitParser {
            onRead: function(data) {
                isBusy = false
                isSuccess = false
                statusMessage = "Error: " + data.trim()
            }
        }
    }

    function executeSave() {
        if (!filePath || filePath.trim().length === 0) {
            statusMessage = "Please specify a destination file path."
            isSuccess = false
            return
        }

        isBusy = true
        statusMessage = "Writing report file..."
        isSuccess = false

        saveProcess.command = [
            "python3", "-c",
            "import sys, pathlib, json\n" +
            "p = pathlib.Path(sys.argv[1]).expanduser().resolve()\n" +
            "p.parent.mkdir(parents=True, exist_ok=True)\n" +
            "p.write_text(sys.argv[2], encoding='utf-8')\n" +
            "print(json.dumps({'event': 'export_done', 'path': str(p), 'success': True}))",
            filePath.trim(),
            reportContent
        ]
        saveProcess.running = true
    }

    // Backdrop overlay
    Rectangle {
        anchors.fill: parent
        color: "#000000cc"

        MouseArea {
            anchors.fill: parent
            onClicked: {
                if (!root.isBusy) root.closeModal()
            }
        }
    }

    // Modal Card
    Rectangle {
        id: dialogCard
        width: Math.min(parent.width - 48, 580)
        height: cardCol.implicitHeight + 36
        anchors.centerIn: parent
        color: "#0a0a0a"
        border.color: "#222222"
        border.width: 1
        radius: 8
        clip: true

        MouseArea {
            anchors.fill: parent
            // Prevent clicks inside card from bubbling to backdrop
        }

        Column {
            id: cardCol
            anchors {
                top: parent.top; topMargin: 18
                left: parent.left; leftMargin: 20
                right: parent.right; rightMargin: 20
            }
            spacing: 14

            // Header Row
            Row {
                width: parent.width
                spacing: 8

                Rectangle {
                    width: 24; height: 24; radius: 4
                    color: "#111827"
                    border.color: "#1e3a8a"; border.width: 1
                    anchors.verticalCenter: parent.verticalCenter
                    Text {
                        anchors.centerIn: parent
                        text: "💾"
                        font.pixelSize: 12
                    }
                }

                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    text: "EXPORT AUDIT REPORT"
                    font.pixelSize: 12
                    font.weight: 700
                    font.family: "JetBrains Mono, monospace"
                    color: "#ffffff"
                    font.letterSpacing: 0.5
                }

                Item {
                    width: Math.max(0, parent.width - 320)
                    height: 1
                }

                Rectangle {
                    width: 24; height: 24; radius: 4
                    color: closeHover.containsMouse ? "#222222" : "transparent"
                    border.color: closeHover.containsMouse ? "#333333" : "transparent"
                    border.width: 1
                    anchors.verticalCenter: parent.verticalCenter

                    Text {
                        anchors.centerIn: parent
                        text: "✕"
                        font.pixelSize: 11
                        font.family: "JetBrains Mono, monospace"
                        color: "#888888"
                    }

                    MouseArea {
                        id: closeHover
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: root.closeModal()
                    }
                }
            }

            Rectangle { width: parent.width; height: 1; color: "#161616" }

            // Target & Finding Metrics Summary Banner
            Rectangle {
                width: parent.width
                height: 38
                radius: 4
                color: "#080808"
                border.color: "#181818"; border.width: 1

                Row {
                    anchors.centerIn: parent
                    spacing: 12

                    Text {
                        text: "Target: " + (root.target ? root.target : "All Scans")
                        font.pixelSize: 10
                        font.weight: 600
                        font.family: "JetBrains Mono, monospace"
                        color: "#0066ff"
                    }
                    Text { text: "•"; color: "#333333"; font.pixelSize: 10 }
                    Text {
                        text: root.overallRisk
                        font.pixelSize: 10
                        font.weight: 700
                        font.family: "JetBrains Mono, monospace"
                        color: root.riskColor
                    }
                    Text { text: "•"; color: "#333333"; font.pixelSize: 10 }
                    Text {
                        text: root.secretsCount + " Leaks / Secrets"
                        font.pixelSize: 10
                        font.weight: 600
                        font.family: "JetBrains Mono, monospace"
                        color: root.secretsCount > 0 ? "#ff3333" : "#888888"
                    }
                    Text { text: "•"; color: "#333333"; font.pixelSize: 10 }
                    Text {
                        text: root.vulnCount + " Vulns"
                        font.pixelSize: 10
                        font.family: "JetBrains Mono, monospace"
                        color: root.vulnCount > 0 ? "#ff9900" : "#888888"
                    }
                }
            }

            // Format Selection Row
            Row {
                spacing: 8
                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    text: "REPORT FORMAT:"
                    font.pixelSize: 9
                    font.weight: 700
                    font.family: "JetBrains Mono, monospace"
                    color: "#666666"
                }

                Repeater {
                    model: [
                        ["md",   "MARKDOWN (.MD) — Standard"],
                        ["json", "JSON (.JSON)"],
                        ["txt",  "RAW TEXT (.TXT)"]
                    ]

                    Rectangle {
                        height: 22
                        width: fmtLabel.implicitWidth + 14
                        radius: 4
                        color: root.selectedFormat === modelData[0] ? "#111827" : (fmtHover.containsMouse ? "#111111" : "#080808")
                        border.color: root.selectedFormat === modelData[0] ? "#0066ff" : (fmtHover.containsMouse ? "#222222" : "#161616")
                        border.width: 1

                        Text {
                            id: fmtLabel
                            anchors.centerIn: parent
                            text: modelData[1]
                            font.pixelSize: 9
                            font.family: "JetBrains Mono, monospace"
                            font.weight: root.selectedFormat === modelData[0] ? 600 : 400
                            color: root.selectedFormat === modelData[0] ? "#60a5fa" : "#777777"
                        }

                        MouseArea {
                            id: fmtHover
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: root.changeFormat(modelData[0])
                        }
                    }
                }
            }

            // Path Input Section
            Column {
                width: parent.width
                spacing: 6

                Text {
                    text: "DESTINATION FILE PATH (EDITABLE):"
                    font.pixelSize: 9
                    font.weight: 700
                    font.family: "JetBrains Mono, monospace"
                    color: "#888888"
                }

                Rectangle {
                    width: parent.width
                    height: 34
                    radius: 4
                    color: "#050505"
                    border.color: pathInput.activeFocus ? "#0066ff" : "#222222"
                    border.width: 1

                    TextInput {
                        id: pathInput
                        anchors {
                            fill: parent
                            leftMargin: 10; rightMargin: 10
                        }
                        verticalAlignment: TextInput.AlignVCenter
                        text: root.filePath
                        font.pixelSize: 11
                        font.family: "JetBrains Mono, monospace"
                        color: "#ffffff"
                        selectByMouse: true
                        onTextChanged: {
                            if (text !== root.filePath) {
                                root.filePath = text
                            }
                        }
                    }
                }

                // Quick Preset Directories
                Row {
                    spacing: 6
                    Text {
                        anchors.verticalCenter: parent.verticalCenter
                        text: "Quick Presets:"
                        font.pixelSize: 9
                        font.family: "JetBrains Mono, monospace"
                        color: "#555555"
                    }

                    Repeater {
                        model: [
                            ["Documents", "/home/avrlln/Documents"],
                            ["Desktop",   "/home/avrlln/Desktop"],
                            ["Home ~",    "/home/avrlln"],
                            ["/tmp",      "/tmp"]
                        ]

                        Rectangle {
                            height: 20
                            width: preText.implicitWidth + 10
                            radius: 3
                            color: preHover.containsMouse ? "#141414" : "#0d0d0d"
                            border.color: preHover.containsMouse ? "#2a2a2a" : "#181818"
                            border.width: 1

                            Text {
                                id: preText
                                anchors.centerIn: parent
                                text: modelData[0]
                                font.pixelSize: 9
                                font.family: "JetBrains Mono, monospace"
                                color: "#888888"
                            }

                            MouseArea {
                                id: preHover
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: root.setFolder(modelData[1])
                            }
                        }
                    }
                }
            }

            // Status feedback message
            Rectangle {
                width: parent.width
                height: 30
                radius: 4
                visible: root.statusMessage.length > 0
                color: root.isSuccess ? "#041a0d" : "#1a0404"
                border.color: root.isSuccess ? "#00cc44" : "#ff3333"
                border.width: 1

                Row {
                    anchors {
                        fill: parent
                        leftMargin: 10; rightMargin: 10
                    }
                    spacing: 8

                    Text {
                        anchors.verticalCenter: parent.verticalCenter
                        text: root.isSuccess ? "✔" : "⚠"
                        font.pixelSize: 11
                        color: root.isSuccess ? "#00cc44" : "#ff3333"
                    }
                    Text {
                        anchors.verticalCenter: parent.verticalCenter
                        text: root.statusMessage
                        font.pixelSize: 10
                        font.family: "JetBrains Mono, monospace"
                        color: root.isSuccess ? "#66ff99" : "#ff8888"
                        elide: Text.ElideMiddle
                        width: parent.width - 24
                    }
                }
            }

            Rectangle { width: parent.width; height: 1; color: "#161616" }

            // Action Buttons Row
            Row {
                anchors.right: parent.right
                spacing: 10

                // Cancel Button
                Rectangle {
                    width: 80; height: 30; radius: 4
                    color: cancelHover.containsMouse ? "#161616" : "#0f0f0f"
                    border.color: "#222222"; border.width: 1

                    Text {
                        anchors.centerIn: parent
                        text: "Cancel"
                        font.pixelSize: 10
                        font.family: "JetBrains Mono, monospace"
                        color: "#888888"
                    }

                    MouseArea {
                        id: cancelHover
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: root.closeModal()
                    }
                }

                // Save Button
                Rectangle {
                    width: 120; height: 30; radius: 4
                    color: root.isBusy ? "#003380" : (saveHover.containsMouse ? "#0055d4" : "#0066ff")
                    border.color: "#0047b3"; border.width: 1

                    Row {
                        anchors.centerIn: parent
                        spacing: 6
                        Text {
                            text: root.isBusy ? "⏳" : "💾"
                            font.pixelSize: 11
                        }
                        Text {
                            text: root.isBusy ? "SAVING..." : "SAVE REPORT"
                            font.pixelSize: 10
                            font.weight: 700
                            font.family: "JetBrains Mono, monospace"
                            color: "#ffffff"
                        }
                    }

                    MouseArea {
                        id: saveHover
                        anchors.fill: parent
                        enabled: !root.isBusy
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: root.executeSave()
                    }
                }
            }
        }
    }
}
