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
    radius: 4

    color: {
        if (isRunning) return "#001a33"
        if (isDone)    return "#051105"
        if (hasFailed) return "#1a0505"
        return isEnabled ? "#111111" : "#050505"
    }

    border.color: {
        if (isRunning) return "#0066ff"
        if (isDone)    return "#111111"
        if (hasFailed) return "#ff3333"
        return isEnabled ? "#222222" : "#111111"
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
                    if (isRunning) return "#0066ff"
                    if (isDone)    return "#00cc44"
                    if (hasFailed) return "#ff3333"
                    return isInstalled ? "#0066ff" : "#333333"
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
                color: isEnabled ? "#ffffff" : "#666666"
                Behavior on color { ColorAnimation { duration: 150 } }
            }
            
            // Missing badge
            Rectangle {
                visible: !isInstalled
                anchors.verticalCenter: parent.verticalCenter
                width: missingLabel.implicitWidth + 8; height: 14
                radius: 4
                color: "#111111"
                border.color: "#333333"
                Text {
                    id: missingLabel
                    anchors.centerIn: parent
                    text: "missing"
                    font.pixelSize: 8
                    font.family: "JetBrains Mono, Fira Mono, monospace"
                    color: "#666666"
                }
            }
        }

        Text {
            text: root.description
            font.pixelSize: 10
            font.family: "Inter, sans-serif"
            color: isEnabled ? "#888888" : "#444444"
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
        color: isEnabled ? "#0066ff" : "transparent"
        border.color: isEnabled ? "#0066ff" : "#333333"
        border.width: 1

        Behavior on color { ColorAnimation { duration: 150 } }

        Text {
            anchors.centerIn: parent
            text: "✓"
            font.pixelSize: 10
            font.weight: 800
            color: "#000000"
            opacity: isEnabled ? 1 : 0
            Behavior on opacity { NumberAnimation { duration: 150 } }
        }
    }

    MouseArea {
        anchors.fill: parent
        cursorShape: Qt.PointingHandCursor
        hoverEnabled: true
        onEntered: root.border.color = Qt.binding(function(){ return isEnabled ? "#0066ff" : "#222222" })
        onExited: root.border.color = Qt.binding(function(){ 
            if (isRunning) return "#0066ff"
            if (isDone)    return "#111111"
            if (hasFailed) return "#ff3333"
            return isEnabled ? "#222222" : "#111111"
        })
        onClicked: {
            root.isEnabled = !root.isEnabled
            root.toggled(root.isEnabled)
        }
    }
}
