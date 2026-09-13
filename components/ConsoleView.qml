import QtQuick
import QtQuick.Controls

// ConsoleView.qml — Real-time streaming output terminal
Rectangle {
    id: root

    property alias model: logList.model
    property string currentTool: ""

    color: "#050505"
    radius: 6
    clip: true
    border.color: "#111111"
    border.width: 1

    // Header bar
    Rectangle {
        id: header
        anchors { top: parent.top; left: parent.left; right: parent.right }
        height: 36
        color: "#0a0a0a"
        radius: 6

        // Square bottom
        Rectangle {
            anchors { bottom: parent.bottom; left: parent.left; right: parent.right }
            height: 10
            color: parent.color
        }

        Text {
            anchors.left: parent.left; anchors.leftMargin: 14
            anchors.verticalCenter: parent.verticalCenter
            text: currentTool !== "" ? "● " + currentTool.toUpperCase() : "CONSOLE"
            font.pixelSize: 11
            font.family: "JetBrains Mono, Fira Mono, monospace"
            font.weight: 500
            color: currentTool !== "" ? "#0066ff" : "#555555"
            Behavior on color { ColorAnimation { duration: 200 } }
        }

        // Clear button
        Rectangle {
            anchors { right: parent.right; verticalCenter: parent.verticalCenter; rightMargin: 10 }
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
                color: "#666666"
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
                color: "#222222"
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
                color: "#444444"
                topPadding: 1
            }

            Text {
                text: model.prefix || ""
                font.pixelSize: 10
                font.family: "JetBrains Mono, Fira Mono, monospace"
                font.weight: 700
                color: model.prefixColor || "#0066ff"
                topPadding: 1
            }

            Text {
                text: model.text || ""
                font.pixelSize: 10
                font.family: "JetBrains Mono, Fira Mono, monospace"
                color: model.textColor || "#aaaaaa"
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
            prefixColor: prefixColor || "#0066ff",
            text: text,
            textColor: textColor || "#aaaaaa"
        })
    }

    function info(text)    { appendLine("[INFO]",    "#0066ff", text, "#aaaaaa") }
    function success(text) { appendLine("[OK]",      "#0066ff", text, "#cccccc") }
    function warn(text)    { appendLine("[WARN]",    "#666666", text, "#bbbbbb") }
    function error(text)   { appendLine("[ERROR]",   "#ff3333", text, "#dddddd") }
    function output(tool, text) {
        appendLine("[" + tool.toUpperCase() + "]", "#0047b3", text, "#888888")
    }
    function system(text)  { appendLine("[SYS]",    "#444444", text, "#666666") }
}
