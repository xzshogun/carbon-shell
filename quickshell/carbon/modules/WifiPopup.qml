import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import QtQuick.Effects
import Quickshell
import Quickshell.Io
import "../Singletons"

/**
 * Detail popup for the Wi-Fi quick tile. A compact rounded sheet listing every
 * network in range (from NetworkManager), with scan + connect actions and a
 * password prompt for secured networks. Stays inside the quick-settings panel
 * and is scrollable when the list is long.
 */
Item {
    id: root

    property bool open: false
    property bool powerOn: true
    property string wifiName: ""

    signal requestedClose()
    signal powerToggled(bool on)

    width: 250
    height: 286

    function shellQuote(s) {
        return "'" + String(s).replace(/'/g, "'\\''") + "'"
    }

    /* ----------------------------- state ----------------------------- */
    property bool scanning: false
    property bool connecting: false
    property bool pwVisible: false
    property string pwSsid: ""
    property string pwBssid: ""
    property string status: ""

    onOpenChanged: {
        if (root.open) {
            root.status = ""
            root.pwVisible = false
            root.connecting = false
            if (root.powerOn) root.listNetworks()
        }
    }

    /* --------------------------- list backend --------------------------- */
    ListModel { id: networkModel }

    Process {
        id: listProc
        command: ["sh", "-c", "nmcli -t -f IN-USE,SSID,SIGNAL,SECURITY,BSSID dev wifi list 2>/dev/null"]
        stdout: StdioCollector { id: listC; waitForEnd: true }
        onExited: root.applyList(String(listC.text))
    }

    Process {
        id: rescanProc
        command: ["sh", "-c", "nmcli dev wifi rescan >/dev/null 2>&1"]
        onExited: {
            root.scanning = true
            relistTimer.restart()
        }
    }

    Timer {
        id: relistTimer
        interval: 3200
        onTriggered: root.listNetworks()
    }

    Process {
        id: connectProc
        command: ["sh", "-c", "true"]
        stdout: StdioCollector { id: connC; waitForEnd: true }
        stderr: StdioCollector { id: connE; waitForEnd: true }
        onExited: {
            root.connecting = false
            if (exitCode === 0) {
                root.pwVisible = false
                root.status = "Connected to " + root.pwSsid
                delayRelist.restart()
            } else {
                var err = String(connE.text).trim()
                root.status = root.pwVisible && root.pwField.text.length === 0
                    ? "Enter a network key" : err
                listTimer.restart()
            }
        }
    }

    Timer { id: listTimer; interval: 1200; onTriggered: root.listNetworks() }
    Timer { id: delayRelist; interval: 2500; onTriggered: root.listNetworks() }

    function listNetworks() {
        root.scanning = false
        listProc.running = true
    }

    function scanNetworks() {
        if (!root.powerOn || root.scanning) return
        rescanProc.running = true
    }

    function requestConnect(bssid, secured, ssid) {
        if (root.connecting) return
        root.pwSsid = ssid
        root.pwBssid = bssid
        root.status = "Connecting to " + ssid + "…"
        if (secured) {
            root.pwVisible = true
            root.pwField.text = ""
            pwField.forceActiveFocus()
            return
        }
        root.doConnect(bssid, "")
    }

    function doConnect(bssid, pw) {
        root.status = "Connecting to " + root.pwSsid + "…"
        root.connecting = true
        connectProc.command = ["sh", "-c",
            "nmcli dev wifi connect " + root.shellQuote(bssid) +
            (pw.length > 0 ? " password " + root.shellQuote(pw) : "")]
        connectProc.running = true
    }

    function applyList(text) {
        networkModel.clear()
        var seen = {}
        var lines = String(text).split("\n")
        for (var i = 0; i < lines.length; i++) {
            var l = lines[i]
            if (!l) continue
            l = l.replace(/\\:/g, "\u0000")
            var p = l.split(":")
            if (p.length < 5) continue
            var ssid = p[1].replace(/\u0000/g, ":").trim()
            if (!ssid) continue
            var sig = parseInt(p[2], 10) || 0
            var sec = p[3].replace(/\u0000/g, ":")
            var inUse = p[0] === "*" || p[0] === "yes"
            var cur = seen[ssid]
            if (!cur || inUse || sig > cur.sig)
                seen[ssid] = { ssid: ssid, sig: sig, sec: sec,
                               bssid: p[4].replace(/\u0000/g, ":"), inUse: inUse }
        }
        var rows = []
        for (var k in seen) rows.push(seen[k])
        rows.sort(function(a, b) {
            if (a.inUse !== b.inUse) return a.inUse ? -1 : 1
            return b.sig - a.sig
        })
        for (var j = 0; j < rows.length; j++) networkModel.append(rows[j])
        root.scanning = false
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

        /* Header */
        RowLayout {
            id: headRow
            anchors.top: parent.top
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.margins: 14
            height: 18
            spacing: 8

            Text {
                text: "\uf1eb"
                font.family: Theme.font
                font.pixelSize: 15
                color: Theme.accentLit
            }
            Text {
                text: "Wi-Fi"
                font.family: "Valley Sans"
                font.pixelSize: 15
                font.weight: Font.Bold
                color: Theme.fg
            }
            Text {
                Layout.fillWidth: true
                text: root.wifiName.length > 0 ? root.wifiName : (root.powerOn ? "Not connected" : "Off")
                font.family: "Valley Sans"
                font.pixelSize: 12
                elide: Text.ElideRight
                horizontalAlignment: Text.AlignRight
                color: root.wifiName.length > 0 ? Theme.accentLit : Theme.fgFaint
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

        /* Network list (scrollable) */
        ListView {
            id: netList
            anchors.top: parent.top
            anchors.topMargin: 44
            anchors.bottom: footRow.top
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.leftMargin: 6
            anchors.rightMargin: 6
            clip: true
            model: networkModel
            spacing: 2

            ScrollBar.vertical: ScrollBar {
                policy: ScrollBar.AsNeeded
                width: 6
                parent: netList
                anchors.top: netList.top
                anchors.bottom: netList.bottom
                anchors.right: netList.right
            }

            delegate: Rectangle {
                id: row
                width: netList.width - 12
                height: 38
                radius: 10
                color: hov.hovered ? Theme.bgHover : "transparent"

                RowLayout {
                    anchors.fill: parent
                    anchors.leftMargin: 10
                    anchors.rightMargin: 10
                    spacing: 8

                    Text {
                        text: model.inUse ? "\uf00c" : (model.sec ? "\uf023" : "")
                        font.family: Theme.font
                        font.pixelSize: 12
                        color: model.inUse ? Theme.accentLit : Theme.fgFaint
                        Layout.preferredWidth: 12
                    }

                    ColumnLayout {
                        Layout.fillWidth: true
                        Layout.preferredWidth: 1
                        spacing: 0
                        Text {
                            Layout.fillWidth: true
                            elide: Text.ElideRight
                            text: model.ssid
                            font.family: "Valley Sans"
                            font.pixelSize: 14
                            color: model.inUse ? Theme.accentLit : Theme.fg
                        }
                        Text {
                            Layout.fillWidth: true
                            visible: model.inUse
                            elide: Text.ElideRight
                            text: "Connected"
                            font.family: "Valley Sans"
                            font.pixelSize: 11
                            color: Theme.fgDim
                        }
                    }

                    Text {
                        text: model.sig >= 75 ? "\u2587" : model.sig >= 45 ? "\u2585" : model.sig >= 20 ? "\u2583" : "\u2581"
                        font.family: Theme.font
                        font.pixelSize: 12
                        color: model.sig >= 45 ? Theme.fgDim : Theme.fgFaint
                    }
                }

                MouseArea {
                    id: hov
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: root.requestConnect(model.bssid, !!model.sec, model.ssid)
                }
            }
        }

        /* Footer: scan action or password entry */
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
                visible: !root.pwVisible

                Text {
                    text: root.connecting ? "" : (root.scanning ? "\uf6be" : "\uf002")
                    font.family: Theme.font
                    font.pixelSize: 14
                    color: Theme.fgDim
                }

                Text {
                    Layout.fillWidth: true
                    Layout.preferredWidth: 1
                    elide: Text.ElideRight
                    text: statusText()
                    font.family: "Valley Sans"
                    font.pixelSize: 12
                    color: root.status.length > 0 ? Theme.accentLit : Theme.fgFaint
                }

                Text {
                    text: "SCAN"
                    font.family: Theme.font
                    font.pixelSize: 11
                    font.bold: true
                    color: (!root.powerOn || root.scanning || root.connecting) ? Theme.fgFaint : Theme.accentLit
                    MouseArea {
                        anchors.fill: parent
                        anchors.margins: -6
                        cursorShape: Qt.PointingHandCursor
                        onClicked: root.scanNetworks()
                    }
                }
            }

            RowLayout {
                anchors.fill: parent
                anchors.leftMargin: 12
                anchors.rightMargin: 12
                spacing: 8
                visible: root.pwVisible

                Text {
                    elide: Text.ElideRight
                    text: root.pwSsid
                    font.family: "Valley Sans"
                    font.pixelSize: 12
                    color: Theme.fgDim
                    Layout.maximumWidth: 90
                }

                Rectangle {
                    Layout.fillWidth: true
                    Layout.preferredWidth: 1
                    Layout.preferredHeight: 26
                    radius: 8
                    color: "#0E0F14"
                    border.width: 1
                    border.color: Theme.outline

                    TextInput {
                        id: pwField
                        anchors.fill: parent
                        anchors.leftMargin: 8
                        anchors.rightMargin: 8
                        verticalAlignment: Text.AlignVCenter
                        font.family: "Valley Sans"
                        font.pixelSize: 12
                        color: Theme.fg
                        echoMode: TextInput.Password
                        focus: root.pwVisible
                        onAccepted: root.doConnect(root.pwBssid, root.pwField.text)
                    }
                }

                Text {
                    text: "CONNECT"
                    font.family: Theme.font
                    font.pixelSize: 11
                    font.bold: true
                    color: Theme.accentLit
                    MouseArea {
                        anchors.fill: parent
                        anchors.margins: -6
                        cursorShape: Qt.PointingHandCursor
                        onClicked: root.doConnect(root.pwBssid, root.pwField.text)
                    }
                }
            }
        }
    }

    function statusText() {
        if (root.pwVisible || root.connecting) return root.status
        if (root.scanning) return "Scanning for networks…"
        if (!root.powerOn) return "Wi-Fi is off"
        if (networkModel.count === 0) return "No networks found"
        return root.status
    }
}