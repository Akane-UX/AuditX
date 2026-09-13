import QtQuick
import QtQuick.Controls

Rectangle {
    id: root

    property string toolName: ""
    property string displayName: ""
    property string category: ""
    property string description: ""
    property bool isEnabled: true
    property bool isInstalled: false
    property bool isRunning: false
    property bool isDone: false
    property bool hasFailed: false

    signal toggled(bool enabled)

    width: 220
    height: 70
    radius: 8

    color: {
        if (isRunning) return "#131b26"
        if (isDone)    return "#111815"
        if (hasFailed) return "#1c1212"
        return isEnabled ? "#12151f" : "#0a0c12"
    }

    border.color: {
        if (isRunning) return "#2a4a7a"
        if (isDone)    return "#2a5a3a"
        if (hasFailed) return "#7a2a2a"
        return isEnabled ? "#1e2638" : "#111520"
    }
    border.width: 1

    Behavior on color       { ColorAnimation { duration: 150 } }
    Behavior on border.color { ColorAnimation { duration: 150 } }

    Column {
        anchors {
            left: parent.left; right: parent.right
            top: parent.top; bottom: parent.bottom
            leftMargin: 12; rightMargin: 32 // leave space for checkbox
            topMargin: 10; bottomMargin: 10
        }
        spacing: 4

        Row {
            width: parent.width
            spacing: 8

            // Subtle Status Indicator
            Rectangle {
                width: 6; height: 6
                radius: 3
                anchors.verticalCenter: parent.verticalCenter
                color: {
                    if (isRunning) return "#5b8fff"
                    if (isDone)    return "#39ff7a"
                    if (hasFailed) return "#ff4a4a"
                    return isInstalled ? "#4a9f7a" : "#444"
                }
                
                SequentialAnimation on opacity {
                    running: isRunning
                    loops: Animation.Infinite
                    NumberAnimation { to: 0.2; duration: 600 }
                    NumberAnimation { to: 1.0; duration: 600 }
                }
            }

            Text {
                text: root.displayName
                font.pixelSize: 12
                font.weight: 600
                font.family: "JetBrains Mono, Fira Mono, monospace"
                color: isEnabled ? "#d8e8ff" : "#556"
                Behavior on color { ColorAnimation { duration: 150 } }
            }
            
            // Missing badge
            Rectangle {
                visible: !isInstalled
                anchors.verticalCenter: parent.verticalCenter
                width: missingLabel.implicitWidth + 8; height: 14
                radius: 4
                color: "#1a1310"
                border.color: "#3a2a1a"
                Text {
                    id: missingLabel
                    anchors.centerIn: parent
                    text: "missing"
                    font.pixelSize: 8
                    font.family: "JetBrains Mono, Fira Mono, monospace"
                    color: "#ff9f40"
                }
            }
        }

        Text {
            text: root.description
            font.pixelSize: 10
            font.family: "Inter, sans-serif"
            color: isEnabled ? "#7a8a9a" : "#445"
            width: parent.width
            elide: Text.ElideRight
            maximumLineCount: 2
            wrapMode: Text.WordWrap
            lineHeight: 1.2
            Behavior on color { ColorAnimation { duration: 150 } }
        }
    }

    // Modern Checkbox overlay
    Rectangle {
        anchors { right: parent.right; verticalCenter: parent.verticalCenter; rightMargin: 12 }
        width: 16; height: 16
        radius: 4
        color: isEnabled ? "#5b8fff" : "transparent"
        border.color: isEnabled ? "#5b8fff" : "#3a4a6a"
        border.width: 1

        Behavior on color { ColorAnimation { duration: 150 } }

        Text {
            anchors.centerIn: parent
            text: "✓"
            font.pixelSize: 10
            font.weight: 800
            color: "#0a0b12"
            opacity: isEnabled ? 1 : 0
            Behavior on opacity { NumberAnimation { duration: 150 } }
        }
    }

    MouseArea {
        anchors.fill: parent
        cursorShape: Qt.PointingHandCursor
        hoverEnabled: true
        onEntered: root.border.color = Qt.binding(function(){ return isEnabled ? "#3a4a7a" : "#2a3a5a" })
        onExited: root.border.color = Qt.binding(function(){ 
            if (isRunning) return "#2a4a7a"
            if (isDone)    return "#2a5a3a"
            if (hasFailed) return "#7a2a2a"
            return isEnabled ? "#1e2638" : "#111520"
        })
        onClicked: {
            root.isEnabled = !root.isEnabled
            root.toggled(root.isEnabled)
        }
    }
}
