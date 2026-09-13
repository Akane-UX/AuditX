import QtQuick
import QtQuick.Controls

// ToolCard.qml — Individual tool selection card
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

    width: 200
    height: 88
    radius: 10

    // Dynamic background
    color: {
        if (isRunning) return "#1a2a1a"
        if (isDone)    return "#1a2a20"
        if (hasFailed) return "#2a1a1a"
        return isEnabled ? "#1a1f2e" : "#111420"
    }

    border.color: {
        if (isRunning) return "#39ff7a"
        if (isDone)    return "#2eff9f"
        if (hasFailed) return "#ff4040"
        return isEnabled ? "#2a3a5e" : "#1e2540"
    }
    border.width: isRunning ? 1.5 : 1

    Behavior on color       { ColorAnimation { duration: 200 } }
    Behavior on border.color { ColorAnimation { duration: 200 } }

    // Glow when running
    Rectangle {
        anchors.fill: parent
        radius: parent.radius
        color: "transparent"
        border.color: isRunning ? "#39ff7a" : "transparent"
        border.width: 6
        opacity: 0.15
        Behavior on border.color { ColorAnimation { duration: 200 } }
    }

    // Category color stripe
    Rectangle {
        anchors { left: parent.left; top: parent.top; bottom: parent.bottom }
        width: 3
        radius: 3
        color: {
            switch(root.category) {
                case "OSINT":   return "#5b8fff"
                case "Network": return "#ff9f40"
                case "Web":     return "#ff5f7e"
                default:        return "#888"
            }
        }
    }

    Column {
        anchors {
            left: parent.left; right: parent.right
            top: parent.top; bottom: parent.bottom
            leftMargin: 16; rightMargin: 12
            topMargin: 12; bottomMargin: 12
        }
        spacing: 4

        Row {
            width: parent.width
            spacing: 6

            // Status dot
            Rectangle {
                width: 7; height: 7
                radius: 4
                anchors.verticalCenter: parent.verticalCenter
                color: {
                    if (isRunning) return "#39ff7a"
                    if (isDone)    return "#2eff9f"
                    if (hasFailed) return "#ff4040"
                    return isInstalled ? "#4a9f7a" : "#666"
                }

                SequentialAnimation on opacity {
                    running: isRunning
                    loops: Animation.Infinite
                    NumberAnimation { to: 0.3; duration: 700 }
                    NumberAnimation { to: 1.0; duration: 700 }
                }
            }

            Text {
                text: root.displayName
                font.pixelSize: 13
                font.weight: 600
                font.family: "JetBrains Mono, Fira Mono, monospace"
                color: isEnabled ? "#e8eaf8" : "#555"
                Behavior on color { ColorAnimation { duration: 150 } }
            }

            Item { width: 1; height: 1 }

            // Category badge
            Rectangle {
                anchors.verticalCenter: parent.verticalCenter
                width: categoryLabel.implicitWidth + 10
                height: 16
                radius: 8
                color: {
                    switch(root.category) {
                        case "OSINT":   return "#1a2550"
                        case "Network": return "#2a1e08"
                        case "Web":     return "#2a0f18"
                        default:        return "#1a1a1a"
                    }
                }
                Text {
                    id: categoryLabel
                    anchors.centerIn: parent
                    text: root.category
                    font.pixelSize: 9
                    font.weight: 500
                    color: {
                        switch(root.category) {
                            case "OSINT":   return "#5b8fff"
                            case "Network": return "#ff9f40"
                            case "Web":     return "#ff5f7e"
                            default:        return "#888"
                        }
                    }
                }
            }
        }

        Text {
            text: root.description
            font.pixelSize: 10
            color: "#667"
            width: parent.width
            elide: Text.ElideRight
            maximumLineCount: 2
            wrapMode: Text.WordWrap
            lineHeight: 1.3
        }

        Row {
            spacing: 6
            // Install badge
            Rectangle {
                visible: !isInstalled
                width: notInstalledLabel.implicitWidth + 10; height: 14
                radius: 7
                color: "#2a1e08"
                Text {
                    id: notInstalledLabel
                    anchors.centerIn: parent
                    text: "not installed"
                    font.pixelSize: 9
                    color: "#ff9f40"
                }
            }
        }
    }

    // Toggle checkbox overlay
    Rectangle {
        anchors { right: parent.right; top: parent.top; margins: 10 }
        width: 20; height: 20
        radius: 5
        color: isEnabled ? "#2a3a7a" : "#1a1f30"
        border.color: isEnabled ? "#5b8fff" : "#2a3050"
        border.width: 1.5

        Behavior on color { ColorAnimation { duration: 150 } }

        Text {
            anchors.centerIn: parent
            text: "✓"
            font.pixelSize: 11
            font.weight: 700
            color: "#5b8fff"
            opacity: isEnabled ? 1 : 0
            Behavior on opacity { NumberAnimation { duration: 150 } }
        }
    }

    MouseArea {
        anchors.fill: parent
        onClicked: {
            root.isEnabled = !root.isEnabled
            root.toggled(root.isEnabled)
        }
        cursorShape: Qt.PointingHandCursor
    }

    // Hover effect
    MouseArea {
        anchors.fill: parent
        hoverEnabled: true
        onEntered: root.opacity = 0.9
        onExited: root.opacity = 1.0
        propagateComposedEvents: true
        onClicked: function(mouse) { mouse.accepted = false }
    }
}
