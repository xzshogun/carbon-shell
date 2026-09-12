import QtQuick
import QtQuick.Layouts
import QtQuick.Effects
import Quickshell
import Quickshell.Io
import Quickshell.Services.Mpris
import "../components"
import "../Singletons"

/**
 * Carbon quick-settings panel. Hovers open from the top-right hot corner.
 * Three modes behind a small tab bar:
 *   0. Quick  — now-playing strip + Bluetooth / Wi-Fi / night light / gaming
 *               toggles + a screen recorder (full screen or slurp region, with
 *               separate microphone / app-audio switches mixed via a null sink).
 *   1. Calendar — compact month widget.
 *   2. Timer  — pomodoro / stopwatch.
 * States are probed live from the CLIs on open and after any toggle fires.
 */
Item {
    id: root

    property bool open: false
    property bool hovered: false
    property int mode: 0
    property string corner: "bottom_right"

    /* Fixed size: the panel never resizes — modes swipe sideways instead. */
    readonly property int paneW: 264
    readonly property int paneH: 296
    readonly property int cardW: root.paneW
    readonly property int cardH: 49 + root.paneH
    implicitWidth: root.cardW + 28
    implicitHeight: root.cardH + 28
    width: root.implicitWidth
    height: root.implicitHeight

    readonly property var cardItem: card
    readonly property bool animatingOut: !root.open && card.opacity > 0.001

    /* Pager position for a pane: current sits at 0, neighbours sit one page
     * off either side and animate in/out when the mode changes. */
    function paneX(idx) { return (idx - root.mode) * root.paneW }


    /* ============================ Now playing ============================ */
    readonly property var players: Mpris.players.values !== undefined
        ? Mpris.players.values : Mpris.players
    property var activePlayer: null
    property string trackTitle: ""
    property string trackArtist: ""
    property string artUrl: ""
    property bool playing: false
    property bool canPrev: false
    property bool canNext: false
    property bool posSupported: false
    property double posUs: 0
    property double lenUs: 0
    property real progRatio: root.lenUs > 0
        ? Math.max(0, Math.min(1, root.posUs / root.lenUs)) : 0

    function resolveActivePlayer() {
        if (!root.players || root.players.length === 0)
            return null
        for (let i = 0; i < root.players.length; i++)
            if (root.players[i].playbackState === MprisPlaybackState.Playing)
                return root.players[i]
        for (let i = 0; i < root.players.length; i++)
            if (root.players[i].playbackState === MprisPlaybackState.Paused
                && (root.players[i].trackTitle || "").length > 0)
                return root.players[i]
        return root.players[0]
    }

    function syncPlayer() {
        const p = root.resolveActivePlayer()
        root.activePlayer = p
        root.trackTitle = p ? String(p.trackTitle || "") : ""
        root.trackArtist = (p && p.metadata && p.metadata["xesam:artist"]) ? String(p.metadata["xesam:artist"]) : ""
        root.artUrl = p && p.metadata ? String(p.metadata["mpris:artUrl"] || "") : ""
        root.playing = !!p && p.playbackState === MprisPlaybackState.Playing
        root.canPrev = !!p && p.canGoPrevious
        root.canNext = !!p && p.canGoNext
        root.posSupported = !!p && p.positionSupported
        root.posUs = p ? p.position : 0
        root.lenUs = p ? p.length : 0
    }

    /* Smooth the progress knob between Mpris position poll refreshes. */
    Timer {
        id: progTick
        interval: 200
        repeat: true
        running: root.open && root.playing && root.lenUs > 0
        onTriggered: {
            if (root.posUs + 200000 <= root.lenUs) root.posUs += 200000
        }
    }

    Timer {
        id: playerProbe
        interval: 800
        repeat: true
        running: root.open
        onTriggered: root.syncPlayer()
    }

    function togglePlayPause() {
        if (root.activePlayer) root.activePlayer.togglePlaying()
    }

    function seekToRatio(r) {
        if (root.lenUs <= 0) return
        const clamped = Math.max(0, Math.min(1, r))
        root.posUs = clamped * root.lenUs
        const targetSec = root.posUs / 1000000.0
        try {
            if (root.activePlayer) root.activePlayer.position = root.posUs
        } catch (e) {}
        Quickshell.execDetached(["playerctl", "position", targetSec.toFixed(2)])
        if (root.activePlayer && root.activePlayer.positionSupported) {
            root.activePlayer.positionChanged()
        }
    }

    /* ============================ Quick toggles ============================ */
    property bool btOn: false
    property bool wifiOn: true
    property bool nightAvailable: true
    property bool nightOn: false
    property bool gameOn: false
    property bool dndOn: false
    property string wifiName: ""
    property string btName: ""
    property bool wifiPopupOpen: false
    property bool btPopupOpen: false

    Timer {
        id: settleTimer
        interval: 900
        onTriggered: root.refreshStates()
    }

    function refreshStates() {
        if (!root.open) return
        if (!btProbe.running) btProbe.running = true
        if (!wifiProbe.running) wifiProbe.running = true
        if (!nightProbe.running) nightProbe.running = true
        if (!gameProbe.running) gameProbe.running = true
        if (!dndProbe.running) dndProbe.running = true
        if (!btNameProbe.running) btNameProbe.running = true
        if (!wifiNameProbe.running) wifiNameProbe.running = true
        if (!recProbe.running) recProbe.running = true
    }

    /* Screen Recorder */
    Process {
        id: recProbe
        command: ["sh", "-c", "if pgrep -x wf-recorder >/dev/null 2>&1 || ([ -f /tmp/rec.pid ] && kill -0 $(cat /tmp/rec.pid 2>/dev/null) 2>/dev/null); then st=$(stat -c %Y /tmp/rec.pid 2>/dev/null || stat -c %Y /tmp/rec.out 2>/dev/null || date +%s); now=$(date +%s); echo \"alive:$((now - st))\"; else echo \"dead:0\"; fi"]
        stdout: StdioCollector { id: recProbeC; waitForEnd: true }
        onExited: {
            const raw = String(recProbeC.text).trim()
            const parts = raw.split(":")
            const isAlive = parts[0] === "alive"
            root.recWorking = isAlive
            if (isAlive && parts.length > 1) {
                const el = parseInt(parts[1]) || 0
                if (el > 0 && Math.abs(el - root.recElapsed) > 2) {
                    root.recElapsed = el
                }
            }
        }
    }

    /* Bluetooth */
    Process {
        id: btProbe
        command: ["sh", "-c", "timeout 4 bluetoothctl show | sed -n 's/.*Powered:[ ]*//p' | tr -d ' \\n\\r'"]
        stdout: StdioCollector { id: btC; waitForEnd: true }
        onExited: root.btOn = String(btC.text).trim() === "yes"
    }
    Process {
        id: btNameProbe
        command: ["sh", "-c", "bluetoothctl devices Connected 2>/dev/null | sed 's/^Device [0-9A-F:]* //'"]
        stdout: StdioCollector { id: btNameC; waitForEnd: true }
        onExited: root.btName = String(btNameC.text).trim()
    }
    function toggleBt() {
        root.btOn = !root.btOn
        if (!root.btOn) root.btName = ""
        Quickshell.execDetached(["sh", "-c",
            "bluetoothctl power " + (root.btOn ? "on" : "off") + " >/dev/null 2>&1"])
        settleTimer.restart()
    }

    /* Wi-Fi */
    Process {
        id: wifiProbe
        command: ["sh", "-c", "nmcli radio wifi | tr -d ' \\n\\r'"]
        stdout: StdioCollector { id: wifiC; waitForEnd: true }
        onExited: root.wifiOn = String(wifiC.text).trim() === "enabled"
    }
    Process {
        id: wifiNameProbe
        command: ["sh", "-c", "wifi=$(nmcli -t -f IN-USE,SSID dev wifi 2>/dev/null | grep -E '^\\*:|^yes:' | head -1 | cut -d: -f2-); [ -n \"$wifi\" ] && echo \"$wifi\" || nmcli -t -f NAME connection show --active 2>/dev/null | grep -v '^lo:' | head -1 | cut -d: -f1"]
        stdout: StdioCollector { id: wifiNameC; waitForEnd: true }
        onExited: root.wifiName = String(wifiNameC.text).trim()
    }
    function toggleWifi() {
        root.wifiOn = !root.wifiOn
        if (!root.wifiOn) root.wifiName = ""
        Quickshell.execDetached(["sh", "-c",
            "nmcli radio wifi " + (root.wifiOn ? "on" : "off") + " >/dev/null 2>&1"])
        settleTimer.restart()
    }

    /* Night light (hyprsunset) */
    Process {
        id: nightProbe
        command: ["/home/shogun/.config/hypr/scripts/carbon-night.sh", "status"]
        stdout: StdioCollector { id: nightC; waitForEnd: true }
        onExited: {
            const v = String(nightC.text).trim()
            root.nightAvailable = v !== "missing"
            root.nightOn = v === "on"
        }
    }
    function toggleNight() {
        if (!root.nightAvailable) return
        root.nightOn = !root.nightOn
        Quickshell.execDetached(["/home/shogun/.config/hypr/scripts/carbon-night.sh", root.nightOn ? "on" : "off"])
        settleTimer.restart()
    }

    /* Gaming mode: drop Hyprland animations for lower latency */
    Process {
        id: gameProbe
        command: ["sh", "-c",
            "hyprctl getoption animations:enabled -j 2>/dev/null | sed -n 's/.*\\\"bool\\\":[[:space:]]*\\(true\\|false\\).*/\\1/p'"]
        stdout: StdioCollector { id: gameC; waitForEnd: true }
        onExited: root.gameOn = String(gameC.text).trim() === "false"
    }
    function toggleGame() {
        root.gameOn = !root.gameOn
        Quickshell.execDetached(["hyprctl", "eval",
            root.gameOn
                ? "hl.config({ animations = { enabled = false } })"
                : "hl.config({ animations = { enabled = true } })"])
        settleTimer.restart()
    }

    /* Do Not Disturb */
    Process {
        id: dndProbe
        command: ["sh", "-c", "if [ -f /tmp/carbon-dnd.on ]; then echo true; else echo false; fi"]
        stdout: StdioCollector { id: dndC; waitForEnd: true }
        onExited: {
            root.dndOn = String(dndC.text).trim() === "true"
            Theme.dnd = root.dndOn
        }
    }
    function toggleDnd() {
        root.dndOn = !root.dndOn
        Theme.dnd = root.dndOn
        Quickshell.execDetached(["sh", "-c",
            root.dndOn ? "touch /tmp/carbon-dnd.on" : "rm -f /tmp/carbon-dnd.on"])
        settleTimer.restart()
    }

    /* ============================ Recorder ============================ */
    property bool recWorking: false
    property bool recWaiting: false
    property bool recFail: false
    property bool recFull: true
    property bool recMic: true
    property bool recApp: true
    property int recElapsed: 0
    property string recDone: ""

    readonly property string recScriptDir: "/home/shogun/.config/hypr/scripts"

    function recStatus() {
        if (root.recFail) return "Failed to start recording"
        if (root.recWaiting) return "Select area to record…"
        if (root.recWorking) return "● REC  " + root.fmtRec(root.recElapsed)
        if (root.recDone.length > 0) return "Saved · " + root.recDone
        return "Ready"
    }
    function fmtRec(s) {
        const m = Math.floor(s / 60)
        return String(m).padStart(2, "0") + ":" + String(s % 60).padStart(2, "0")
    }
    function recStart() {
        if (root.recWorking || root.recWaiting) return
        root.recDone = ""
        root.recFail = false
        root.recElapsed = 0
        root.recWaiting = !root.recFull
        recStartProc.command = ["/bin/sh", root.recScriptDir + "/carbon-rec-start.sh",
            root.recFull ? "full" : "region",
            root.recMic ? "1" : "0", root.recApp ? "1" : "0"]
        recStartProc.running = true
    }
    function recStop() {
        recStopProc.command = ["/bin/sh", root.recScriptDir + "/carbon-rec-stop.sh"]
        recStopProc.running = true
    }

    Timer {
        id: recClock
        interval: 1000
        repeat: true
        running: root.recWorking && !root.recWaiting
        onTriggered: root.recElapsed++
    }

    Timer {
        id: recMsgTimer
        interval: 5000
        onTriggered: root.recDone = ""
    }

    /* Periodic recorder health & status check */
    Timer {
        id: recHeartbeatTimer
        interval: 1500
        repeat: true
        running: root.open || root.recWorking
        triggeredOnStart: true
        onTriggered: {
            if (!recProbe.running) recProbe.running = true
        }
    }

    Process {
        id: recStartProc
        command: ["/bin/sh", "/bin/true"]
        stdout: StdioCollector { id: recStartC; waitForEnd: true }
        onExited: {
            root.recWaiting = false
            if (exitCode === 0) {
                /* the start script detaches wf-recorder; confirm it is still
                 * alive before flipping the UI to "recording" */
                recVerifyProc.running = true
            } else {
                root.recFail = true
                recFailTimer.restart()
            }
        }
    }

    Process {
        id: recVerifyProc
        command: ["sh", "-c", "[ -f /tmp/rec.pid ] && kill -0 $(cat /tmp/rec.pid) 2>/dev/null && echo alive || echo dead"]
        stdout: StdioCollector { id: recVerifyC; waitForEnd: true }
        onExited: {
            if (String(recVerifyC.text).trim() === "alive") {
                root.recWorking = true
            } else {
                root.recFail = true
                recFailTimer.restart()
            }
        }
    }

    Timer {
        id: recFailTimer
        interval: 4000
        onTriggered: root.recFail = false
    }

    Process {
        id: recStopProc
        command: ["/bin/sh", "/bin/true"]
        stdout: StdioCollector { id: recStopC; waitForEnd: true }
        onExited: {
            root.recWorking = false
            const v = String(recStopC.text).trim().replace(/^saved:\s*/, "")
            if (v.length > 0) {
                root.recDone = v.substring(v.lastIndexOf("/") + 1)
                recMsgTimer.restart()
            }
        }
    }

    onOpenChanged: {
        if (root.open) {
            root.syncPlayer()
            root.refreshStates()
            if (!layoutLoader.running) layoutLoader.running = true
            console.log("DEBUG_DIMS: winH=" + (parent ? parent.height : -1) + " rootH=" + root.height + " cardH=" + card.height + " paneH=" + (typeof pane0 !== 'undefined' ? pane0.height : -1) + " mediaY=" + (typeof cardMedia !== 'undefined' ? cardMedia.y : -1) + " togY=" + (typeof cardToggles !== 'undefined' ? cardToggles.y : -1) + " recY=" + (typeof cardRecorder !== 'undefined' ? cardRecorder.y : -1) + " recH=" + (typeof cardRecorder !== 'undefined' ? cardRecorder.height : -1));
        } else {
            root.wifiPopupOpen = false
            root.btPopupOpen = false
        }
    }

    /* ==================== Reorderable Layout ==================== */
    property var cardOrder: ["media", "toggles", "recorder"]
    property string activeCardDrag: ""

    function getCardHeight(name) {
        if (name === "media") return 62;
        if (name === "recorder") return 106;
        if (name === "toggles") return 118;
        return 100;
    }

    function getSlotY(slotIdx) {
        if (slotIdx <= 0) return 0;
        var h0 = getCardHeight(root.cardOrder[0]);
        var y1 = h0 + 5;
        if (slotIdx === 1) return y1;
        var h1 = getCardHeight(root.cardOrder[1]);
        return y1 + h1 + 5;
    }

    function getTargetCardY(name) {
        var idx = root.cardOrder.indexOf(name);
        return idx >= 0 ? getSlotY(idx) : 0;
    }

    function checkCardSwap(draggedName, centerY) {
        var curSlot = root.cardOrder.indexOf(draggedName);
        if (curSlot === -1) return;

        var bestSlot = 0;
        var minDist = 999999;
        for (var s = 0; s < 3; s++) {
            var sCenter = getSlotY(s) + getCardHeight(root.cardOrder[s]) / 2;
            var d = Math.abs(centerY - sCenter);
            if (d < minDist) {
                minDist = d;
                bestSlot = s;
            }
        }

        if (bestSlot !== curSlot) {
            var arr = root.cardOrder.slice();
            arr.splice(curSlot, 1);
            arr.splice(bestSlot, 0, draggedName);
            root.cardOrder = arr;
        }
    }

    /* 5 Toggle tiles ordering */
    property var tileOrder: ["wifi", "bt", "night", "game", "dnd"]
    property string activeTileDrag: ""

    readonly property var tileSlotCoords: [
        { x: 37,  y: 2 },
        { x: 101, y: 2 },
        { x: 165, y: 2 },
        { x: 69,  y: 52 },
        { x: 133, y: 52 }
    ]

    function getTileSlotX(name) {
        var idx = root.tileOrder.indexOf(name);
        return idx >= 0 && idx < tileSlotCoords.length ? tileSlotCoords[idx].x : 37;
    }

    function getTileSlotY(name) {
        var idx = root.tileOrder.indexOf(name);
        return idx >= 0 && idx < tileSlotCoords.length ? tileSlotCoords[idx].y : 2;
    }

    function checkTileSwap(draggedName, centerX, centerY) {
        var curSlot = root.tileOrder.indexOf(draggedName);
        if (curSlot === -1) return;

        var bestSlot = curSlot;
        var minDist = 999999;
        for (var s = 0; s < tileSlotCoords.length; s++) {
            var sx = tileSlotCoords[s].x + 23;
            var sy = tileSlotCoords[s].y + 23;
            var dist = Math.hypot(centerX - sx, centerY - sy);
            if (dist < minDist) {
                minDist = dist;
                bestSlot = s;
            }
        }

        if (bestSlot !== curSlot && minDist < 34) {
            var arr = root.tileOrder.slice();
            arr.splice(curSlot, 1);
            arr.splice(bestSlot, 0, draggedName);
            root.tileOrder = arr;
        }
    }

    Component.onCompleted: {
        layoutLoader.running = true
        recProbe.running = true
        root.refreshStates()
    }

    function saveLayout() {
        var d = {
            cardOrder: root.cardOrder,
            tileOrder: root.tileOrder
        };
        Quickshell.execDetached(["sh", "-c",
            "echo '" + JSON.stringify(d) + "' > /home/shogun/.config/hypr/carbon-qs-layout.json"]);
    }

    function resetLayout() {
        root.cardOrder = ["media", "toggles", "recorder"];
        root.tileOrder = ["wifi", "bt", "night", "game", "dnd"];
        if (typeof cardMedia !== 'undefined') cardMedia.y = Qt.binding(() => root.getTargetCardY("media"));
        if (typeof cardToggles !== 'undefined') cardToggles.y = Qt.binding(() => root.getTargetCardY("toggles"));
        if (typeof cardRecorder !== 'undefined') cardRecorder.y = Qt.binding(() => root.getTargetCardY("recorder"));
        if (typeof tileWifi !== 'undefined') {
            tileWifi.x = Qt.binding(() => root.getTileSlotX("wifi"));
            tileWifi.y = Qt.binding(() => root.getTileSlotY("wifi"));
        }
        if (typeof tileBt !== 'undefined') {
            tileBt.x = Qt.binding(() => root.getTileSlotX("bt"));
            tileBt.y = Qt.binding(() => root.getTileSlotY("bt"));
        }
        if (typeof tileNight !== 'undefined') {
            tileNight.x = Qt.binding(() => root.getTileSlotX("night"));
            tileNight.y = Qt.binding(() => root.getTileSlotY("night"));
        }
        if (typeof tileGame !== 'undefined') {
            tileGame.x = Qt.binding(() => root.getTileSlotX("game"));
            tileGame.y = Qt.binding(() => root.getTileSlotY("game"));
        }
        if (typeof tileDnd !== 'undefined') {
            tileDnd.x = Qt.binding(() => root.getTileSlotX("dnd"));
            tileDnd.y = Qt.binding(() => root.getTileSlotY("dnd"));
        }
        Quickshell.execDetached(["rm", "-f", "/home/shogun/.config/hypr/carbon-qs-layout.json"]);
    }

    Process {
        id: layoutLoader
        command: ["sh", "-c", "cat /home/shogun/.config/hypr/carbon-qs-layout.json 2>/dev/null || true"]
        stdout: StdioCollector { id: layoutC; waitForEnd: true }
        onExited: {
            try {
                var txt = String(layoutC.text).trim();
                if (txt.length > 5) {
                    var d = JSON.parse(txt);
                    if (Array.isArray(d.cardOrder) && d.cardOrder.length === 3) {
                        root.cardOrder = d.cardOrder;
                    }
                    if (Array.isArray(d.tileOrder) && d.tileOrder.length === 5) {
                        root.tileOrder = d.tileOrder;
                    }
                }
            } catch (e) {}
        }
    }

    /* ============================ Visual ============================ */
    Rectangle {
        id: card
        width: root.cardW
        height: root.cardH
        radius: 14
        color: Theme.bg
        border.color: root.open ? Theme.accentLit : Theme.outline
        border.width: 1
        Behavior on border.color { ColorAnimation { duration: root.open ? 350 : 150; easing.type: Easing.OutQuad } }

        transformOrigin: root.corner === "top_left" ? Item.TopLeft :
                         (root.corner === "bottom_left" ? Item.BottomLeft : Item.BottomRight)

        x: (root.corner === "top_left" || root.corner === "bottom_left") ? (root.open ? 28 : 0) : (root.open ? 0 : 28)
        y: root.corner === "top_left" ? (root.open ? 28 : 0) : (root.open ? 0 : 28)
        scale: root.open ? 1.0 : 0.90
        opacity: root.open ? 1.0 : 0.0

        Behavior on opacity {
            NumberAnimation {
                duration: root.open ? 200 : 140
                easing.type: root.open ? Easing.OutCubic : Easing.InQuad
            }
        }
        Behavior on x {
            NumberAnimation {
                duration: root.open ? 280 : 160
                easing.type: root.open ? Easing.OutExpo : Easing.InQuad
            }
        }
        Behavior on y {
            NumberAnimation {
                duration: root.open ? 280 : 160
                easing.type: root.open ? Easing.OutExpo : Easing.InQuad
            }
        }
        Behavior on scale {
            NumberAnimation {
                duration: root.open ? 280 : 160
                easing.type: root.open ? Easing.OutExpo : Easing.InQuad
            }
        }

        HoverHandler {
            onHoveredChanged: root.hovered = hovered
        }

        ColumnLayout {
            anchors.fill: parent
            anchors.margins: 8
            spacing: 4

            /* --- Mode tabs --- */
            RowLayout {
                id: modeTabsRow
                Layout.fillWidth: true
                Layout.preferredHeight: 24
                spacing: 4

                opacity: root.open ? 1 : 0
                transform: Translate {
                    y: root.open ? 0 : -8
                    Behavior on y { NumberAnimation { duration: root.open ? 240 : 120; easing.type: Easing.OutExpo } }
                }
                Behavior on opacity { NumberAnimation { duration: root.open ? 200 : 120; easing.type: Easing.OutCubic } }

                Repeater {
                    model: [
                        { glyph: "\uf085" },
                        { glyph: "\uf0ae" },
                        { glyph: "\uf017" }
                    ]
                    delegate: Rectangle {
                        required property int index
                        required property var modelData
                        Layout.preferredWidth: 24
                        Layout.preferredHeight: 24
                        radius: 12
                        color: root.mode === index ? Theme.accent
                             : (hov.hovered ? Theme.bgHover : "transparent")

                        Behavior on color { ColorAnimation { duration: Motion.fast } }

                        Text {
                            anchors.centerIn: parent
                            text: modelData.glyph
                            font.family: Theme.font
                            font.pixelSize: 12
                            color: root.mode === index ? "#0e0e12" : Theme.fgDim
                        }
                        MouseArea {
                            id: hov
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: root.mode = index
                        }
                    }
                }
                Item { Layout.fillWidth: true }

                Rectangle {
                    visible: root.mode === 0
                    Layout.preferredWidth: 22
                    Layout.preferredHeight: 22
                    radius: 11
                    color: rstHov.hovered ? Theme.bgHover : "transparent"
                    Behavior on color { ColorAnimation { duration: Motion.fast } }

                    Text {
                        anchors.centerIn: parent
                        text: "\uf0e2"
                        font.family: Theme.font
                        font.pixelSize: 10
                        color: rstHov.hovered ? Theme.accent : Theme.fgFaint
                    }
                    MouseArea {
                        id: rstHov
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: root.resetLayout()
                    }
                }
            }

            Rectangle {
                Layout.fillWidth: true
                Layout.preferredHeight: 1
                height: 1
                color: Theme.outline
            }

            /* --- Content (modes swipe horizontally, size stays fixed) --- */
            Item {
                Layout.fillWidth: true
                Layout.preferredHeight: root.paneH
                clip: true

                /* ==== Mode 0: quick settings + recorder (draggable modules) ==== */
                Item {
                    id: pane0
                    width: parent.width
                    height: parent.height
                    x: root.paneX(0)
                    opacity: root.mode === 0 ? 1 : 0
                    enabled: root.mode === 0
                    Behavior on x {
                        NumberAnimation { duration: 220; easing.type: Easing.OutCubic }
                    }
                    Behavior on opacity {
                        NumberAnimation { duration: 150; easing.type: Easing.InOutCubic }
                    }

                    /* 1. Media Player Card */
                    Rectangle {
                        id: cardMedia
                        width: parent.width
                        height: 62
                        x: 0
                        y: root.activeCardDrag === "media" ? y : root.getTargetCardY("media")
                        radius: Theme.radius
                        color: mediaDrag.drag.active ? Theme.bgAlt : "transparent"
                        border.color: mediaDrag.drag.active ? Theme.accent : "transparent"
                        border.width: 1
                        z: mediaDrag.drag.active ? 50 : 1
                        scale: mediaDrag.drag.active ? 1.02 : 1.0
                        Behavior on scale { NumberAnimation { duration: 100 } }
                        Behavior on y {
                            enabled: root.activeCardDrag !== "media"
                            NumberAnimation { duration: 240; easing.type: Easing.OutCubic }
                        }

                        opacity: root.open ? 1 : 0
                        transform: Translate {
                            y: root.open ? 0 : 8
                            Behavior on y { NumberAnimation { duration: root.open ? 280 : 120; easing.type: Easing.OutExpo } }
                        }
                        Behavior on opacity { NumberAnimation { duration: root.open ? 240 : 120; easing.type: Easing.OutCubic } }

                        ColumnLayout {
                            anchors.fill: parent
                            spacing: 1

                            /* Header with title + drag handle */
                            RowLayout {
                                Layout.fillWidth: true
                                Layout.preferredHeight: 11

                                Text {
                                    text: "NOW PLAYING"
                                    font.family: Theme.font
                                    font.pixelSize: 8
                                    font.letterSpacing: 2
                                    color: Theme.fgFaint
                                }

                                Item { Layout.fillWidth: true }

                                Text {
                                    text: "\uf047"
                                    font.family: Theme.font
                                    font.pixelSize: 9
                                    color: mediaDrag.drag.active || mediaDrag.containsMouse ? Theme.accent : Theme.fgFaint
                                }
                            }

                            /* Now-playing strip (no lyrics) */
                            RowLayout {
                                Layout.fillWidth: true
                                Layout.preferredHeight: 34
                                spacing: 6

                                Rectangle {
                                    Layout.preferredWidth: 32
                                    Layout.preferredHeight: 32
                                    Layout.alignment: Qt.AlignVCenter
                                    radius: 6
                                    color: Theme.bgAlt
                                    clip: true

                                    Image {
                                        anchors.fill: parent
                                        source: root.artUrl
                                        sourceSize: Qt.size(64, 64)
                                        fillMode: Image.PreserveAspectCrop
                                        visible: root.artUrl.length > 0
                                    }

                                    Text {
                                        anchors.centerIn: parent
                                        text: "\uf001"
                                        font.family: Theme.font
                                        font.pixelSize: 14
                                        color: Theme.fgFaint
                                        visible: root.artUrl.length === 0
                                    }
                                }

                                ColumnLayout {
                                    Layout.fillWidth: true
                                    Layout.preferredWidth: 1
                                    spacing: 0

                                    Text {
                                        Layout.fillWidth: true
                                        text: root.trackTitle.length > 0 ? root.trackTitle : "Nothing playing"
                                        font.family: "Valley Sans"
                                        font.pixelSize: 12
                                        font.weight: Font.Bold
                                        color: root.trackTitle.length > 0 ? Theme.fg : Theme.fgFaint
                                        elide: Text.ElideRight
                                    }
                                    Text {
                                        Layout.fillWidth: true
                                        text: root.trackArtist
                                        font.family: "Valley Sans"
                                        font.pixelSize: 9
                                        color: Theme.fgDim
                                        elide: Text.ElideRight
                                    }
                                }

                                RowLayout {
                                    spacing: 2
                                    IconButton {
                                        glyph: "\uf048"
                                        tip: "Previous"
                                        size: 11
                                        color: root.canPrev ? Theme.fgDim : Theme.fgFaint
                                        pointer: true
                                        onClicked: { if (root.activePlayer) root.activePlayer.previous() }
                                    }
                                    IconButton {
                                        glyph: root.playing ? "\uf04c" : "\uf04b"
                                        tip: root.playing ? "Pause" : "Play"
                                        size: 13
                                        color: "#0e0e12"
                                        bg: Theme.accent
                                        hoverBg: Theme.accentLit
                                        pointer: true
                                        onClicked: root.togglePlayPause()
                                    }
                                    IconButton {
                                        glyph: "\uf051"
                                        tip: "Next"
                                        size: 11
                                        color: root.canNext ? Theme.fgDim : Theme.fgFaint
                                        pointer: true
                                        onClicked: { if (root.activePlayer) root.activePlayer.next() }
                                    }
                                }
                            }

                            /* Wavy progress (draggable & clickable seek) */
                            Item {
                                id: progContainer
                                Layout.fillWidth: true
                                Layout.preferredHeight: 14

                                Rectangle {
                                    anchors.left: knob.right
                                    anchors.leftMargin: 2
                                    anchors.right: parent.right
                                    anchors.verticalCenter: parent.verticalCenter
                                    height: 2
                                    radius: 1
                                    color: Theme.fgFaint
                                    visible: root.lenUs > 0 && root.progRatio < 0.99
                                }

                                WavyLine {
                                    anchors.left: parent.left
                                    anchors.right: knob.left
                                    anchors.rightMargin: 2
                                    anchors.verticalCenter: parent.verticalCenter
                                    height: 10
                                    visible: root.lenUs > 0 && root.progRatio > 0.004
                                    color: Theme.accent
                                    lineWidth: 2
                                    amplitudeMultiplier: 0.8 + 1.2 * root.progRatio
                                    frequency: 3 + 7 * root.progRatio
                                    fullLength: Math.max(1, parent.width)
                                }

                                Rectangle {
                                    id: knob
                                    width: seekMouse.containsMouse || seekMouse.pressed ? 5 : 3
                                    height: seekMouse.containsMouse || seekMouse.pressed ? 12 : 10
                                    radius: width / 2
                                    color: seekMouse.containsMouse || seekMouse.pressed ? Theme.accentLit : Theme.fg
                                    anchors.verticalCenter: parent.verticalCenter
                                    visible: root.lenUs > 0
                                    x: root.progRatio * Math.max(0, parent.width - width)
                                    Behavior on width { NumberAnimation { duration: 120 } }
                                    Behavior on height { NumberAnimation { duration: 120 } }
                                    Behavior on color { ColorAnimation { duration: 120 } }
                                }

                                MouseArea {
                                    id: seekMouse
                                    anchors.fill: parent
                                    anchors.margins: -4
                                    hoverEnabled: true
                                    cursorShape: Qt.PointingHandCursor
                                    preventStealing: true

                                    function updateSeek(mouse) {
                                        if (progContainer.width > 0) {
                                            const r = Math.max(0, Math.min(1, mouse.x / progContainer.width))
                                            root.seekToRatio(r)
                                        }
                                    }

                                    onPressed: mouse => updateSeek(mouse)
                                    onPositionChanged: mouse => {
                                        if (pressed) updateSeek(mouse)
                                    }
                                }
                            }
                        }

                        MouseArea {
                            id: mediaDrag
                            anchors.top: parent.top
                            anchors.left: parent.left
                            anchors.right: parent.right
                            height: 24
                            hoverEnabled: true
                            cursorShape: drag.active ? Qt.ClosedHandCursor : Qt.SizeAllCursor
                            drag.target: cardMedia
                            drag.axis: Drag.YAxis
                            drag.minimumY: 0
                            drag.maximumY: Math.max(0, pane0.height - cardMedia.height)
                            onPressed: root.activeCardDrag = "media"
                            onPositionChanged: {
                                if (drag.active) {
                                    root.checkCardSwap("media", cardMedia.y + cardMedia.height / 2)
                                }
                            }
                            onReleased: {
                                root.activeCardDrag = ""
                                cardMedia.y = Qt.binding(() => root.getTargetCardY("media"))
                                root.saveLayout()
                            }
                        }
                    }

                    /* 2. Quick Settings Card */
                    Rectangle {
                        id: cardToggles
                        width: parent.width
                        height: 118
                        x: 0
                        y: root.activeCardDrag === "toggles" ? y : root.getTargetCardY("toggles")
                        radius: Theme.radius
                        color: togglesDrag.drag.active ? Theme.bgAlt : "transparent"
                        border.color: togglesDrag.drag.active ? Theme.accent : "transparent"
                        border.width: 1
                        z: togglesDrag.drag.active ? 50 : 1
                        scale: togglesDrag.drag.active ? 1.02 : 1.0
                        Behavior on scale { NumberAnimation { duration: 100 } }
                        Behavior on y {
                            enabled: root.activeCardDrag !== "toggles"
                            NumberAnimation { duration: 240; easing.type: Easing.OutCubic }
                        }

                        opacity: root.open ? 1 : 0
                        transform: Translate {
                            y: root.open ? 0 : 14
                            Behavior on y { NumberAnimation { duration: root.open ? 320 : 120; easing.type: Easing.OutExpo } }
                        }
                        Behavior on opacity { NumberAnimation { duration: root.open ? 280 : 120; easing.type: Easing.OutCubic } }

                        ColumnLayout {
                            anchors.fill: parent
                            spacing: 2

                            RowLayout {
                                Layout.fillWidth: true
                                Layout.preferredHeight: 11

                                Text {
                                    text: "QUICK SETTINGS"
                                    font.family: Theme.font
                                    font.pixelSize: 8
                                    font.letterSpacing: 2
                                    color: Theme.fgFaint
                                }

                                Item { Layout.fillWidth: true }

                                Text {
                                    text: "\uf047"
                                    font.family: Theme.font
                                    font.pixelSize: 9
                                    color: togglesDrag.drag.active || togglesDrag.containsMouse ? Theme.accent : Theme.fgFaint
                                }
                            }

                            Item {
                                id: togglesArea
                                Layout.fillWidth: true
                                Layout.fillHeight: true

                                QuickTile {
                                    id: tileWifi
                                    tileId: "wifi"
                                    tileSize: 46
                                    draggable: true
                                    x: root.activeTileDrag === "wifi" ? x : root.getTileSlotX("wifi")
                                    y: root.activeTileDrag === "wifi" ? y : root.getTileSlotY("wifi")
                                    glyph: "\uf1eb"
                                    label: "Wi-Fi"
                                    on: root.wifiOn
                                    held: root.wifiPopupOpen
                                    act: function() { root.wifiPopupOpen = !root.wifiPopupOpen }
                                    onTileMoved: (cx, cy) => {
                                        root.activeTileDrag = "wifi"
                                        root.checkTileSwap("wifi", cx, cy)
                                    }
                                    onDragEnded: {
                                        root.activeTileDrag = ""
                                        tileWifi.x = Qt.binding(() => root.getTileSlotX("wifi"))
                                        tileWifi.y = Qt.binding(() => root.getTileSlotY("wifi"))
                                        root.saveLayout()
                                    }
                                }
                                QuickTile {
                                    id: tileBt
                                    tileId: "bt"
                                    tileSize: 46
                                    draggable: true
                                    x: root.activeTileDrag === "bt" ? x : root.getTileSlotX("bt")
                                    y: root.activeTileDrag === "bt" ? y : root.getTileSlotY("bt")
                                    glyph: "\uf294"
                                    label: "Bluetooth"
                                    on: root.btOn
                                    held: root.btPopupOpen
                                    act: function() { root.btPopupOpen = !root.btPopupOpen }
                                    onTileMoved: (cx, cy) => {
                                        root.activeTileDrag = "bt"
                                        root.checkTileSwap("bt", cx, cy)
                                    }
                                    onDragEnded: {
                                        root.activeTileDrag = ""
                                        tileBt.x = Qt.binding(() => root.getTileSlotX("bt"))
                                        tileBt.y = Qt.binding(() => root.getTileSlotY("bt"))
                                        root.saveLayout()
                                    }
                                }
                                QuickTile {
                                    id: tileNight
                                    tileId: "night"
                                    tileSize: 46
                                    draggable: true
                                    x: root.activeTileDrag === "night" ? x : root.getTileSlotX("night")
                                    y: root.activeTileDrag === "night" ? y : root.getTileSlotY("night")
                                    glyph: "\uf186"
                                    label: "Night light"
                                    on: root.nightOn
                                    disabled: !root.nightAvailable
                                    act: root.toggleNight
                                    onTileMoved: (cx, cy) => {
                                        root.activeTileDrag = "night"
                                        root.checkTileSwap("night", cx, cy)
                                    }
                                    onDragEnded: {
                                        root.activeTileDrag = ""
                                        tileNight.x = Qt.binding(() => root.getTileSlotX("night"))
                                        tileNight.y = Qt.binding(() => root.getTileSlotY("night"))
                                        root.saveLayout()
                                    }
                                }
                                QuickTile {
                                    id: tileGame
                                    tileId: "game"
                                    tileSize: 46
                                    draggable: true
                                    x: root.activeTileDrag === "game" ? x : root.getTileSlotX("game")
                                    y: root.activeTileDrag === "game" ? y : root.getTileSlotY("game")
                                    glyph: "\uf11b"
                                    label: "Gaming mode"
                                    on: root.gameOn
                                    act: root.toggleGame
                                    onTileMoved: (cx, cy) => {
                                        root.activeTileDrag = "game"
                                        root.checkTileSwap("game", cx, cy)
                                    }
                                    onDragEnded: {
                                        root.activeTileDrag = ""
                                        tileGame.x = Qt.binding(() => root.getTileSlotX("game"))
                                        tileGame.y = Qt.binding(() => root.getTileSlotY("game"))
                                        root.saveLayout()
                                    }
                                }
                                QuickTile {
                                    id: tileDnd
                                    tileId: "dnd"
                                    tileSize: 46
                                    draggable: true
                                    x: root.activeTileDrag === "dnd" ? x : root.getTileSlotX("dnd")
                                    y: root.activeTileDrag === "dnd" ? y : root.getTileSlotY("dnd")
                                    glyph: root.dndOn ? "\uf1f6" : "\uf0f3"
                                    label: "DND"
                                    on: root.dndOn
                                    act: root.toggleDnd
                                    onTileMoved: (cx, cy) => {
                                        root.activeTileDrag = "dnd"
                                        root.checkTileSwap("dnd", cx, cy)
                                    }
                                    onDragEnded: {
                                        root.activeTileDrag = ""
                                        tileDnd.x = Qt.binding(() => root.getTileSlotX("dnd"))
                                        tileDnd.y = Qt.binding(() => root.getTileSlotY("dnd"))
                                        root.saveLayout()
                                    }
                                }
                            }
                        }

                        MouseArea {
                            id: togglesDrag
                            anchors.top: parent.top
                            anchors.left: parent.left
                            anchors.right: parent.right
                            height: 24
                            hoverEnabled: true
                            cursorShape: drag.active ? Qt.ClosedHandCursor : Qt.SizeAllCursor
                            drag.target: cardToggles
                            drag.axis: Drag.YAxis
                            drag.minimumY: 0
                            drag.maximumY: Math.max(0, pane0.height - cardToggles.height)
                            onPressed: root.activeCardDrag = "toggles"
                            onPositionChanged: {
                                if (drag.active) {
                                    root.checkCardSwap("toggles", cardToggles.y + cardToggles.height / 2)
                                }
                            }
                            onReleased: {
                                root.activeCardDrag = ""
                                cardToggles.y = Qt.binding(() => root.getTargetCardY("toggles"))
                                root.saveLayout()
                            }
                        }
                    }

                    /* 3. Screen Recorder Card */
                    Rectangle {
                        id: cardRecorder
                        width: parent.width
                        height: 106
                        x: 0
                        y: root.activeCardDrag === "recorder" ? y : root.getTargetCardY("recorder")
                        radius: Theme.radius
                        color: recDrag.drag.active ? Theme.bgAlt : "transparent"
                        border.color: recDrag.drag.active ? Theme.accent : "transparent"
                        border.width: 1
                        z: recDrag.drag.active ? 50 : 1
                        scale: recDrag.drag.active ? 1.02 : 1.0
                        Behavior on scale { NumberAnimation { duration: 100 } }
                        Behavior on y {
                            enabled: root.activeCardDrag !== "recorder"
                            NumberAnimation { duration: 240; easing.type: Easing.OutCubic }
                        }

                        opacity: root.open ? 1 : 0
                        transform: Translate {
                            y: root.open ? 0 : 20
                            Behavior on y { NumberAnimation { duration: root.open ? 360 : 120; easing.type: Easing.OutExpo } }
                        }
                        Behavior on opacity { NumberAnimation { duration: root.open ? 320 : 120; easing.type: Easing.OutCubic } }

                        ColumnLayout {
                            anchors.fill: parent
                            spacing: 2

                            RowLayout {
                                Layout.fillWidth: true
                                Layout.preferredHeight: 11

                                Text {
                                    text: "SCREEN RECORDER"
                                    font.family: Theme.font
                                    font.pixelSize: 8
                                    font.letterSpacing: 2
                                    color: Theme.fgFaint
                                }

                                Item { Layout.fillWidth: true }

                                Text {
                                    text: "\uf047"
                                    font.family: Theme.font
                                    font.pixelSize: 9
                                    color: recDrag.drag.active || recDrag.containsMouse ? Theme.accent : Theme.fgFaint
                                }
                            }

                            RowLayout {
                                Layout.fillWidth: true
                                Layout.preferredHeight: 22
                                spacing: 4

                                Rectangle {
                                    Layout.fillWidth: true
                                    Layout.preferredHeight: 22
                                    radius: 11
                                    color: root.recFull && !root.recWorking ? Theme.accent
                                         : (fHov.hovered && !root.recWorking ? Theme.bgHover : "transparent")
                                    opacity: root.recWorking ? 0.4 : 1
                                    Text {
                                        anchors.centerIn: parent
                                        text: "\uf065   Full screen"
                                        font.family: Theme.font
                                        font.pixelSize: 10
                                        color: root.recFull && !root.recWorking ? "#0e0e12" : Theme.fgDim
                                        horizontalAlignment: Text.AlignHCenter
                                    }
                                    MouseArea {
                                        id: fHov
                                        anchors.fill: parent
                                        hoverEnabled: true
                                        cursorShape: root.recWorking ? Qt.ArrowCursor : Qt.PointingHandCursor
                                        onClicked: if (!root.recWorking) root.recFull = true
                                    }
                                }

                                Rectangle {
                                    Layout.fillWidth: true
                                    Layout.preferredHeight: 22
                                    radius: 11
                                    color: !root.recFull && !root.recWorking ? Theme.accent
                                         : (rHov.hovered && !root.recWorking ? Theme.bgHover : "transparent")
                                    opacity: root.recWorking ? 0.4 : 1
                                    Text {
                                        anchors.centerIn: parent
                                        text: "\uf0b2   Region"
                                        font.family: Theme.font
                                        font.pixelSize: 10
                                        color: !root.recFull && !root.recWorking ? "#0e0e12" : Theme.fgDim
                                        horizontalAlignment: Text.AlignHCenter
                                    }
                                    MouseArea {
                                        id: rHov
                                        anchors.fill: parent
                                        hoverEnabled: true
                                        cursorShape: root.recWorking ? Qt.ArrowCursor : Qt.PointingHandCursor
                                        onClicked: if (!root.recWorking) root.recFull = false
                                    }
                                }
                            }

                            RowLayout {
                                Layout.fillWidth: true
                                Layout.preferredHeight: 22
                                spacing: 4

                                RecToggle {
                                    label: "Microphone"
                                    checked: root.recMic
                                    disabled: root.recWorking
                                    heightHint: 22
                                    onToggled: root.recMic = !root.recMic
                                    widthHint: (card.width - 16 - 4) / 2
                                }
                                RecToggle {
                                    label: "App audio"
                                    checked: root.recApp
                                    disabled: root.recWorking
                                    heightHint: 22
                                    onToggled: root.recApp = !root.recApp
                                    widthHint: (card.width - 16 - 4) / 2
                                }
                            }

                            Rectangle {
                                Layout.fillWidth: true
                                Layout.preferredHeight: 26
                                radius: 13
                                color: root.recWaiting ? Theme.bgHover
                                     : root.recWorking ? "#8f2d24" : Theme.accent
                                Text {
                                    anchors.centerIn: parent
                                    text: root.recWaiting ? "SELECTING AREA…"
                                        : root.recWorking ? "\uf04d   STOP" : "START RECORDING"
                                    font.family: "Valley Sans"
                                    font.pixelSize: 10
                                    font.weight: Font.Bold
                                    color: root.recWorking ? "#ffffff" : "#0e0e12"
                                }
                                MouseArea {
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: root.recWorking ? root.recStop() : root.recStart()
                                }
                            }

                            Text {
                                Layout.fillWidth: true
                                Layout.preferredHeight: 10
                                text: root.recStatus()
                                font.family: "Valley Sans"
                                font.pixelSize: 9
                                color: (root.recWorking || root.recFail) ? "#ff7b6b" : Theme.fgFaint
                                horizontalAlignment: Text.AlignHCenter
                                elide: Text.ElideRight
                            }
                        }

                        MouseArea {
                            id: recDrag
                            anchors.top: parent.top
                            anchors.left: parent.left
                            anchors.right: parent.right
                            height: 24
                            hoverEnabled: true
                            cursorShape: drag.active ? Qt.ClosedHandCursor : Qt.SizeAllCursor
                            drag.target: cardRecorder
                            drag.axis: Drag.YAxis
                            drag.minimumY: 0
                            drag.maximumY: Math.max(0, pane0.height - cardRecorder.height)
                            onPressed: root.activeCardDrag = "recorder"
                            onPositionChanged: {
                                if (drag.active) {
                                    root.checkCardSwap("recorder", cardRecorder.y + cardRecorder.height / 2)
                                }
                            }
                            onReleased: {
                                root.activeCardDrag = ""
                                cardRecorder.y = Qt.binding(() => root.getTargetCardY("recorder"))
                                root.saveLayout()
                            }
                        }
                    }
                }

                /* ==== Mode 1: to-do list ==== */
                TodoPane {
                    width: parent.width
                    height: parent.height
                    x: root.paneX(1)
                    opacity: root.mode === 1 ? 1 : 0
                    enabled: root.mode === 1
                    transform: Translate {
                        y: root.open ? 0 : 12
                        Behavior on y { NumberAnimation { duration: root.open ? 300 : 120; easing.type: Easing.OutExpo } }
                    }
                    Behavior on x {
                        NumberAnimation { duration: 220; easing.type: Easing.OutCubic }
                    }
                    Behavior on opacity {
                        NumberAnimation { duration: 150; easing.type: Easing.InOutCubic }
                    }
                }

                /* ==== Mode 2: timer ==== */
                TimerPane {
                    width: parent.width
                    height: parent.height
                    x: root.paneX(2)
                    opacity: root.mode === 2 ? 1 : 0
                    enabled: root.mode === 2
                    transform: Translate {
                        y: root.open ? 0 : 12
                        Behavior on y { NumberAnimation { duration: root.open ? 300 : 120; easing.type: Easing.OutExpo } }
                    }
                    Behavior on x {
                        NumberAnimation { duration: 220; easing.type: Easing.OutCubic }
                    }
                    Behavior on opacity {
                        NumberAnimation { duration: 150; easing.type: Easing.InOutCubic }
                    }
                }
            }
        }

        /* Detail popups for the Wi-Fi / Bluetooth tiles, layered over the
         * mode content (kept out of the pane's clip so they can extend it). */
        WifiPopup {
            id: wifiPopup
            anchors.horizontalCenter: card.horizontalCenter
            anchors.top: card.top
            anchors.topMargin: 46
            open: root.wifiPopupOpen
            powerOn: root.wifiOn
            wifiName: root.wifiName
            onPowerToggled: root.toggleWifi()
            onRequestedClose: root.wifiPopupOpen = false
        }

        BtPopup {
            id: btPopup
            anchors.horizontalCenter: card.horizontalCenter
            anchors.top: card.top
            anchors.topMargin: 46
            open: root.btPopupOpen
            powerOn: root.btOn
            btName: root.btName
            onPowerToggled: root.toggleBt()
            onRequestedClose: root.btPopupOpen = false
        }
    }
}