import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import QtQuick.Effects
import Quickshell
import Quickshell.Io
import "../Singletons"

/**
 * Detail popup for the Bluetooth quick tile: paired/known devices from
 * bluez, connect/disconnect, scan.
 */
Item {
    id: root

    property bool open: false
    property bool powerOn: true
    property string btName: ""

    signal requestedClose()
    signal powerToggled(bool on)

    width: 250
    height: 286

    /* ----------------------------- state ----------------------------- */
    property bool scanning: false
    property bool working: false
    property string status: ""

    onOpenChanged: {
        if (root.open) {
            root.status = ""
            root.reloadAll()
        }
    }

    ListModel { id: deviceModel }

    Process {
        id: pairProc
        command: ["sh", "-c", "bluetoothctl devices 2>/dev/null | sed -E 's/^Device ([0-9A-F:]+) (.*)/\\1|\\2/'"]
        stdout: StdioCollector { id: pairC; waitForEnd: true }
        onExited: root.applyPairs(String(pairC.text))
    }

    Process {
        id: connSetProc
        command: ["sh", "-c", "bluetoothctl devices Connected 2>/dev/null | sed -E 's/^Device ([0-9A-F:]+).*/\\1/'"]
        stdout: StdioCollector { id: connSetC; waitForEnd: true }
        onExited: root.applyConnected(String(connSetC.text))
    }

    Process {
        id: actProc
        command: ["sh", "-c", "true"]
        onExited: {
            root.working = false
            if (exitCode !== 0) root.status = "Action failed"
            delayRelist.restart()
        }
    }

    Process {
        id: scanProc
        command: ["sh", "-c", "bluetoothctl scan on >/dev/null 2>&1; sleep 8; bluetoothctl scan off >/dev/null 2>&1"]
        onExited: {
            root.scanning = false
            root.reloadAll()
        }
    }

    Timer { id: delayRelist; interval: 1200; onTriggered: root.reloadAll() }

    function shellQuote(s) {
        return "'" + String(s).replace(/'/g, "'\\''") + "'"
    }

    function reloadAll() {
        pairProc.running = true
        connSetProc.running = true
    }

    function scanDevices() {
        if (!root.powerOn || root.scanning || root.working) return
        root.scanning = true
        scanProc.running = true
    }

    function toggleDevice(mac, connected) {
        if (root.working) return
        root.working = true
        root.status = connected ? "Disconnecting…" : "Connecting…"
        actProc.command = ["sh", "-c",
            "bluetoothctl " + (connected ? "disconnect " : "connect ") +
            root.shellQuote(mac) + " >/dev/null 2>&1"]
        actProc.running = true
    }

    function applyPairs(text) {
        var seen = {}
        var lines = String(text).split("\n")
        for (var i = 0; i < lines.length; i++) {
            var l = lines[i].trim()
            if (!l) continue
            var bar = l.indexOf("|")
            if (bar < 0) continue
            var mac = l.substring(0, bar).trim()
            var name = l.substring(bar + 1).trim()
            if (!mac) continue
            seen[mac] = { mac: mac, name: name, connected: false }
        }
        deviceModel.clear()
        if (root.powerOn) {
            for (var m in seen) deviceModel.append(seen[m])
        }
    }

    function applyConnected(text) {
        var set = {}
        var lines = String(text).split("\n")
        for (var i = 0; i < lines.length; i++) {
            var m = lines[i].trim()
            if (m) set[m] = true
        }
        for (var j = 0; j < deviceModel.count; j++) {
            deviceModel.setProperty(j, "connected", !!set[deviceModel.get(j).mac])
        }
    }

    /* ----------------------------- visuals ----------------------------- */
    Rectangle {
        id: sheet
        width: parent.width
        height: parent.height
        radius: 18
        color: Theme.bg
        border.width: 1
        border.color: root.open ? Qt.rgba(Theme.accentLit.r, Theme.accentLit.g, Theme.accentLit.b, 0.45) : Theme.outline

        opacity: root.open ? 1 : 0
        scale: root.open ? 1.0 : 0.88
        y: root.open ? 0 : -20
        transformOrigin: Item.Top
        visible: opacity > 0.001

        Behavior on border.color { ColorAnimation { duration: 200 } }
        Behavior on opacity {
            NumberAnimation { duration: root.open ? 220 : 140; easing.type: Easing.OutCubic }
        }
        Behavior on y {
            NumberAnimation {
                duration: root.open ? 320 : 160
                easing.type: root.open ? Easing.OutBack : Easing.OutCubic
                easing.overshoot: 1.35
            }
        }
        Behavior on scale {
            NumberAnimation {
                duration: root.open ? 300 : 150
                easing.type: root.open ? Easing.OutBack : Easing.OutCubic
                easing.overshoot: 1.38
            }
        }

        /* swallow clicks on empty popup real estate */
        MouseArea { anchors.fill: parent }

        RowLayout {
            id: headRow
            anchors.top: parent.top
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.margins: 14
            height: 18
            spacing: 8

            Text {
                text: "\uf294"
                font.family: Theme.font
                font.pixelSize: 15
                color: Theme.accentLit
            }
            Text {
                text: "Bluetooth"
                font.family: "Valley Sans"
                font.pixelSize: 15
                font.weight: Font.Bold
                color: Theme.fg
            }
            Text {
                Layout.fillWidth: true
                text: root.btName.length > 0 ? root.btName
                     : (root.powerOn ? (deviceModel.count === 0 ? "No devices" : "On")
                                     : "Off")
                font.family: "Valley Sans"
                font.pixelSize: 12
                elide: Text.ElideRight
                horizontalAlignment: Text.AlignRight
                color: (root.btName.length > 0 || root.powerOn) ? Theme.accentLit : Theme.fgFaint
            }
            Rectangle {
                Layout.preferredWidth: 30
                Layout.preferredHeight: 18
                Layout.alignment: Qt.AlignVCenter
                radius: 9
                color: root.powerOn ? Theme.accent : Theme.bgAlt
                border.width: 1
                border.color: root.powerOn ? "transparent" : Theme.fgFaint
                MouseArea {
                    anchors.fill: parent
                    onClicked: root.powerToggled(!root.powerOn)
                }
                Rectangle {
                    width: 12
                    height: 12
                    radius: 6
                    color: root.powerOn ? "#0e0e12" : Theme.fgDim
                    anchors.verticalCenter: parent.verticalCenter
                    x: root.powerOn ? parent.width - width - 3 : 3
                    Behavior on x { NumberAnimation { duration: Motion.fast } }
                }
            }
            Text {
                text: "\uf00d"
                font.family: Theme.font
                font.pixelSize: 13
                color: Theme.fgDim
                MouseArea {
                    anchors.fill: parent
                    anchors.margins: -4
                    cursorShape: Qt.PointingHandCursor
                    onClicked: root.requestedClose()
                }
            }
        }

        Rectangle {
            anchors.top: headRow.bottom
            anchors.topMargin: 10
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.leftMargin: 14
            anchors.rightMargin: 14
            height: 1
            color: Theme.outline
        }

        ListView {
            id: devList
            anchors.top: parent.top
            anchors.topMargin: 44
            anchors.bottom: footRow.top
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.leftMargin: 6
            anchors.rightMargin: 6
            clip: true
            model: deviceModel
            spacing: 2

            ScrollBar.vertical: ScrollBar {
                policy: ScrollBar.AsNeeded
                width: 6
                parent: devList
                anchors.top: devList.top
                anchors.bottom: devList.bottom
                anchors.right: devList.right
            }

            delegate: Rectangle {
                id: row
                width: devList.width - 12
                height: 38
                radius: 10
                color: hov.hovered ? Theme.bgHover : "transparent"

                RowLayout {
                    anchors.fill: parent
                    anchors.leftMargin: 10
                    anchors.rightMargin: 10
                    spacing: 8

                    Text {
                        text: "\uf293"
                        font.family: Theme.font
                        font.pixelSize: 13
                        color: model.connected ? Theme.accentLit : Theme.fgFaint
                        Layout.preferredWidth: 14
                    }

                    ColumnLayout {
                        Layout.fillWidth: true
                        Layout.preferredWidth: 1
                        spacing: 0
                        Text {
                            Layout.fillWidth: true
                            elide: Text.ElideRight
                            text: model.name.length > 0 ? model.name : model.mac
                            font.family: "Valley Sans"
                            font.pixelSize: 14
                            color: model.connected ? Theme.accentLit : Theme.fg
                        }
                        Text {
                            Layout.fillWidth: true
                            text: model.mac
                            font.family: "Valley Sans"
                            font.pixelSize: 10
                            color: Theme.fgFaint
                        }
                    }

                    Text {
                        text: model.connected ? "\uf00c" : ""
                        font.family: Theme.font
                        font.pixelSize: 12
                        color: Theme.accentLit
                    }
                }

                MouseArea {
                    id: hov
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: root.toggleDevice(model.mac, model.connected)
                }
            }
        }

        Rectangle {
            id: footRow
            anchors.bottom: parent.bottom
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.bottomMargin: 14
            anchors.leftMargin: 14
            anchors.rightMargin: 14
            height: 40
            radius: 12
            color: Theme.bgAlt

            RowLayout {
                anchors.fill: parent
                anchors.leftMargin: 12
                anchors.rightMargin: 12
                spacing: 10

                Text {
                    text: root.working ? "" : (root.scanning ? "\uf6be" : "\uf002")
                    font.family: Theme.font
                    font.pixelSize: 14
                    color: Theme.fgDim
                }

                Text {
                    Layout.fillWidth: true
                    Layout.preferredWidth: 1
                    elide: Text.ElideRight
                    text: root.status.length > 0 ? root.status
                        : root.scanning ? "Scanning for devices…"
                        : !root.powerOn ? "Bluetooth is off"
                        : deviceModel.count === 0 ? "No known devices"
                        : "Tap a device to connect"
                    font.family: "Valley Sans"
                    font.pixelSize: 12
                    color: root.status.length > 0 ? Theme.accentLit : Theme.fgFaint
                }

                Text {
                    text: "SCAN"
                    font.family: Theme.font
                    font.pixelSize: 11
                    font.bold: true
                    color: (!root.powerOn || root.scanning || root.working) ? Theme.fgFaint : Theme.accentLit
                    MouseArea {
                        anchors.fill: parent
                        anchors.margins: -6
                        cursorShape: Qt.PointingHandCursor
                        onClicked: root.scanDevices()
                    }
                }
            }
        }
    }
}