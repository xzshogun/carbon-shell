import QtQuick
import QtQuick.Layouts
import QtQuick.Shapes
import Quickshell
import Quickshell.Io
import "../Singletons"

/**
 * ConnectivityOrbitPicker.qml
 *
 * Generic Monochrome Orbit-Orb Connectivity Picker for Carbon Shell.
 * Supports:
 * - Wi-Fi (nmcli): signal-proportional orbits (118 - sig*52 px), 12-dot keyboard password ring,
 *   connecting spinner, 800ms rose flash on wrong password, electron curve & pulse on success.
 * - Bluetooth (bluetoothctl): inner paired (~75px) and outer discovered (~115px) orbits,
 *   device type icons, battery arc, scanning spinner around nucleus strictly active while open.
 */
Item {
    id: root

    /* ── Configuration & Token Defaults ── */
    property int wifiOrbitBase: Theme.wifiOrbitBase || 118
    property int wifiOrbitFactor: Theme.wifiOrbitFactor || 52
    property int guideRingInner: Theme.guideRingInner || 70
    property int guideRingOuter: Theme.guideRingOuter || 105
    property int btInnerRadius: Theme.btInnerRadius || 75
    property int btOuterRadius: Theme.btOuterRadius || 115
    property int scanInterval: Theme.connectivityScanInterval || 8000
    property bool reducedMotion: Theme.reducedMotion || false

    /* ── Mode & State Machine ── */
    // pickerMode: "none" | "wifi" | "bluetooth"
    property string pickerMode: "none"
    // state: "idle" | "list" | "pass" | "connecting" | "done"
    property string state: "idle"

    /* ── Selection & Caption Communication ── */
    property var selectedItem: null
    property var hoveredItem: null
    property string statusMessage: ""
    readonly property string captionText: {
        if (root.isLoading) {
            return root.pickerMode === "wifi" ? "searching for networks…" : "discovering devices…"
        }
        if (root.state === "pass") {
            if (root.wrongPasswordActive) return "wrong password / try again"
            return "enter password / Enter to connect / Esc to cancel"
        }
        if (root.state === "connecting") {
            var target = root.selectedItem ? (root.selectedItem.ssid || root.selectedItem.name || "") : ""
            return "connecting to " + target + "…"
        }
        if (root.statusMessage.length > 0) return root.statusMessage

        var active = root.hoveredItem || root.selectedItem
        if (active) {
            if (root.pickerMode === "wifi") {
                var sec = active.isSecured ? "secured" : "open"
                var tail = (root.selectedItem === active) ? "tap again to connect" : "tap to select"
                return active.ssid + " / " + sec + " / " + active.signal + "% / " + tail
            } else if (root.pickerMode === "bluetooth") {
                var bStatus = active.connected ? "connected" : (active.paired ? "paired" : "unpaired")
                var batStr = (active.battery >= 0) ? (" / " + active.battery + "%") : ""
                var bTail = active.connected ? "tap again to disconnect" : "tap again to connect"
                return active.name + " / " + bStatus + batStr + " / " + bTail
            }
        }

        if (root.pickerMode === "wifi") {
            if (root.wifiList.length === 0 && !root.wifiScanning) return "no wi-fi networks found"
            return "select a network / tap nucleus to exit"
        } else if (root.pickerMode === "bluetooth") {
            if (root.btList.length === 0 && !root.btScanning) return "no bluetooth devices found"
            return root.btScanning ? "discovering devices…" : "select a device / tap nucleus to exit"
        }
        return ""
    }

    /* Signals to parent (NucleusHub) */
    signal backRequested()
    signal connectSuccess()

    /* ── Colors (Strict Monochrome + Halo Accent) ── */
    readonly property color colAccent: Theme.accent || "#00F0FF"
    readonly property color colErr: Theme.err || "#f87171"
    readonly property color colWhite: "#FFFFFF"
    readonly property color colFg: Theme.fg || "#e6e4f0"
    readonly property color colFgDim: Theme.fgDim || "#94a3b8"
    readonly property color colBgDark: Theme.bg || "#0e0e14"

    /* ── Internal Models ── */
    property var wifiList: []
    property bool wifiScanning: false
    property var btList: []
    property bool btScanning: false

    /* Dynamic discovering rotation angle for Bluetooth orbs */
    property real btScanRotation: 0.0
    NumberAnimation on btScanRotation {
        from: 0
        to: 360
        duration: 16000
        loops: Animation.Infinite
        running: root.pickerMode === "bluetooth" && root.btScanning
        easing.type: Easing.Linear
    }

    /* Password Input Buffer */
    property string passwordBuffer: ""
    property bool wrongPasswordActive: false

    /* Loading State */
    property bool isLoading: false

    Timer {
        id: btInitialScanTimer
        interval: 2400
        repeat: false
        onTriggered: {
            root.isLoading = false
        }
    }

    Timer {
        id: wifiLoadTimer
        interval: 1600
        repeat: false
        onTriggered: {
            root.isLoading = false
        }
    }

    /* Success Animation Props */
    property real electronProgress: 0.0
    property real pulseProgress: 0.0
    property bool showSuccessEffects: false

    /* ── Lifecycle Management ── */
    function openWifi() {
        root.stopBluetoothScan()
        root.pickerMode = "wifi"
        root.state = "list"
        root.selectedItem = null
        root.hoveredItem = null
        root.statusMessage = ""
        root.passwordBuffer = ""
        root.wrongPasswordActive = false
        root.showSuccessEffects = false
        root.isLoading = true
        wifiLoadTimer.restart()
        root.rescanWifi()
    }

    function openBluetooth() {
        root.stopBluetoothScan()
        root.pickerMode = "bluetooth"
        root.state = "list"
        root.selectedItem = null
        root.hoveredItem = null
        root.statusMessage = ""
        root.showSuccessEffects = false
        root.isLoading = true
        btInitialScanTimer.restart()
        root.startBluetoothScan()
    }

    function closePicker() {
        root.stopBluetoothScan()
        root.isLoading = false
        btInitialScanTimer.stop()
        wifiLoadTimer.stop()
        root.pickerMode = "none"
        root.state = "idle"
        root.selectedItem = null
        root.hoveredItem = null
        root.statusMessage = ""
        root.passwordBuffer = ""
        root.wrongPasswordActive = false
        root.showSuccessEffects = false
    }

    function goBack() {
        if (root.state === "pass") {
            root.state = "list"
            root.passwordBuffer = ""
            root.wrongPasswordActive = false
            keyScope.focus = false
        } else if (root.state === "list" || root.state === "connecting" || root.state === "done") {
            root.closePicker()
            root.backRequested()
        }
    }

    /* ══════════════════════════════════════════════════════════════════════
       WIFI BACKEND (nmcli)
       ══════════════════════════════════════════════════════════════════════ */
    function shellQuote(s) {
        return "'" + String(s).replace(/'/g, "'\\''") + "'"
    }

    Process {
        id: wifiListProc
        command: [
            "sh", "-c",
            "echo '===SAVED==='; nmcli -t -f NAME,TYPE con show 2>/dev/null | grep -E ':802-11-wireless|:wifi'; " +
            "echo '===WIFI==='; nmcli -t -f IN-USE,SSID,SIGNAL,SECURITY,BSSID dev wifi list 2>/dev/null"
        ]
        stdout: StdioCollector {
            id: wifiListOut
            waitForEnd: true
        }
        onExited: {
            root.wifiScanning = false
            console.log("[ConnectivityPicker] wifiListProc exited, stdout len:", wifiListOut.text ? wifiListOut.text.length : 0)
            root.parseWifiOutput(String(wifiListOut.text))
        }
    }

    Process {
        id: wifiRescanProc
        command: ["sh", "-c", "nmcli dev wifi rescan >/dev/null 2>&1"]
        onExited: {
            if (root.pickerMode === "wifi") {
                if (!wifiListProc.running) {
                    wifiListProc.running = true
                }
            }
        }
    }

    function rescanWifi() {
        root.wifiScanning = true
        // Immediately list cached networks so orbs pop up instantly without waiting for rescan
        wifiListProc.running = true
        wifiRescanProc.running = true
    }

    function parseWifiOutput(text) {
        var saved = {}
        var seen = {}
        var lines = String(text).split("\n")
        var inSaved = false
        var inWifi = false

        for (var i = 0; i < lines.length; i++) {
            var l = lines[i].trim()
            if (!l) continue
            if (l === "===SAVED===") { inSaved = true; inWifi = false; continue; }
            if (l === "===WIFI===") { inSaved = false; inWifi = true; continue; }

            if (inSaved) {
                var pS = l.split(":")
                if (pS.length >= 1 && pS[0]) saved[pS[0]] = true
            } else if (inWifi || (!inSaved && text.indexOf("===SAVED===") === -1)) {
                var raw = lines[i].replace(/\\:/g, "\u0000")
                var p = raw.split(":")
                if (p.length < 5) continue
                var ssid = p[1].replace(/\u0000/g, ":").trim()
                if (!ssid || ssid === "--") continue
                var sig = parseInt(p[2], 10) || 0
                var sec = p[3].replace(/\u0000/g, ":")
                var inUse = (p[0].trim() === "*" || p[0].trim() === "yes")
                var cur = seen[ssid]

                if (!cur || inUse || sig > cur.signal) {
                    var isSecured = (sec.length > 0 && sec.indexOf("--") === -1)
                    seen[ssid] = {
                        ssid: ssid,
                        signal: sig,
                        isSecured: isSecured,
                        security: sec,
                        bssid: p[4].replace(/\u0000/g, ":"),
                        connected: inUse,
                        isSaved: !!saved[ssid]
                    }
                }
            }
        }

        var rows = []
        for (var k in seen) rows.push(seen[k])
        rows.sort(function(a, b) {
            if (a.connected !== b.connected) return a.connected ? -1 : 1
            if (a.isSaved !== b.isSaved) return a.isSaved ? -1 : 1
            return b.signal - a.signal
        })

        // Cap to 14 orbs around orbit to prevent visual clutter
        if (rows.length > 14) rows = rows.slice(0, 14)

        var total = rows.length
        for (var j = 0; j < total; j++) {
            var item = rows[j]
            var sigNorm = Math.max(0.0, Math.min(1.0, item.signal / 100.0))
            item.orbitRadius = Math.round(root.wifiOrbitBase - sigNorm * root.wifiOrbitFactor)
            item.orbRadius = Math.round(11 + sigNorm * 8)
            item.angleDeg = j * (360.0 / Math.max(1, total))
        }

        console.log("[ConnectivityPicker] parsed wifi networks count:", rows.length)
        root.wifiList = rows
    }

    Process {
        id: wifiConnectProc
        property string targetSsid: ""
        stdout: StdioCollector { id: wifiConnOut; waitForEnd: true }
        stderr: StdioCollector { id: wifiConnErr; waitForEnd: true }
        onExited: {
            connectingMinTimer.stop()
            root.handleWifiConnectResult(exitCode, String(wifiConnErr.text) + "\n" + String(wifiConnOut.text))
        }
    }

    Timer {
        id: connectingMinTimer
        interval: 1400
        repeat: false
    }

    function connectWifi(item, password) {
        root.state = "connecting"
        connectingMinTimer.restart()
        wifiConnectProc.targetSsid = item.ssid

        var cmd = ""
        if (password && password.length > 0) {
            cmd = "nmcli con delete id " + root.shellQuote(item.ssid) + " >/dev/null 2>&1; " +
                  "nmcli dev wifi connect " + root.shellQuote(item.ssid) + " password " + root.shellQuote(password)
        } else if (item.isSaved) {
            cmd = "nmcli con up id " + root.shellQuote(item.ssid) + " 2>/dev/null || nmcli dev wifi connect " + root.shellQuote(item.ssid)
        } else {
            // Open network
            cmd = "nmcli dev wifi connect " + root.shellQuote(item.ssid)
        }

        wifiConnectProc.command = ["sh", "-c", cmd]
        wifiConnectProc.running = true
    }

    function handleWifiConnectResult(exitCode, output) {
        if (connectingMinTimer.running) {
            connectingMinTimer.triggered.connect(() => root.finalizeWifiConnect(exitCode, output))
            return
        }
        root.finalizeWifiConnect(exitCode, output)
    }

    function finalizeWifiConnect(exitCode, output) {
        if (exitCode === 0) {
            // Success!
            root.state = "done"
            root.triggerSuccessAnimation()
        } else {
            // Wrong password or secret failure
            var isSecretErr = (output.indexOf("Secrets were required") >= 0 ||
                               output.indexOf("no-secrets") >= 0 ||
                               output.indexOf("password") >= 0 ||
                               output.indexOf("802-11-wireless-security") >= 0 ||
                               (root.state === "connecting" && root.selectedItem && root.selectedItem.isSecured))

            if (isSecretErr) {
                root.state = "pass"
                root.wrongPasswordActive = true
                wrongPasswordTimer.restart()
            } else {
                root.statusMessage = "connection failed / try again"
                root.state = "list"
                delayClearStatusTimer.restart()
            }
        }
    }

    Timer {
        id: wrongPasswordTimer
        interval: 800
        onTriggered: {
            root.wrongPasswordActive = false
            root.passwordBuffer = ""
        }
    }

    Timer {
        id: delayClearStatusTimer
        interval: 3200
        onTriggered: root.statusMessage = ""
    }

    /* Success animation sequence:
       1. All 12 dots illuminate then fade out.
       2. Electron travels along curve from orb (0, -96) into nucleus (0, 0) over 700ms (ease in/out).
       3. Bond line stays. Pulse ring expands from nucleus (600ms).
    */
    function triggerSuccessAnimation() {
        root.showSuccessEffects = true
        successElectronAnim.restart()
        pulseRingAnim.restart()
    }

    NumberAnimation {
        id: successElectronAnim
        target: root
        property: "electronProgress"
        from: 0.0
        to: 1.0
        duration: root.reducedMotion ? 100 : 700
        easing.type: Easing.InOutCubic
    }

    NumberAnimation {
        id: pulseRingAnim
        target: root
        property: "pulseProgress"
        from: 0.0
        to: 1.0
        duration: root.reducedMotion ? 100 : 600
        easing.type: Easing.OutCubic
        onFinished: {
            // Re-fetch wifi list to reflect new connected state and notify
            root.rescanWifi()
            root.connectSuccess()
        }
    }

    /* ══════════════════════════════════════════════════════════════════════
       BLUETOOTH BACKEND (bluetoothctl)
       ══════════════════════════════════════════════════════════════════════ */
    Process {
        id: btScanOnProc
        command: ["sh", "-c", "bluetoothctl scan on >/dev/null 2>&1"]
    }

    Process {
        id: btScanOffProc
        command: ["sh", "-c", "bluetoothctl scan off >/dev/null 2>&1; pkill -f 'bluetoothctl scan on' 2>/dev/null || true"]
    }

    Process {
        id: btListProc
        command: [
            "sh", "-c",
            "echo '===PAIRED==='; bluetoothctl devices Paired 2>/dev/null | sed -E 's/^Device ([0-9A-F:]+) (.*)/\\1|\\2/'; " +
            "echo '===CONNECTED==='; bluetoothctl devices Connected 2>/dev/null | sed -E 's/^Device ([0-9A-F:]+).*/\\1/'; " +
            "echo '===ALL==='; bluetoothctl devices 2>/dev/null | sed -E 's/^Device ([0-9A-F:]+) (.*)/\\1|\\2/'"
        ]
        stdout: StdioCollector {
            id: btListOut
            waitForEnd: true
        }
        onExited: {
            console.log("[ConnectivityPicker] btListProc exited, stdout len:", btListOut.text ? btListOut.text.length : 0)
            root.parseBtOutput(String(btListOut.text))
        }
    }

    Timer {
        id: btPollTimer
        interval: 2200
        repeat: true
        running: root.pickerMode === "bluetooth" && root.btScanning
        onTriggered: {
            if (!btListProc.running) btListProc.running = true
        }
    }

    function startBluetoothScan() {
        root.btScanning = true
        btScanOnProc.running = true
        btListProc.running = true
    }

    function stopBluetoothScan() {
        if (!root.btScanning && root.pickerMode !== "bluetooth") return
        root.btScanning = false
        btPollTimer.stop()
        btScanOffProc.running = true
    }

    function parseBtOutput(text) {
        var pairedMap = {}
        var connectedMap = {}
        var allDevices = {}
        var lines = String(text).split("\n")
        var section = ""

        for (var i = 0; i < lines.length; i++) {
            var l = lines[i].trim()
            if (!l) continue
            if (l === "===PAIRED===") { section = "paired"; continue; }
            if (l === "===CONNECTED===") { section = "connected"; continue; }
            if (l === "===ALL===") { section = "all"; continue; }

            if (section === "paired") {
                var barP = l.indexOf("|")
                if (barP > 0) {
                    var mP = l.substring(0, barP).trim()
                    var nP = l.substring(barP + 1).trim()
                    if (mP) {
                        pairedMap[mP] = nP
                        allDevices[mP] = { mac: mP, name: nP, paired: true, connected: false, battery: -1 }
                    }
                }
            } else if (section === "connected") {
                connectedMap[l] = true
            } else if (section === "all") {
                var barA = l.indexOf("|")
                if (barA > 0) {
                    var mA = l.substring(0, barA).trim()
                    var nA = l.substring(barA + 1).trim()
                    if (mA && !allDevices[mA]) {
                        allDevices[mA] = { mac: mA, name: nA, paired: false, connected: false, battery: -1 }
                    }
                }
            }
        }

        var pairedRows = []
        var discoveredRows = []

        for (var k in allDevices) {
            var dev = allDevices[k]
            dev.connected = !!connectedMap[dev.mac]
            dev.paired = !!pairedMap[dev.mac]
            dev.icon = root.getBtIcon(dev.name)

            if (dev.paired) {
                pairedRows.push(dev)
            } else {
                discoveredRows.push(dev)
            }
        }

        // Arrange paired on inner orbit (~75px), discovered on outer orbit (~115px)
        var totalPaired = pairedRows.length
        for (var pIdx = 0; pIdx < totalPaired; pIdx++) {
            var pDev = pairedRows[pIdx]
            pDev.orbitRadius = root.btInnerRadius
            pDev.orbRadius = 15
            pDev.angleDeg = pIdx * (360.0 / Math.max(1, totalPaired))
        }

        // Cap discovered to 10
        if (discoveredRows.length > 10) discoveredRows = discoveredRows.slice(0, 10)
        var totalDisc = discoveredRows.length
        for (var dIdx = 0; dIdx < totalDisc; dIdx++) {
            var dDev = discoveredRows[dIdx]
            dDev.orbitRadius = root.btOuterRadius
            dDev.orbRadius = 14
            dDev.angleDeg = (dIdx * (360.0 / Math.max(1, totalDisc))) + 18.0
        }

        root.btList = pairedRows.concat(discoveredRows)
        console.log("[ConnectivityPicker] parsed bt devices total:", root.btList.length, "paired:", pairedRows.length, "discovered:", discoveredRows.length)
    }

    function getBtIcon(name) {
        var lower = String(name || "").toLowerCase()
        if (lower.indexOf("head") >= 0 || lower.indexOf("ear") >= 0 || lower.indexOf("airpod") >= 0 || lower.indexOf("buds") >= 0 || lower.indexOf("airdopes") >= 0 || lower.indexOf("rockerz") >= 0) return "headphones"
        if (lower.indexOf("speaker") >= 0 || lower.indexOf("sound") >= 0) return "speaker"
        if (lower.indexOf("phone") >= 0 || lower.indexOf("mobile") >= 0) return "smartphone"
        if (lower.indexOf("mouse") >= 0) return "mouse"
        if (lower.indexOf("keyboard") >= 0 || lower.indexOf("key") >= 0) return "keyboard"
        if (lower.indexOf("tv") >= 0 || lower.indexOf("display") >= 0) return "tv"
        return "bluetooth"
    }

    Process {
        id: btActionProc
        stdout: StdioCollector { id: btActOut; waitForEnd: true }
        stderr: StdioCollector { id: btActErr; waitForEnd: true }
        onExited: {
            root.state = "list"
            if (exitCode === 0) {
                root.statusMessage = "device updated"
            } else {
                root.statusMessage = "action failed"
            }
            delayClearStatusTimer.restart()
            btListProc.running = true
        }
    }

    function toggleBtDevice(item) {
        root.state = "connecting"
        var cmd = ""
        if (item.connected) {
            cmd = "bluetoothctl disconnect " + root.shellQuote(item.mac)
        } else if (item.paired) {
            cmd = "bluetoothctl connect " + root.shellQuote(item.mac)
        } else {
            // Unpaired -> pair and connect
            cmd = "bluetoothctl trust " + root.shellQuote(item.mac) + " >/dev/null 2>&1; " +
                  "bluetoothctl pair " + root.shellQuote(item.mac) + " && " +
                  "bluetoothctl connect " + root.shellQuote(item.mac)
        }
        btActionProc.command = ["sh", "-c", cmd]
        btActionProc.running = true
    }

    /* ══════════════════════════════════════════════════════════════════════
       KEYBOARD LISTENER (Password Input in 'pass' State)
       ══════════════════════════════════════════════════════════════════════ */
    Item {
        id: keyScope
        focus: root.pickerMode === "wifi" && root.state === "pass"

        Keys.onEscapePressed: {
            root.goBack()
        }
        Keys.onReturnPressed: {
            if (root.selectedItem && root.passwordBuffer.length > 0) {
                root.connectWifi(root.selectedItem, root.passwordBuffer)
            }
        }
        Keys.onEnterPressed: {
            if (root.selectedItem && root.passwordBuffer.length > 0) {
                root.connectWifi(root.selectedItem, root.passwordBuffer)
            }
        }
        Keys.onBackPressed: {
            if (root.passwordBuffer.length > 0) {
                root.passwordBuffer = root.passwordBuffer.slice(0, -1)
            }
        }
        Keys.onDeletePressed: {
            if (root.passwordBuffer.length > 0) {
                root.passwordBuffer = root.passwordBuffer.slice(0, -1)
            }
        }
        Keys.onPressed: (event) => {
            if (event.key === Qt.Key_Backspace) {
                if (root.passwordBuffer.length > 0) {
                    root.passwordBuffer = root.passwordBuffer.slice(0, -1)
                }
                event.accepted = true
                return
            }
            if (event.text && event.text.length > 0 && (!event.modifiers || event.modifiers === Qt.ShiftModifier)) {
                root.passwordBuffer += event.text
                event.accepted = true
            }
        }
    }

    onStateChanged: {
        if (root.state === "pass") {
            Qt.callLater(() => keyScope.forceActiveFocus())
        }
    }

    /* ══════════════════════════════════════════════════════════════════════
       VISUAL RENDERING: GUIDE RINGS, ORBS, AND 12-DOT PASSWORD SYSTEM
       ══════════════════════════════════════════════════════════════════════ */
    Item {
        id: visualContainer
        anchors.centerIn: parent
        visible: root.pickerMode !== "none"

        /* ── Bohr Atomic Scanning Orbs (The Two Moving Orbs on Loading Screen) ── */
        Item {
            id: scanningOrbitSystem
            anchors.centerIn: parent
            width: 1
            height: 1
            visible: (root.pickerMode === "bluetooth" || root.pickerMode === "wifi") && root.isLoading
            opacity: visible ? 1.0 : 0.0
            Behavior on opacity { NumberAnimation { duration: 240; easing.type: Easing.OutCubic } }

            // Continuous rotation (5.8s, matching inner orbit of CarbonLewisLogo)
            NumberAnimation on rotation {
                from: 0
                to: 360
                duration: 5800
                loops: Animation.Infinite
                running: scanningOrbitSystem.visible
                easing.type: Easing.Linear
            }

            // Dot 1: Top (0, -root.guideRingInner)
            Item {
                x: -width / 2
                y: -root.guideRingInner - height / 2
                width: 22
                height: 22

                Rectangle {
                    anchors.centerIn: parent
                    width: 20
                    height: 20
                    radius: 10
                    color: Qt.rgba(root.colAccent.r, root.colAccent.g, root.colAccent.b, 0.38)
                }
                Rectangle {
                    anchors.centerIn: parent
                    width: 12
                    height: 12
                    radius: 6
                    color: root.colWhite
                    border.width: 1.5
                    border.color: root.colAccent

                    Rectangle {
                        anchors.centerIn: parent
                        width: 4
                        height: 4
                        radius: 2
                        color: root.colAccent
                    }
                }
            }

            // Dot 2: Bottom (0, +root.guideRingInner)
            Item {
                x: -width / 2
                y: root.guideRingInner - height / 2
                width: 22
                height: 22

                Rectangle {
                    anchors.centerIn: parent
                    width: 20
                    height: 20
                    radius: 10
                    color: Qt.rgba(root.colAccent.r, root.colAccent.g, root.colAccent.b, 0.38)
                }
                Rectangle {
                    anchors.centerIn: parent
                    width: 12
                    height: 12
                    radius: 6
                    color: root.colWhite
                    border.width: 1.5
                    border.color: root.colAccent

                    Rectangle {
                        anchors.centerIn: parent
                        width: 4
                        height: 4
                        radius: 2
                        color: root.colAccent
                    }
                }
            }
        }

        /* ── Thin Bond Line from Selected Orb to Nucleus upon Success ── */
        Rectangle {
            visible: root.showSuccessEffects
            x: -0.8
            y: -70
            width: 1.6
            height: 70
            color: Qt.rgba(1, 1, 1, 0.40)
        }

        /* ── Pulse Ring Expanding from Nucleus on Success (600ms) ── */
        Rectangle {
            visible: root.showSuccessEffects && root.pulseProgress > 0.001
            anchors.centerIn: parent
            width: 38 + (root.pulseProgress * 110)
            height: 38 + (root.pulseProgress * 110)
            radius: width / 2
            color: "transparent"
            border.color: Qt.rgba(1, 1, 1, (1.0 - root.pulseProgress) * 0.85)
            border.width: 2.0
        }

        /* ── Success Electron Travelling along Curve into Nucleus (700ms) ── */
        Item {
            visible: root.showSuccessEffects && root.electronProgress < 0.999
            // Curve from (0, -96) to (0, 0)
            readonly property real ep: root.electronProgress
            readonly property real curX: Math.sin(ep * Math.PI) * 16.0
            readonly property real curY: -96.0 + (ep * 96.0)

            x: curX - 4
            y: curY - 4
            width: 8
            height: 8

            Rectangle {
                anchors.fill: parent
                radius: 4
                color: root.colWhite
            }

            // Subtle trail behind electron
            Rectangle {
                x: -Math.sin(ep * Math.PI) * 3
                y: -6
                width: 5
                height: 5
                radius: 2.5
                color: Qt.rgba(1, 1, 1, 0.5)
            }
        }

        /* ── 12-Dot Password Ring around Selected Orb in 'pass' State ── */
        Item {
            id: dotRingSystem
            x: 0
            y: -96
            visible: root.pickerMode === "wifi" && (root.state === "pass" || root.state === "connecting" || root.state === "done")

            // Connecting Spinner Arc around Dot Ring (radius 44)
            Item {
                anchors.centerIn: parent
                width: 88
                height: 88
                visible: root.state === "connecting"

                RotationAnimation on rotation {
                    from: 0
                    to: 360
                    duration: 1200
                    loops: Animation.Infinite
                    running: root.state === "connecting"
                }

                Canvas {
                    anchors.fill: parent
                    onPaint: {
                        var ctx = getContext("2d")
                        ctx.reset()
                        ctx.lineWidth = 2.0
                        ctx.strokeStyle = root.colAccent
                        ctx.beginPath()
                        ctx.arc(44, 44, 42, 0, Math.PI * 0.9, false)
                        ctx.stroke()
                    }
                }
            }

            // 12 Dots (Radius 38)
            Repeater {
                model: 12
                delegate: Item {
                    id: dotDelegate
                    required property int index
                    readonly property real angleDeg: index * 30.0
                    readonly property real rad: angleDeg * (Math.PI / 180.0)
                    readonly property real dotRadius: 38

                    readonly property bool isLit: {
                        if (root.showSuccessEffects) return true
                        var len = root.passwordBuffer.length
                        if (len === 0) return false
                        return index < len
                    }

                    x: (dotRadius * Math.cos(rad)) - width / 2
                    y: (dotRadius * Math.sin(rad)) - height / 2
                    width: isLit ? 6 : 4
                    height: isLit ? 6 : 4
                    Behavior on width { NumberAnimation { duration: 120; easing.type: Easing.OutCubic } }
                    Behavior on height { NumberAnimation { duration: 120; easing.type: Easing.OutCubic } }

                    Rectangle {
                        anchors.fill: parent
                        radius: width / 2
                        color: {
                            if (root.wrongPasswordActive) return root.colErr
                            if (dotDelegate.isLit) return root.colWhite
                            return Qt.rgba(1, 1, 1, 0.22)
                        }
                        Behavior on color { ColorAnimation { duration: 160 } }
                    }
                }
            }
        }

        /* ── Active Orbs (WiFi or Bluetooth) ── */
        Repeater {
            model: (!root.isLoading && root.pickerMode === "wifi") ? root.wifiList : ((!root.isLoading && root.pickerMode === "bluetooth") ? root.btList : [])
            delegate: Item {
                id: orbDelegate
                required property int index
                required property var modelData

                readonly property bool isThisSelected: root.selectedItem === modelData
                readonly property bool inPassMode: root.state === "pass" || root.state === "connecting" || root.state === "done"

                // Target Coordinates:
                // If in 'pass' and selected: smoothly moves to 96px above nucleus (x: 0, y: -96).
                // Otherwise: regular radial position around center.
                readonly property real baseRad: ((modelData.angleDeg || 0.0) + (root.pickerMode === "bluetooth" && !modelData.paired ? root.btScanRotation : 0.0)) * (Math.PI / 180.0)
                readonly property real targetX: (inPassMode && isThisSelected) ? 0.0 : (modelData.orbitRadius * Math.cos(baseRad))
                readonly property real targetY: (inPassMode && isThisSelected) ? -96.0 : (modelData.orbitRadius * Math.sin(baseRad))

                // Target Size:
                // If in 'pass' and selected: grows to radius 26 (width 52).
                readonly property real targetD: (inPassMode && isThisSelected) ? 52.0 : ((modelData.orbRadius || 14) * 2)

                // Staggered Spawning Animation (55ms stagger)
                property real spawnProgress: 0.0
                Component.onCompleted: {
                    if (root.reducedMotion) {
                        spawnProgress = 1.0
                    } else {
                        spawnTimer.restart()
                    }
                }

                Timer {
                    id: spawnTimer
                    interval: Math.max(10, index * 55)
                    repeat: false
                    onTriggered: spawnAnim.restart()
                }

                NumberAnimation {
                    id: spawnAnim
                    target: orbDelegate
                    property: "spawnProgress"
                    from: 0.0
                    to: 1.0
                    duration: 320
                    easing.type: Easing.OutCubic
                }

                x: targetX - width / 2
                y: targetY - height / 2
                width: targetD
                height: targetD
                scale: (inPassMode && !isThisSelected) ? 0.4 : (0.3 + 0.7 * spawnProgress)
                opacity: (inPassMode && !isThisSelected) ? 0.0 : Math.min(1.0, spawnProgress * 1.5)

                Behavior on x { NumberAnimation { duration: 340; easing.type: Easing.OutCubic } }
                Behavior on y { NumberAnimation { duration: 340; easing.type: Easing.OutCubic } }
                Behavior on width { NumberAnimation { duration: 300; easing.type: Easing.OutCubic } }
                Behavior on height { NumberAnimation { duration: 300; easing.type: Easing.OutCubic } }
                Behavior on opacity { NumberAnimation { duration: 240; easing.type: Easing.OutCubic } }
                Behavior on scale { NumberAnimation { duration: 260; easing.type: Easing.OutCubic } }

                // Selection White Ring (shows when selected)
                Rectangle {
                    anchors.centerIn: parent
                    width: parent.width + 8
                    height: parent.height + 8
                    radius: width / 2
                    color: "transparent"
                    border.color: root.colWhite
                    border.width: 1.6
                    visible: orbDelegate.isThisSelected && !orbDelegate.inPassMode
                    opacity: orbDelegate.isThisSelected ? 1.0 : 0.0
                    Behavior on opacity { NumberAnimation { duration: 160 } }
                }

                // Glowing outer halo for Bluetooth iconless orbs (like ValenceDot on lockscreen)
                Rectangle {
                    anchors.centerIn: parent
                    width: parent.width + (orbMouse.containsMouse ? 14 : 8)
                    height: width
                    radius: width / 2
                    visible: root.pickerMode === "bluetooth"
                    color: Qt.rgba(root.colAccent.r, root.colAccent.g, root.colAccent.b, orbMouse.containsMouse ? 0.42 : 0.22)
                    Behavior on width { NumberAnimation { duration: 180; easing.type: Easing.OutCubic } }
                }

                // Battery Arc Indicator (Bluetooth devices with known battery)
                Canvas {
                    anchors.centerIn: parent
                    width: parent.width + 6
                    height: parent.height + 6
                    visible: root.pickerMode === "bluetooth" && modelData.battery !== undefined && modelData.battery >= 0
                    onPaint: {
                        var ctx = getContext("2d")
                        ctx.reset()
                        var r = (width / 2) - 1.5
                        var pct = Math.max(0.0, Math.min(1.0, modelData.battery / 100.0))
                        ctx.lineWidth = 1.5
                        ctx.strokeStyle = root.colAccent
                        ctx.beginPath()
                        ctx.arc(width / 2, height / 2, r, -Math.PI / 2, (-Math.PI / 2) + (2 * Math.PI * pct), false)
                        ctx.stroke()
                    }
                }

                // Main Orb Body
                Rectangle {
                    id: orbBody
                    anchors.fill: parent
                    radius: width / 2
                    // Connected network/device is solid white with dark glyph/center
                    color: modelData.connected ? root.colWhite : (orbMouse.containsMouse ? Qt.rgba(root.colAccent.r, root.colAccent.g, root.colAccent.b, 0.28) : Qt.rgba(root.colBgDark.r, root.colBgDark.g, root.colBgDark.b, 0.94))
                    border.color: modelData.connected ? root.colWhite : (orbMouse.containsMouse ? root.colAccent : Qt.rgba(1, 1, 1, 0.35))
                    border.width: 1.5

                    // Inner bright neon center dot (iconless orb like the ones around C in Bohr model)
                    Rectangle {
                        anchors.centerIn: parent
                        visible: root.pickerMode === "bluetooth"
                        width: Math.max(4, Math.round(parent.width * 0.32))
                        height: width
                        radius: width / 2
                        color: modelData.connected ? "#0b0e14" : root.colAccent
                    }

                    // Glyph: lock / wifi (ONLY for Wi-Fi; Bluetooth is an iconless orb)
                    Text {
                        anchors.centerIn: parent
                        visible: root.pickerMode === "wifi"
                        text: modelData.isSecured ? "lock" : "wifi"
                        font.family: Theme.fontIcon
                        font.pixelSize: (orbDelegate.inPassMode && orbDelegate.isThisSelected) ? 22 : Math.max(10, Math.round(parent.width * 0.52))
                        color: modelData.connected ? "#0b0e14" : root.colFg
                    }

                    MouseArea {
                        id: orbMouse
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor

                        onEntered: {
                            root.hoveredItem = modelData
                        }
                        onExited: {
                            if (root.hoveredItem === modelData) root.hoveredItem = null
                        }

                        onClicked: {
                            if (orbDelegate.isThisSelected) {
                                // Tap again -> execute connect/disconnect
                                root.triggerAction(modelData)
                            } else {
                                // Tap once -> select
                                root.selectedItem = modelData
                            }
                        }
                    }
                }
            }
        }
    }

    /* ── Action Trigger Helper ── */
    function triggerAction(item) {
        if (!item) return
        if (root.pickerMode === "wifi") {
            if (item.connected) {
                // Already connected
                root.statusMessage = "already connected to " + item.ssid
                delayClearStatusTimer.restart()
                return
            }

            // Check if enterprise / 802.1X / captive portal or hidden
            var isEnterprise = (item.security && (item.security.indexOf("802.1X") >= 0 || item.security.indexOf("WPA3-Enterprise") >= 0))
            if (isEnterprise) {
                Quickshell.execDetached(["nm-connection-editor"])
                return
            }

            if (!item.isSecured || item.isSaved) {
                // Open network or saved connection -> connect directly!
                root.connectWifi(item, "")
            } else {
                // Unsaved secured network -> enter 'pass' state
                root.state = "pass"
                root.passwordBuffer = ""
                root.wrongPasswordActive = false
            }
        } else if (root.pickerMode === "bluetooth") {
            root.toggleBtDevice(item)
        }
    }
}
