import QtQuick
import QtQuick.Controls

// ConsoleView.qml — Multi-Tab Real-time streaming output terminal
Rectangle {
    id: root

    property string currentTool: ""
    property string activeTabId: "all"
    property var toolLinesMap: ({})     // toolId -> array of log entry objects

    color: "#050505"
    radius: 6
    clip: true
    border.color: "#111111"
    border.width: 1

    // ── Tab Management ─────────────────────────────────────────────────────────
    ListModel {
        id: tabsModel
        Component.onCompleted: {
            append({ tabId: "all", label: "ALL", status: "idle", count: 0 })
        }
    }

    ListModel {
        id: allLogsModel
    }

    ListModel {
        id: activeLogsModel
    }

    // ── Header Bar with Tabs ───────────────────────────────────────────────────
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

        // Title & Active Pulse
        Row {
            id: titleRow
            anchors { left: parent.left; leftMargin: 12; verticalCenter: parent.verticalCenter }
            spacing: 8

            Rectangle {
                width: 7; height: 7; radius: 3.5
                color: currentTool !== "" ? "#0066ff" : "#444444"
                anchors.verticalCenter: parent.verticalCenter
                SequentialAnimation on opacity {
                    running: currentTool !== ""
                    loops: Animation.Infinite
                    NumberAnimation { to: 0.2; duration: 500 }
                    NumberAnimation { to: 1.0; duration: 500 }
                }
            }
            Text {
                anchors.verticalCenter: parent.verticalCenter
                text: "CONSOLE"
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
        }

        // Actions (Tab info + Clear)
        Row {
            id: actionsRow
            anchors { right: parent.right; rightMargin: 10; verticalCenter: parent.verticalCenter }
            spacing: 8

            Text {
                anchors.verticalCenter: parent.verticalCenter
                text: (activeTabId === "all" ? allLogsModel.count : activeLogsModel.count) + " lines"
                font.pixelSize: 9
                font.family: "JetBrains Mono, Fira Mono, monospace"
                color: "#555555"
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
                    onClicked: root.clearCurrentTab()
                }
            }
        }

        // Tabs ScrollView
        ScrollView {
            id: tabScroll
            anchors {
                left: titleRow.right; leftMargin: 10
                right: actionsRow.left; rightMargin: 10
                verticalCenter: parent.verticalCenter
            }
            height: 32
            clip: true
            ScrollBar.vertical.policy: ScrollBar.AlwaysOff
            ScrollBar.horizontal.policy: ScrollBar.AlwaysOff

            Row {
                spacing: 6
                height: 30

                Repeater {
                    model: tabsModel
                    Rectangle {
                        height: 26
                        width: tabRow.implicitWidth + 16
                        radius: 4
                        color: activeTabId === model.tabId ? "#141414" : (tabHover.containsMouse ? "#0f0f0f" : "transparent")
                        border.color: activeTabId === model.tabId ? "#0066ff" : (tabHover.containsMouse ? "#222222" : "transparent")
                        border.width: 1
                        Behavior on color { ColorAnimation { duration: 120 } }
                        Behavior on border.color { ColorAnimation { duration: 120 } }

                        Row {
                            id: tabRow
                            anchors.centerIn: parent
                            spacing: 5

                            Rectangle {
                                visible: model.tabId !== "all"
                                width: 6; height: 6; radius: 3
                                anchors.verticalCenter: parent.verticalCenter
                                color: {
                                    if (model.status === "running") return "#0066ff"
                                    if (model.status === "done")    return "#00cc44"
                                    if (model.status === "failed")  return "#ff3333"
                                    return "#555555"
                                }
                                SequentialAnimation on opacity {
                                    running: model.status === "running"
                                    loops: Animation.Infinite
                                    NumberAnimation { to: 0.2; duration: 500 }
                                    NumberAnimation { to: 1.0; duration: 500 }
                                }
                            }

                            Text {
                                text: model.label
                                font.pixelSize: 10
                                font.family: "JetBrains Mono, Fira Mono, monospace"
                                font.weight: activeTabId === model.tabId ? 600 : 400
                                color: activeTabId === model.tabId ? "#ffffff" : "#888888"
                                anchors.verticalCenter: parent.verticalCenter
                            }

                            Rectangle {
                                visible: model.count > 0
                                width: countText.implicitWidth + 6; height: 14; radius: 7
                                color: activeTabId === model.tabId ? "#003366" : "#1a1a1a"
                                anchors.verticalCenter: parent.verticalCenter
                                Text {
                                    id: countText
                                    anchors.centerIn: parent
                                    text: model.count > 999 ? "999+" : model.count
                                    font.pixelSize: 8
                                    font.family: "JetBrains Mono, Fira Mono, monospace"
                                    color: activeTabId === model.tabId ? "#66a3ff" : "#666666"
                                }
                            }
                        }

                        MouseArea {
                            id: tabHover
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: root.switchTab(model.tabId)
                        }
                    }
                }
            }
        }
    }

    // ── Log List ───────────────────────────────────────────────────────────────
    ListView {
        id: logList
        anchors {
            top: header.bottom; bottom: parent.bottom
            left: parent.left; right: parent.right
            margins: 4; topMargin: 6; bottomMargin: 6
        }

        model: activeTabId === "all" ? allLogsModel : activeLogsModel
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

    // ── Tab Management Functions ───────────────────────────────────────────────
    function addTab(toolId, label) {
        if (!toolId) return
        var tId = toolId.toLowerCase()
        for (var i = 0; i < tabsModel.count; i++) {
            if (tabsModel.get(i).tabId === tId) return
        }
        tabsModel.append({
            tabId: tId,
            label: (label || toolId).toUpperCase(),
            status: "running",
            count: 0
        })
    }

    function setTabStatus(toolId, status) {
        if (!toolId) return
        var tId = toolId.toLowerCase()
        for (var i = 0; i < tabsModel.count; i++) {
            if (tabsModel.get(i).tabId === tId) {
                tabsModel.setProperty(i, "status", status)
                return
            }
        }
    }

    function incrementTabCount(toolId) {
        var tId = (toolId || "").toLowerCase()
        for (var i = 0; i < tabsModel.count; i++) {
            if (tabsModel.get(i).tabId === "all" || tabsModel.get(i).tabId === tId) {
                tabsModel.setProperty(i, "count", tabsModel.get(i).count + 1)
            }
        }
    }

    function switchTab(tabId) {
        activeTabId = tabId
        if (tabId === "all") {
            // Already bound to allLogsModel
            return
        }
        activeLogsModel.clear()
        var entries = toolLinesMap[tabId] || []
        for (var i = 0; i < entries.length; i++) {
            activeLogsModel.append(entries[i])
        }
    }

    function resetTabs() {
        tabsModel.clear()
        tabsModel.append({ tabId: "all", label: "ALL", status: "idle", count: 0 })
        activeTabId = "all"
        toolLinesMap = {}
        allLogsModel.clear()
        activeLogsModel.clear()
    }

    function clearCurrentTab() {
        if (activeTabId === "all") {
            allLogsModel.clear()
            activeLogsModel.clear()
            toolLinesMap = {}
            for (var i = 0; i < tabsModel.count; i++) {
                tabsModel.setProperty(i, "count", 0)
            }
        } else {
            activeLogsModel.clear()
            toolLinesMap[activeTabId] = []
            for (var j = 0; j < tabsModel.count; j++) {
                if (tabsModel.get(j).tabId === activeTabId) {
                    tabsModel.setProperty(j, "count", 0)
                }
            }
        }
    }

    function clear() {
        allLogsModel.clear()
        activeLogsModel.clear()
    }

    // ── Append Line ────────────────────────────────────────────────────────────
    function appendLine(prefix, prefixColor, text, textColor, toolId) {
        var d = new Date()
        var ts = d.getHours().toString().padStart(2, '0') + ':'
                + d.getMinutes().toString().padStart(2, '0') + ':'
                + d.getSeconds().toString().padStart(2, '0')

        var entry = {
            timestamp: ts,
            prefix: prefix,
            prefixColor: prefixColor || "#0066ff",
            text: text,
            textColor: textColor || "#aaaaaa",
            tool: toolId || ""
        }

        allLogsModel.append(entry)
        incrementTabCount(toolId)

        if (toolId) {
            var tId = toolId.toLowerCase()
            var currentMap = Object.assign({}, toolLinesMap)
            if (!currentMap[tId]) currentMap[tId] = []
            currentMap[tId].push(entry)
            toolLinesMap = currentMap

            if (activeTabId === tId) {
                activeLogsModel.append(entry)
            }
        }
    }

    function info(text)    { appendLine("[INFO]",    "#0066ff", text, "#aaaaaa", "") }
    function success(text) { appendLine("[OK]",      "#0066ff", text, "#cccccc", "") }
    function warn(text)    { appendLine("[WARN]",    "#666666", text, "#bbbbbb", "") }
    function error(text)   { appendLine("[ERROR]",   "#ff3333", text, "#dddddd", "") }
    function output(tool, text) {
        appendLine("[" + tool.toUpperCase() + "]", "#0047b3", text, "#888888", tool)
    }
    function system(text)  { appendLine("[SYS]",    "#444444", text, "#666666", "") }
}
