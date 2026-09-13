import QtQuick
import QtQuick.Controls

// ConsoleView.qml — Real-time streaming output terminal
Rectangle {
    id: root

    property alias model: logList.model
    property string currentTool: ""

    color: "#09090f"
    radius: 10
    clip: true

    // Scanline overlay for terminal feel
    Rectangle {
        anchors.fill: parent
        z: 10
        color: "transparent"
        opacity: 0.03
        Rectangle {
            anchors.fill: parent
            color: Qt.rgba(0, 1, 0.2, 0.05)
        }
    }

    // Header bar
    Rectangle {
        id: header
        anchors { top: parent.top; left: parent.left; right: parent.right }
        height: 36
        color: "#0e0e18"
        radius: 10

        // Square bottom
        Rectangle {
            anchors { bottom: parent.bottom; left: parent.left; right: parent.right }
            height: 10
            color: parent.color
        }

        Row {
            anchors { left: parent.left; verticalCenter: parent.verticalCenter; leftMargin: 14 }
            spacing: 7

            Repeater {
                model: ["#ff5f57", "#febc2e", "#28c840"]
                Rectangle {
                    width: 10; height: 10; radius: 5
                    color: modelData
                    opacity: 0.8
                }
            }
        }

        Text {
            anchors.centerIn: parent
            text: currentTool !== "" ? "● " + currentTool.toUpperCase() : "CONSOLE"
            font.pixelSize: 11
            font.family: "JetBrains Mono, Fira Mono, monospace"
            font.weight: 500
            color: currentTool !== "" ? "#39ff7a" : "#444"
            Behavior on color { ColorAnimation { duration: 200 } }
        }

        // Clear button
        Rectangle {
            anchors { right: parent.right; verticalCenter: parent.verticalCenter; rightMargin: 10 }
            width: 52; height: 22; radius: 5
            color: clearHover.containsMouse ? "#1a2030" : "transparent"
            border.color: clearHover.containsMouse ? "#2a3050" : "transparent"
            Behavior on color { ColorAnimation { duration: 100 } }

            Text {
                anchors.centerIn: parent
                text: "CLEAR"
                font.pixelSize: 9
                font.family: "JetBrains Mono, Fira Mono, monospace"
                font.weight: 500
                color: "#445"
            }

            MouseArea {
                id: clearHover
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: {
                    logList.model.clear()
                }
            }
        }
    }

    // Log list
    ListView {
        id: logList
        anchors {
            top: header.bottom; bottom: parent.bottom
            left: parent.left; right: parent.right
            margins: 4; topMargin: 6; bottomMargin: 6
        }

        model: ListModel {}
        clip: true
        spacing: 1

        ScrollBar.vertical: ScrollBar {
            policy: ScrollBar.AsNeeded
            contentItem: Rectangle {
                implicitWidth: 4
                radius: 2
                color: "#2a3050"
            }
        }

        delegate: Row {
            width: logList.width - 16
            x: 8
            spacing: 8

            Text {
                text: model.timestamp || ""
                font.pixelSize: 10
                font.family: "JetBrains Mono, Fira Mono, monospace"
                color: "#2a3a5a"
                topPadding: 1
            }

            Text {
                text: model.prefix || ""
                font.pixelSize: 10
                font.family: "JetBrains Mono, Fira Mono, monospace"
                font.weight: 700
                color: model.prefixColor || "#39ff7a"
                topPadding: 1
            }

            Text {
                text: model.text || ""
                font.pixelSize: 10
                font.family: "JetBrains Mono, Fira Mono, monospace"
                color: model.textColor || "#a8b8d8"
                width: logList.width - 140
                wrapMode: Text.WrapAnywhere
                lineHeight: 1.4
            }
        }

        onCountChanged: {
            Qt.callLater(() => logList.positionViewAtEnd())
        }
    }

    function appendLine(prefix, prefixColor, text, textColor) {
        var d = new Date()
        var ts = d.getHours().toString().padStart(2,'0') + ':'
                + d.getMinutes().toString().padStart(2,'0') + ':'
                + d.getSeconds().toString().padStart(2,'0')
        logList.model.append({
            timestamp: ts,
            prefix: prefix,
            prefixColor: prefixColor || "#39ff7a",
            text: text,
            textColor: textColor || "#a8b8d8"
        })
    }

    function info(text)    { appendLine("[INFO]",    "#5b8fff", text, "#a8b8d8") }
    function success(text) { appendLine("[OK]",      "#2eff9f", text, "#c8f8d8") }
    function warn(text)    { appendLine("[WARN]",    "#ff9f40", text, "#f8d8a8") }
    function error(text)   { appendLine("[ERROR]",   "#ff4040", text, "#f8a8a8") }
    function output(tool, text) {
        appendLine("[" + tool.toUpperCase() + "]", "#39ff7a", text, "#8a9fb8")
    }
    function system(text)  { appendLine("[SYS]",    "#6677aa", text, "#667788") }
}
