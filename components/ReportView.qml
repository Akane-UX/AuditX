import QtQuick
import QtQuick.Controls

// ReportView.qml — Structured audit report panel
Rectangle {
    id: root

    property string target: ""

    // Internal ListModel — reactive, no JS array binding issues
    ListModel {
        id: resultsModel
    }

    color: "#050505"
    radius: 6
    clip: true
    border.color: "#111111"
    border.width: 1

    // Header
    Rectangle {
        id: reportHeader
        anchors { top: parent.top; left: parent.left; right: parent.right }
        height: 36
        color: "#0a0a0a"
        radius: 6
        Rectangle {
            anchors { bottom: parent.bottom; left: parent.left; right: parent.right }
            height: 10; color: parent.color
        }

        Text {
            anchors.left: parent.left; anchors.leftMargin: 14
            anchors.verticalCenter: parent.verticalCenter
            text: "REPORT"
            font.pixelSize: 11
            font.family: "JetBrains Mono, Fira Mono, monospace"
            font.weight: 500
            color: "#555555"
        }

        // Export button
        Rectangle {
            anchors { right: parent.right; verticalCenter: parent.verticalCenter; rightMargin: 10 }
            width: 64; height: 22; radius: 4
            color: exportHover.containsMouse ? "#111111" : "transparent"
            border.color: exportHover.containsMouse ? "#222222" : "transparent"
            border.width: 1
            Behavior on color { ColorAnimation { duration: 100 } }

            Text {
                anchors.centerIn: parent
                text: "EXPORT"
                font.pixelSize: 9
                font.family: "JetBrains Mono, Fira Mono, monospace"
                color: "#0066ff"
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

    // Empty state
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
            text: "No results yet"
            font.pixelSize: 12
            font.family: "JetBrains Mono, Fira Mono, monospace"
            color: "#666666"
        }
        Text {
            anchors.horizontalCenter: parent.horizontalCenter
            text: "Run tools to generate a report"
            font.pixelSize: 10
            color: "#444444"
        }
    }

    // Results list
    ListView {
        id: resultList
        anchors {
            top: reportHeader.bottom; bottom: parent.bottom
            left: parent.left; right: parent.right
            margins: 10; topMargin: 12
        }
        spacing: 8
        clip: true

        model: resultsModel

        ScrollBar.vertical: ScrollBar {
            policy: ScrollBar.AsNeeded
            contentItem: Rectangle {
                implicitWidth: 4; radius: 2; color: "#222222"
            }
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

                // Tool header row
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

                // Divider
                Rectangle { width: parent.width; height: 1; color: "#111111"; opacity: 1.0 }

                // Output lines preview (last 8)
                Column {
                    width: parent.width
                    spacing: 2

                    Repeater {
                        // lines is stored as a JSON string; parse it back here
                        model: {
                            try {
                                var arr = JSON.parse(model.linesJson || "[]")
                                return arr.slice(-8)
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
                            try { return JSON.parse(model.linesJson || "[]").length > 8 } catch(e) { return false }
                        }
                        text: {
                            try { return "... " + (JSON.parse(model.linesJson || "[]").length - 8) + " more lines in console" } catch(e) { return "" }
                        }
                        font.pixelSize: 9
                        color: "#555555"
                    }
                }
            }
        }
    }

    // ── Public API called from shell.qml ──────────────────────────────────────

    function clear() {
        resultsModel.clear()
    }

    function addResult(toolName, displayName, status, lines) {
        // Check for existing entry first
        for (var i = 0; i < resultsModel.count; i++) {
            if (resultsModel.get(i).tool === toolName) {
                resultsModel.setProperty(i, "status", status)
                resultsModel.setProperty(i, "linesJson", JSON.stringify(lines || []))
                return
            }
        }
        resultsModel.append({
            tool:      toolName,
            display:   displayName,
            status:    status,
            linesJson: JSON.stringify(lines || [])
        })
    }

    function updateStatus(toolName, newStatus) {
        for (var i = 0; i < resultsModel.count; i++) {
            if (resultsModel.get(i).tool === toolName) {
                resultsModel.setProperty(i, "status", newStatus)
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

    function exportReport() {
        var lines = ["# AuditX Report", "# Target: " + root.target, "# Generated: " + new Date().toString(), ""]
        for (var i = 0; i < resultsModel.count; i++) {
            var r = resultsModel.get(i)
            lines.push("## " + (r.display || r.tool) + " [" + r.status.toUpperCase() + "]")
            try {
                var arr = JSON.parse(r.linesJson || "[]")
                lines = lines.concat(arr)
            } catch(e) {}
            lines.push("")
        }
        console.log("EXPORT:\n" + lines.join("\n"))
    }
}
