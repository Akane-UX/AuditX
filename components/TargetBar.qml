import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

Rectangle {
    id: root

    property string targetIp: ""
    property string targetDomain: ""
    property string targetUrl: ""
    property string targetCloud: ""
    property string targetPath: ""
    property string targetUsername: ""
    property string targetInterface: ""

    property string activeType: "ip" // "ip" | "domain" | "url" | "cloud" | "path" | "username" | "interface"
    property bool isMultiView: false
    property bool isRunning: false

    signal runSelectedRequested()
    signal fullAuditRequested()
    signal networkReconRequested()
    signal checkStatusRequested()

    width: parent.width
    implicitHeight: isMultiView ? multiLayout.implicitHeight + 20 : 80
    color: "#080808"
    border.color: "#1a1a1a"
    border.width: 1
    radius: 8

    Behavior on implicitHeight { NumberAnimation { duration: 180; easing.type: Easing.OutCubic } }

    readonly property var typesMeta: [
        { id: "ip",        label: "IP",        fullLabel: "IP / Host",         hint: "e.g. 192.168.1.1 or 10.10.10.0/24" },
        { id: "domain",    label: "Domain",    fullLabel: "Domain / Host",     hint: "e.g. example.com or corp.local" },
        { id: "url",       label: "URL",       fullLabel: "Web URL",           hint: "e.g. https://example.com or http://10.10.10.5:8080" },
        { id: "cloud",     label: "Cloud",     fullLabel: "Cloud Provider",    hint: "e.g. aws, azure, gcp, oci" },
        { id: "path",      label: "Path",      fullLabel: "Path / Capture",    hint: "e.g. . or /path/to/handshake.cap" },
        { id: "username",  label: "User",      fullLabel: "Username",          hint: "e.g. admin or target_handle" },
        { id: "interface", label: "Interface", fullLabel: "Wireless Interface", hint: "e.g. wlp0s20f3 or wlan0" }
    ]

    function getValue(t) {
        if (t === "ip") return targetIp
        if (t === "domain") return targetDomain
        if (t === "url") return targetUrl
        if (t === "cloud") return targetCloud
        if (t === "path") return targetPath
        if (t === "username") return targetUsername
        if (t === "interface") return targetInterface
        return ""
    }

    function setValue(t, val) {
        if (t === "ip") targetIp = val
        else if (t === "domain") targetDomain = val
        else if (t === "url") targetUrl = val
        else if (t === "cloud") targetCloud = val
        else if (t === "path") targetPath = val
        else if (t === "username") targetUsername = val
        else if (t === "interface") targetInterface = val
    }

    function getMeta(t) {
        for (var i = 0; i < typesMeta.length; i++) {
            if (typesMeta[i].id === t) return typesMeta[i]
        }
        return typesMeta[0]
    }

    // ── Content ──────────────────────────────────────────────────────────────
    Column {
        anchors { fill: parent; margins: 10 }
        spacing: 8

        // ── TOP: Type Selector Pills + Multi-view Toggle ─────────────────────
        Item {
            width: parent.width
            height: 24

            // Left: Type selector pills
            Row {
                anchors.left: parent.left
                anchors.verticalCenter: parent.verticalCenter
                spacing: 6

                Repeater {
                    model: root.typesMeta

                    Rectangle {
                        id: pill
                        property var m: modelData
                        property bool isActive: root.activeType === m.id
                        property bool hasValue: root.getValue(m.id).trim().length > 0

                        width: pillRow.implicitWidth + 14
                        height: 24
                        radius: 4
                        color: {
                            if (isActive) return "#0d223a"
                            if (pillHover.containsMouse) return "#141414"
                            return "#0c0c0c"
                        }
                        border.color: isActive ? "#0066ff" : (hasValue ? "#224466" : "#222222")
                        border.width: 1

                        Behavior on color { ColorAnimation { duration: 120 } }
                        Behavior on border.color { ColorAnimation { duration: 120 } }

                        Row {
                            id: pillRow
                            anchors.centerIn: parent
                            spacing: 5

                            Text {
                                text: pill.m.label
                                font.pixelSize: 10
                                font.weight: pill.isActive ? 700 : 500
                                font.family: "JetBrains Mono, Fira Mono, monospace"
                                color: pill.isActive ? "#ffffff" : (pill.hasValue ? "#88ccff" : "#777777")
                                anchors.verticalCenter: parent.verticalCenter
                            }

                            // Has value indicator dot
                            Rectangle {
                                visible: pill.hasValue
                                width: 5; height: 5; radius: 2.5
                                color: pill.isActive ? "#00ffff" : "#00aa66"
                                anchors.verticalCenter: parent.verticalCenter
                            }
                        }

                        MouseArea {
                            id: pillHover
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: root.activeType = pill.m.id
                        }
                    }
                }
            }

            // Right: Multi-Field Toggle Button
            Rectangle {
                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
                width: multiToggleRow.implicitWidth + 16
                height: 24
                radius: 4
                color: root.isMultiView ? "#0d223a" : (multiHover.containsMouse ? "#141414" : "#0c0c0c")
                border.color: root.isMultiView ? "#0066ff" : "#2a2a2a"
                border.width: 1

                Behavior on color { ColorAnimation { duration: 120 } }

                Row {
                    id: multiToggleRow
                    anchors.centerIn: parent
                    spacing: 5
                    Text {
                        text: root.isMultiView ? "⊟" : "⊞"
                        font.pixelSize: 12; font.weight: 700; color: root.isMultiView ? "#00ffff" : "#888888"
                    }
                    Text {
                        text: root.isMultiView ? "Compact" : "Multi-Target"
                        font.pixelSize: 10; font.weight: 600
                        font.family: "JetBrains Mono, Fira Mono, monospace"
                        color: root.isMultiView ? "#ffffff" : "#888888"
                    }
                }

                MouseArea {
                    id: multiHover
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: root.isMultiView = !root.isMultiView
                }
            }
        }

        // ── MODE A: Compact Single Input View ────────────────────────────────
        Row {
            visible: !root.isMultiView
            width: parent.width
            height: 40
            spacing: 8

            // Main Input Container
            Rectangle {
                height: 40
                width: parent.width - actionButtonsCompact.width - 8
                radius: 6
                color: "#050505"
                border.color: singleInput.activeFocus ? "#0066ff" : "#222222"
                border.width: 1
                Behavior on border.color { ColorAnimation { duration: 120 } }

                Row {
                    anchors {
                        left: parent.left; right: parent.right
                        verticalCenter: parent.verticalCenter
                        leftMargin: 10; rightMargin: 10
                    }
                    spacing: 8

                    // Active Type Tag (Clean text badge, no emoji)
                    Rectangle {
                        height: 22
                        width: tagRow.implicitWidth + 10
                        radius: 3
                        color: "#0c1d33"
                        border.color: "#1e3a5f"
                        border.width: 1
                        anchors.verticalCenter: parent.verticalCenter

                        Row {
                            id: tagRow
                            anchors.centerIn: parent
                            spacing: 4
                            Text {
                                text: root.getMeta(root.activeType).label.toUpperCase()
                                font.pixelSize: 9
                                font.weight: 700
                                font.family: "JetBrains Mono, Fira Mono, monospace"
                                color: "#64b5f6"
                                anchors.verticalCenter: parent.verticalCenter
                            }
                        }
                    }

                    // Input Field
                    TextInput {
                        id: singleInput
                        width: parent.width - 90
                        font.pixelSize: 12
                        font.family: "JetBrains Mono, Fira Mono, monospace"
                        color: "#ffffff"
                        selectionColor: "#0066ff"
                        text: root.getValue(root.activeType)
                        onTextChanged: root.setValue(root.activeType, text)

                        Keys.onReturnPressed: {
                            if (event.modifiers & Qt.ControlModifier) {
                                root.runSelectedRequested()
                            }
                        }

                        Text {
                            visible: singleInput.text.length === 0
                            text: root.getMeta(root.activeType).hint
                            font: singleInput.font
                            color: "#444444"
                            anchors.verticalCenter: parent.verticalCenter
                        }
                    }

                    // Clear button
                    Text {
                        visible: singleInput.text.length > 0
                        text: "✕"
                        font.pixelSize: 10
                        color: clearHover.containsMouse ? "#ffffff" : "#666666"
                        anchors.verticalCenter: parent.verticalCenter

                        MouseArea {
                            id: clearHover
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: {
                                singleInput.text = ""
                                root.setValue(root.activeType, "")
                            }
                        }
                    }
                }
            }

            // Action Buttons
            Row {
                id: actionButtonsCompact
                spacing: 8
                height: 40

                // Run Selected Button
                Rectangle {
                    height: 40; width: 125; radius: 6
                    color: runHover.containsMouse && !root.isRunning ? "#0066ff" : "#0047b3"
                    opacity: root.isRunning ? 0.5 : 1
                    Behavior on color { ColorAnimation { duration: 120 } }

                    Column {
                        anchors.centerIn: parent; spacing: 1
                        Text {
                            anchors.horizontalCenter: parent.horizontalCenter
                            text: "Run Selected"
                            font.pixelSize: 11; font.weight: 600
                            font.family: "JetBrains Mono, Fira Mono, monospace"
                            color: "#ffffff"
                        }
                        Text {
                            anchors.horizontalCenter: parent.horizontalCenter
                            text: "Ctrl+Enter"
                            font.pixelSize: 8; font.family: "JetBrains Mono, Fira Mono, monospace"
                            color: "#bbccff"
                        }
                    }

                    MouseArea {
                        id: runHover
                        anchors.fill: parent; hoverEnabled: true
                        cursorShape: root.isRunning ? Qt.ArrowCursor : Qt.PointingHandCursor
                        onClicked: { if (!root.isRunning) root.runSelectedRequested() }
                    }
                }

                // Full Audit Button
                Rectangle {
                    height: 40; width: 105; radius: 6
                    color: fullHover.containsMouse && !root.isRunning ? "#141414" : "#0c0c0c"
                    border.color: root.isRunning ? "#111" : "#222222"; border.width: 1
                    opacity: root.isRunning ? 0.5 : 1
                    Behavior on color { ColorAnimation { duration: 120 } }

                    Column {
                        anchors.centerIn: parent; spacing: 1
                        Text {
                            anchors.horizontalCenter: parent.horizontalCenter
                            text: "Full Audit"
                            font.pixelSize: 11; font.weight: 600
                            font.family: "JetBrains Mono, Fira Mono, monospace"
                            color: "#0066ff"
                        }
                        Text {
                            anchors.horizontalCenter: parent.horizontalCenter
                            text: "All tools"
                            font.pixelSize: 8; font.family: "JetBrains Mono, Fira Mono, monospace"
                            color: "#666666"
                        }
                    }

                    MouseArea {
                        id: fullHover
                        anchors.fill: parent; hoverEnabled: true
                        cursorShape: root.isRunning ? Qt.ArrowCursor : Qt.PointingHandCursor
                        onClicked: { if (!root.isRunning) root.fullAuditRequested() }
                    }
                }

                // Network Recon Button
                Rectangle {
                    height: 40; width: 125; radius: 6
                    color: reconHover.containsMouse && !root.isRunning ? "#0a192f" : "#0c0c0c"
                    border.color: root.isRunning ? "#111" : (reconHover.containsMouse ? "#0066ff" : "#1a365d"); border.width: 1
                    opacity: root.isRunning ? 0.5 : 1
                    Behavior on color { ColorAnimation { duration: 120 } }
                    Behavior on border.color { ColorAnimation { duration: 120 } }

                    Column {
                        anchors.centerIn: parent; spacing: 1
                        Text {
                            anchors.horizontalCenter: parent.horizontalCenter
                            text: "Network Recon"
                            font.pixelSize: 11; font.weight: 600
                            font.family: "JetBrains Mono, Fira Mono, monospace"
                            color: "#00d4ff"
                        }
                        Text {
                            anchors.horizontalCenter: parent.horizontalCenter
                            text: "Subnet sweep"
                            font.pixelSize: 8; font.family: "JetBrains Mono, Fira Mono, monospace"
                            color: "#5588aa"
                        }
                    }

                    MouseArea {
                        id: reconHover
                        anchors.fill: parent; hoverEnabled: true
                        cursorShape: root.isRunning ? Qt.ArrowCursor : Qt.PointingHandCursor
                        onClicked: { if (!root.isRunning) root.networkReconRequested() }
                    }
                }

                // Status Button
                Rectangle {
                    height: 40; width: 80; radius: 6
                    color: statusHover.containsMouse ? "#141414" : "#0c0c0c"
                    border.color: "#222222"; border.width: 1
                    Behavior on color { ColorAnimation { duration: 120 } }

                    Column {
                        anchors.centerIn: parent; spacing: 1
                        Text {
                            anchors.horizontalCenter: parent.horizontalCenter
                            text: "Status"
                            font.pixelSize: 11; font.weight: 600
                            font.family: "JetBrains Mono, Fira Mono, monospace"
                            color: "#888888"
                        }
                        Text {
                            anchors.horizontalCenter: parent.horizontalCenter
                            text: "health"
                            font.pixelSize: 8; font.family: "JetBrains Mono, Fira Mono, monospace"
                            color: "#555555"
                        }
                    }

                    MouseArea {
                        id: statusHover
                        anchors.fill: parent; hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: root.checkStatusRequested()
                    }
                }
            }
        }

        // ── MODE B: Multi-Target Grid View ───────────────────────────────────
        Column {
            id: multiLayout
            visible: root.isMultiView
            width: parent.width
            spacing: 8

            // 4-Column Grid for the 7 target types
            Grid {
                width: parent.width
                columns: 4
                spacing: 8

                Repeater {
                    model: root.typesMeta

                    Rectangle {
                        property var m: modelData
                        width: Math.floor((multiLayout.width - 24) / 4)
                        height: 42
                        radius: 5
                        color: "#050505"
                        border.color: multiFieldInput.activeFocus ? "#0066ff" : (root.getValue(m.id).trim().length > 0 ? "#1e3a5f" : "#1a1a1a")
                        border.width: 1

                        Column {
                            anchors {
                                fill: parent
                                leftMargin: 8; rightMargin: 8
                                topMargin: 4; bottomMargin: 4
                            }
                            spacing: 1

                            // Mini Label (Clean text, no emoji)
                            Row {
                                spacing: 4
                                Text {
                                    text: m.fullLabel.toUpperCase()
                                    font.pixelSize: 8; font.weight: 700
                                    font.family: "JetBrains Mono, Fira Mono, monospace"
                                    color: root.getValue(m.id).trim().length > 0 ? "#00b4d8" : "#666666"
                                    anchors.verticalCenter: parent.verticalCenter
                                }
                            }

                            // Input Box
                            TextInput {
                                id: multiFieldInput
                                width: parent.width
                                font.pixelSize: 11
                                font.family: "JetBrains Mono, Fira Mono, monospace"
                                color: "#ffffff"
                                selectionColor: "#0066ff"
                                text: root.getValue(m.id)
                                onTextChanged: root.setValue(m.id, text)

                                Keys.onReturnPressed: {
                                    if (event.modifiers & Qt.ControlModifier) {
                                        root.runSelectedRequested()
                                    }
                                }

                                Text {
                                    visible: multiFieldInput.text.length === 0
                                    text: m.hint
                                    font: multiFieldInput.font
                                    color: "#333333"
                                    elide: Text.ElideRight
                                    width: parent.width
                                    anchors.verticalCenter: parent.verticalCenter
                                }
                            }
                        }
                    }
                }
            }

            // Actions row in Multi-View
            Item {
                width: parent.width
                height: 36

                Text {
                    anchors.left: parent.left
                    anchors.verticalCenter: parent.verticalCenter
                    text: "✓ Target types are automatically assigned to matching security tools."
                    font.pixelSize: 10
                    font.family: "JetBrains Mono, Fira Mono, monospace"
                    color: "#00aa66"
                }

                Row {
                    anchors.right: parent.right
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: 8

                    // Run Selected Button
                    Rectangle {
                        height: 34; width: 120; radius: 5
                        color: runMultiHover.containsMouse && !root.isRunning ? "#0066ff" : "#0047b3"
                        opacity: root.isRunning ? 0.5 : 1
                        Behavior on color { ColorAnimation { duration: 120 } }
                        Text {
                            anchors.centerIn: parent
                            text: "Run Selected"
                            font.pixelSize: 11; font.weight: 600
                            font.family: "JetBrains Mono, Fira Mono, monospace"
                            color: "#ffffff"
                        }
                        MouseArea {
                            id: runMultiHover
                            anchors.fill: parent; hoverEnabled: true
                            cursorShape: root.isRunning ? Qt.ArrowCursor : Qt.PointingHandCursor
                            onClicked: { if (!root.isRunning) root.runSelectedRequested() }
                        }
                    }

                    // Full Audit Button
                    Rectangle {
                        height: 34; width: 100; radius: 5
                        color: fullMultiHover.containsMouse && !root.isRunning ? "#141414" : "#0c0c0c"
                        border.color: root.isRunning ? "#111" : "#222222"; border.width: 1
                        opacity: root.isRunning ? 0.5 : 1
                        Behavior on color { ColorAnimation { duration: 120 } }
                        Text {
                            anchors.centerIn: parent
                            text: "Full Audit"
                            font.pixelSize: 11; font.weight: 600
                            font.family: "JetBrains Mono, Fira Mono, monospace"
                            color: "#0066ff"
                        }
                        MouseArea {
                            id: fullMultiHover
                            anchors.fill: parent; hoverEnabled: true
                            cursorShape: root.isRunning ? Qt.ArrowCursor : Qt.PointingHandCursor
                            onClicked: { if (!root.isRunning) root.fullAuditRequested() }
                        }
                    }

                    // Network Recon Button
                    Rectangle {
                        height: 34; width: 115; radius: 5
                        color: reconMultiHover.containsMouse && !root.isRunning ? "#0a192f" : "#0c0c0c"
                        border.color: root.isRunning ? "#111" : (reconMultiHover.containsMouse ? "#0066ff" : "#1a365d"); border.width: 1
                        opacity: root.isRunning ? 0.5 : 1
                        Behavior on color { ColorAnimation { duration: 120 } }
                        Behavior on border.color { ColorAnimation { duration: 120 } }
                        Text {
                            anchors.centerIn: parent
                            text: "Network Recon"
                            font.pixelSize: 11; font.weight: 600
                            font.family: "JetBrains Mono, Fira Mono, monospace"
                            color: "#00d4ff"
                        }
                        MouseArea {
                            id: reconMultiHover
                            anchors.fill: parent; hoverEnabled: true
                            cursorShape: root.isRunning ? Qt.ArrowCursor : Qt.PointingHandCursor
                            onClicked: { if (!root.isRunning) root.networkReconRequested() }
                        }
                    }

                    // Status Button
                    Rectangle {
                        height: 34; width: 80; radius: 5
                        color: statusMultiHover.containsMouse ? "#141414" : "#0c0c0c"
                        border.color: "#222222"; border.width: 1
                        Behavior on color { ColorAnimation { duration: 120 } }
                        Text {
                            anchors.centerIn: parent
                            text: "Status"
                            font.pixelSize: 11; font.weight: 600
                            font.family: "JetBrains Mono, Fira Mono, monospace"
                            color: "#888888"
                        }
                        MouseArea {
                            id: statusMultiHover
                            anchors.fill: parent; hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: root.checkStatusRequested()
                        }
                    }
                }
            }
        }
    }
}
