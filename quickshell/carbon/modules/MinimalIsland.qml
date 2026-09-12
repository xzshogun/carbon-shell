import QtQuick
import QtQuick.Layouts
import QtQuick.Shapes
import Quickshell
import Quickshell.Io
import Quickshell.Hyprland
import Quickshell.Services.Mpris
import Quickshell.Services.Pipewire
import Quickshell.Services.UPower
import M3Shapes
import "../Singletons"

/**
 * MinimalIsland: Ultra-lightweight Dynamic Island single-bar capsule.
 * Designed for absolute minimum CPU, GPU, and RAM consumption.
 *
 * Page Architecture:
 *   Page 0 (Default): Minimal Workspaces & Clock ONLY (no sound, battery, or media).
 *   Page 1 (Swipe Right): Sound, Battery, and Notifications.
 *   Page 2 (Swipe Right again): Media Player controls and track info.
 *
 * Silky Smooth Physics:
 *   - Pure Easing.OutCubic curves (zero jitter, zero shaking, zero overshoot bounce).
 *   - Direct drag tracking without animation fighting.
 *   - Clean horizontal cross-slide transitions.
 */
Item {
    id: root

    implicitHeight: 34
    implicitWidth: capsule.width
    width: capsule.width
    height: 34

    property bool attachedBottom: false
    property string islandStyle: "pill" // "pill" or "notch"
    property int notifCount: 0
    property int currentPage: 0 // 0: Time & Workspace, 1: Sound/Battery/Notif, 2: Media

    function getShapeForWs(wsId) {
        switch (wsId) {
            case 1: return MaterialShape.Clover4Leaf
            case 2: return MaterialShape.Sunny
            case 3: return MaterialShape.Flower
            case 4: return MaterialShape.Heart
            case 5: return MaterialShape.Gem
            case 6: return MaterialShape.Diamond
            case 7: return MaterialShape.Cookie4Sided
            case 8: return MaterialShape.SoftBurst
            case 9: return MaterialShape.Boom
            case 10: return MaterialShape.Ghostish
            default: {
                const extraShapes = [
                    MaterialShape.Slanted,
                    MaterialShape.Pentagon,
                    MaterialShape.ClamShell,
                    MaterialShape.PuffyDiamond,
                    MaterialShape.Arch
                ]
                return extraShapes[Math.abs(wsId - 11) % extraShapes.length]
            }
        }
    }

    signal openLauncher()
    signal toggleControls()
    signal openNotif()
    signal closeNotif()
    signal toggleNotif()
    signal openMixer()
    signal closeMixer()
    signal toggleMixer()
    signal openBrightness()
    signal closeBrightness()
    signal toggleBrightness()
    signal openBattery()
    signal closeBattery()
    signal toggleBattery()
    signal openWifi()
    signal closeWifi()
    signal toggleWifi()
    signal openBt()
    signal closeBt()
    signal toggleBt()
    signal openCalendar()
    signal closeCalendar()
    signal toggleCalendar()
    signal openSmallMusic()
    signal closeSmallMusic()
    signal toggleSmallMusic()
    signal convertToPill()
    signal convertToNotch()
    signal switchIslandStyle(string style)

    /* ── Night Light Integration ── */
    property bool nightLightOn: false

    Process {
        id: nightLightStatusProc
        command: ["/home/shogun/.config/hypr/scripts/carbon-night.sh", "status"]
        stdout: SplitParser {
            onRead: line => {
                root.nightLightOn = (line.trim() === "on")
            }
        }
    }

    Timer {
        interval: 2500
        repeat: true
        running: true
        onTriggered: {
            if (!nightLightStatusProc.running) nightLightStatusProc.running = true
        }
    }

    function toggleNightLight() {
        Quickshell.execDetached(["/home/shogun/.config/hypr/scripts/carbon-night.sh", "toggle"])
        root.nightLightOn = !root.nightLightOn
        nightLightCheckTimer.restart()
    }

    Timer {
        id: nightLightCheckTimer
        interval: 350
        onTriggered: {
            if (!nightLightStatusProc.running) nightLightStatusProc.running = true
        }
    }

    /* ── Coordinated Hover & Pop-up Timing (Prevents Overlaps) ── */
    property string pendingPopup: ""
    property string activePopup: ""

    Timer {
        id: popupHoverTimer
        interval: 160
        repeat: false
        onTriggered: {
            if (root.pendingPopup !== "") {
                root.activePopup = root.pendingPopup
                if (root.pendingPopup === "mixer") root.openMixer()
                else if (root.pendingPopup === "brightness") root.openBrightness()
                else if (root.pendingPopup === "battery") root.openBattery()
                else if (root.pendingPopup === "wifi") root.openWifi()
                else if (root.pendingPopup === "bt") root.openBt()
                else if (root.pendingPopup === "notif") root.openNotif()
                else if (root.pendingPopup === "calendar") root.openCalendar()
                else if (root.pendingPopup === "smallMusic") root.openSmallMusic()
            }
        }
    }

    function requestHoverPopup(name) {
        if (root.activePopup === name) return
        root.pendingPopup = name
        popupHoverTimer.restart()
    }

    function cancelHoverPopup(name) {
        if (root.pendingPopup === name) {
            popupHoverTimer.stop()
            root.pendingPopup = ""
        }
        if (root.activePopup === name) {
            if (name === "mixer") root.closeMixer()
            else if (name === "brightness") root.closeBrightness()
            else if (name === "battery") root.closeBattery()
            else if (name === "wifi") root.closeWifi()
            else if (name === "bt") root.closeBt()
            else if (name === "notif") root.closeNotif()
            else if (name === "calendar") root.closeCalendar()
            else if (name === "smallMusic") root.closeSmallMusic()
            root.activePopup = ""
        }
    }

    function clickPopup(name) {
        popupHoverTimer.stop()
        root.pendingPopup = ""
        root.activePopup = ""
        if (name === "mixer") root.toggleMixer()
        else if (name === "brightness") root.toggleBrightness()
        else if (name === "battery") root.toggleBattery()
        else if (name === "wifi") root.toggleWifi()
        else if (name === "bt") root.toggleBt()
        else if (name === "notif") root.toggleNotif()
        else if (name === "calendar") root.toggleCalendar()
        else if (name === "smallMusic") root.toggleSmallMusic()
    }

    function nextPage() {
        root.currentPage = (root.currentPage + 1) % 3
    }

    function prevPage() {
        root.currentPage = (root.currentPage - 1 + 3) % 3
    }

    function handleWheel(wheel) {
        if (!wheel) return
        if (wheel.angleDelta.y < 0) {
            root.nextPage()
        } else if (wheel.angleDelta.y > 0) {
            root.prevPage()
        }
    }

    /* ── Notch Geometry Fillets ── */
    property real filletRadius: 14
    property real bottomRadius: 14

    readonly property string notchFillPath: {
        const rTopLeft = root.filletRadius
        const rTopRight = root.filletRadius
        const rBotLeft = root.bottomRadius
        const rBotRight = root.bottomRadius
        const w = capsule.width
        const h = 34

        if (root.attachedBottom) {
            let p = `M 0 ${h} `
            p += `A ${rTopLeft} ${rTopLeft} 0 0 0 ${rTopLeft} ${h - rTopLeft} `
            p += `L ${rTopLeft} ${rBotLeft} `
            p += `A ${rBotLeft} ${rBotLeft} 0 0 1 ${rTopLeft + rBotLeft} 0 `

            const rightWallX = w - rTopRight
            p += `L ${rightWallX - rBotRight} 0 `
            p += `A ${rBotRight} ${rBotRight} 0 0 1 ${rightWallX} ${rBotRight} `
            p += `L ${rightWallX} ${h - rTopRight} `
            p += `A ${rTopRight} ${rTopRight} 0 0 0 ${w} ${h} `
            p += `L 0 ${h} Z`
            return p
        }

        let p = "M 0 0 "
        p += `A ${rTopLeft} ${rTopLeft} 0 0 1 ${rTopLeft} ${rTopLeft} `
        p += `L ${rTopLeft} ${h - rBotLeft} `
        p += `A ${rBotLeft} ${rBotLeft} 0 0 0 ${rTopLeft + rBotLeft} ${h} `

        const rightWallX = w - rTopRight
        p += `L ${rightWallX - rBotRight} ${h} `
        p += `A ${rBotRight} ${rBotRight} 0 0 0 ${rightWallX} ${h - rBotRight} `
        p += `L ${rightWallX} ${rTopRight} `
        p += `A ${rTopRight} ${rTopRight} 0 0 1 ${w} 0 `
        p += `L 0 0 Z`
        return p
    }

    readonly property string notchStrokePath: {
        const rTopLeft = root.filletRadius
        const rTopRight = root.filletRadius
        const rBotLeft = root.bottomRadius
        const rBotRight = root.bottomRadius
        const w = capsule.width
        const h = 34

        if (root.attachedBottom) {
            let p = `M 0 ${h} `
            p += `A ${rTopLeft} ${rTopLeft} 0 0 0 ${rTopLeft} ${h - rTopLeft} `
            p += `L ${rTopLeft} ${rBotLeft} `
            p += `A ${rBotLeft} ${rBotLeft} 0 0 1 ${rTopLeft + rBotLeft} 0 `

            const rightWallX = w - rTopRight
            p += `L ${rightWallX - rBotRight} 0 `
            p += `A ${rBotRight} ${rBotRight} 0 0 1 ${rightWallX} ${rBotRight} `
            p += `L ${rightWallX} ${h - rTopRight} `
            p += `A ${rTopRight} ${rTopRight} 0 0 0 ${w} ${h}`
            return p
        }

        let p = "M 0 0 "
        p += `A ${rTopLeft} ${rTopLeft} 0 0 1 ${rTopLeft} ${rTopLeft} `
        p += `L ${rTopLeft} ${h - rBotLeft} `
        p += `A ${rBotLeft} ${rBotLeft} 0 0 0 ${rTopLeft + rBotLeft} ${h} `

        const rightWallX = w - rTopRight
        p += `L ${rightWallX - rBotRight} ${h} `
        p += `A ${rBotRight} ${rBotRight} 0 0 0 ${rightWallX} ${h - rBotRight} `
        p += `L ${rightWallX} ${rTopRight} `
        p += `A ${rTopRight} ${rTopRight} 0 0 1 ${w} 0`
        return p
    }

    /* ── Live Clock (Minute updates, zero idle waste) ── */
    property var currentTime: new Date()
    property int currentHourRaw: currentTime.getHours()
    property int currentHour12: {
        let h = currentHourRaw % 12
        return h === 0 ? 12 : h
    }
    property string hourStr: (currentHour12 < 10 ? "0" : "") + currentHour12
    property string minStr: {
        let m = currentTime.getMinutes()
        return (m < 10 ? "0" : "") + m
    }

    /* ── Clock Style Watcher ── */
    FileView {
        id: clockStyleFile
        path: "/home/shogun/.config/hypr/carbon-clock-style.json"
        watchChanges: true
        onFileChanged: root.reloadClockStyle()
        onLoaded: root.reloadClockStyle()
    }

    property string clockStyle: "titan"

    function reloadClockStyle() {
        try {
            const txt = clockStyleFile.text().trim()
            if (txt.length > 0) {
                const d = JSON.parse(txt)
                if (d.style) root.clockStyle = d.style
            }
        } catch (e) {}
    }

    Timer {
        interval: 1000
        repeat: true
        running: true
        onTriggered: root.currentTime = new Date()
    }

    /* ── Workspaces (Hyprland Event Driven) ── */
    property int activeWs: (Hyprland.focusedMonitor && Hyprland.focusedMonitor.activeWorkspace) ? Hyprland.focusedMonitor.activeWorkspace.id : 1
    Connections {
        target: Hyprland.focusedMonitor
        function onActiveWorkspaceChanged() {
            if (Hyprland.focusedMonitor && Hyprland.focusedMonitor.activeWorkspace) {
                root.activeWs = Hyprland.focusedMonitor.activeWorkspace.id
            }
        }
    }
    Connections {
        target: Hyprland
        function onRawEvent(event) {
            if (event.name === "workspace" || event.name === "workspacev2") {
                const id = parseInt(event.data, 10)
                if (!isNaN(id) && id > 0) root.activeWs = id
            }
        }
    }

    /* ── MPRIS State (Synchronized via LyricsService Singleton) ── */
    readonly property var activePlayer: LyricsService.activePlayer
    readonly property bool isPlaying: LyricsService.isPlaying
    readonly property string trackTitle: LyricsService.trackTitle
    readonly property string trackArtist: LyricsService.trackArtist
    readonly property bool hasTrack: LyricsService.hasTrack

    /* ── Mini Cava Visualizer State ── */
    property var cavaBars: [4, 8, 12, 6]
    property real cavaAnimTick: 0

    Process {
        id: cavaProc
        command: ["cava", "-p", "/home/shogun/.config/hypr/cava-island.conf"]
        running: root.currentPage === 2 && root.isPlaying
        stdout: SplitParser {
            splitMarker: "\n"
            onRead: line => {
                const parts = line.trim().split(";")
                if (parts.length >= 4) {
                    const b0 = Math.max(3, Math.min(14, Math.round((parseInt(parts[0]) || 0) * 0.14)))
                    const b1 = Math.max(3, Math.min(14, Math.round((parseInt(parts[1]) || 0) * 0.14)))
                    const b2 = Math.max(3, Math.min(14, Math.round((parseInt(parts[2]) || 0) * 0.14)))
                    const b3 = Math.max(3, Math.min(14, Math.round((parseInt(parts[3]) || 0) * 0.14)))
                    root.cavaBars = [b0, b1, b2, b3]
                }
            }
        }
    }

    Timer {
        interval: 100
        repeat: true
        running: root.currentPage === 2 && root.isPlaying && (!cavaProc.running)
        onTriggered: {
            root.cavaAnimTick += 0.4
            const b0 = 3 + Math.round(Math.abs(Math.sin(root.cavaAnimTick)) * 8)
            const b1 = 3 + Math.round(Math.abs(Math.cos(root.cavaAnimTick * 1.3)) * 10)
            const b2 = 3 + Math.round(Math.abs(Math.sin(root.cavaAnimTick * 0.8 + 1)) * 9)
            const b3 = 3 + Math.round(Math.abs(Math.cos(root.cavaAnimTick * 1.1 + 0.5)) * 7)
            root.cavaBars = [b0, b1, b2, b3]
        }
    }

    /* ── Audio State (PipeWire Direct) ── */
    readonly property var audioSink: Pipewire.defaultAudioSink
    readonly property real volume: audioSink && audioSink.audio ? audioSink.audio.volume : 0.0
    readonly property bool muted: audioSink && audioSink.audio ? audioSink.audio.muted : false
    readonly property string volumeGlyph: {
        if (muted) return "\uf6a9"
        if (volume > 0.5) return "\uf028"
        if (volume > 0.0) return "\uf027"
        return "\uf026"
    }

    /* ── Battery State (UPower Direct) ── */
    readonly property var battery: UPower.displayDevice
    readonly property bool hasBattery: battery ? battery.isPresent : false
    readonly property real batteryPct: battery ? battery.percentage : 1.0
    readonly property bool isCharging: battery ? (battery.state === UPowerDeviceState.Charging || battery.state === UPowerDeviceState.FullyCharged) : false
    readonly property string batteryGlyph: {
        if (isCharging) return "\uf0e7"
        const p = batteryPct * 100
        if (p > 85) return "\uf240"
        if (p > 60) return "\uf241"
        if (p > 35) return "\uf242"
        if (p > 10) return "\uf243"
        return "\uf244"
    }

    /* ── Dynamic Container ── */
    Item {
        id: capsule
        height: 34
        anchors.centerIn: parent

        property bool musicHovered: false

        readonly property int baseWidth: {
            if (root.currentPage === 0) return 178 // Minimal: Workspace + Time + Calendar
            if (root.currentPage === 1) return 278 // Sound, Brightness, Battery, Wifi, Bluetooth, Night Light, Notif
            if (root.currentPage === 2) {
                if (capsule.musicHovered) {
                    return (LyricsService.hasLyrics ? 320 : (root.hasTrack ? 250 : 178))
                }
                return root.hasTrack ? 220 : 160
            }
            return root.hasTrack ? 220 : 160
        }

        width: root.islandStyle === "notch" ? (baseWidth + Math.round(root.filletRadius * 2)) : baseWidth

        /* Ultra-smooth cubic expansion / contraction (zero jitter, zero shaking) */
        Behavior on width {
            NumberAnimation {
                duration: 260
                easing.type: Easing.OutCubic
            }
        }

        /* ── 1A. Pill Mode Background (Floating Rounded Capsule) ── */
        Rectangle {
            id: pillBg
            anchors.fill: parent
            visible: root.islandStyle !== "notch"
            radius: 17
            color: Qt.rgba(0.08, 0.09, 0.12, 0.94)
            border.color: Qt.rgba(Theme.outline.r, Theme.outline.g, Theme.outline.b, 0.32)
            border.width: 1
        }

        /* ── 1B. Notch Mode Background (Screen-Attached Curved Notch) ── */
        Shape {
            id: notchShape
            anchors.fill: parent
            visible: root.islandStyle === "notch"
            preferredRendererType: Shape.CurveRenderer
            asynchronous: false
            layer.enabled: true
            layer.smooth: true

            ShapePath {
                strokeWidth: 0
                strokeColor: "transparent"
                fillColor: Qt.rgba(0.08, 0.09, 0.12, 0.96)
                PathSvg { path: root.notchFillPath }
            }

            ShapePath {
                strokeWidth: 1
                strokeColor: Qt.rgba(Theme.outline.r, Theme.outline.g, Theme.outline.b, 0.4)
                fillColor: "transparent"
                capStyle: ShapePath.RoundCap
                joinStyle: ShapePath.RoundJoin
                PathSvg { path: root.notchStrokePath }
            }
        }

        /* ── Scroll Gesture Area (Wheel Up/Down to cycle islands) ── */
        MouseArea {
            id: swipeGestureArea
            anchors.fill: parent
            hoverEnabled: true
            z: 1

            onWheel: wheel => root.handleWheel(wheel)
        }

        /* ── Content Container (Clean Silky Slide Transitions) ── */
        Item {
            id: contentContainer
            anchors.fill: parent
            anchors.leftMargin: root.islandStyle === "notch" ? root.filletRadius : 0
            anchors.rightMargin: root.islandStyle === "notch" ? root.filletRadius : 0
            clip: true
            z: 2

            /* ══════════════════════════════════════════════════════════════
             * PAGE 0: MINIMAL WORKSPACES & TIME ONLY
             * ══════════════════════════════════════════════════════════════ */
            Item {
                id: page0
                anchors.fill: parent
                visible: opacity > 0.001

                opacity: root.currentPage === 0 ? 1.0 : 0.0
                x: (0 - root.currentPage) * 24

                Behavior on opacity {
                    NumberAnimation { duration: 200; easing.type: Easing.OutCubic }
                }
                Behavior on x {
                    NumberAnimation { duration: 240; easing.type: Easing.OutCubic }
                }

                Row {
                    anchors.centerIn: parent
                    spacing: 12

                    /* Active Workspace Morphing Badge */
                    Item {
                        id: wsBtn
                        width: 24
                        height: 24
                        anchors.verticalCenter: parent.verticalCenter
                        scale: wsArea.pressed ? 0.92 : (wsArea.containsMouse ? 1.15 : 1.0)
                        Behavior on scale { NumberAnimation { duration: 180; easing.type: Easing.OutBack; easing.overshoot: 1.3 } }

                        MaterialShape {
                            id: wsShape
                            anchors.fill: parent
                            shape: root.getShapeForWs(root.activeWs)
                            animationDuration: 280
                            animationEasing: Easing.OutBack
                            color: wsArea.containsMouse ? Theme.accentLit : Theme.accent
                            Behavior on color { ColorAnimation { duration: 150 } }
                        }

                        Text {
                            anchors.centerIn: parent
                            text: String(root.activeWs)
                            font.pixelSize: 11
                            font.bold: true
                            font.family: "Valley Sans"
                            color: Theme.isDark ? "#111111" : "#ffffff"
                        }

                        MouseArea {
                            id: wsArea
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            z: 5
                            onClicked: root.openLauncher()
                            onWheel: wheel => root.handleWheel(wheel)
                        }
                    }

                    /* Live Clock (Titan 3D Pop) */
                    Row {
                        spacing: root.clockStyle === "titan" ? 1 : 2
                        anchors.verticalCenter: parent.verticalCenter

                        Text {
                            text: root.hourStr
                            font.pixelSize: root.clockStyle === "titan" ? 14 : 12
                            font.weight: root.clockStyle === "titan" ? Font.Black : Font.Bold
                            font.family: root.clockStyle === "titan" ? "Titan One" : "JetBrains Mono"
                            color: Theme.fg
                            style: root.clockStyle === "titan" ? Text.Raised : Text.Normal
                            styleColor: root.clockStyle === "titan" ? "#55000000" : "transparent"
                            anchors.verticalCenter: parent.verticalCenter
                        }

                        Text {
                            text: ":"
                            font.pixelSize: root.clockStyle === "titan" ? 14 : 12
                            font.weight: root.clockStyle === "titan" ? Font.Black : Font.Bold
                            font.family: root.clockStyle === "titan" ? "Titan One" : "JetBrains Mono"
                            color: Theme.accent
                            style: root.clockStyle === "titan" ? Text.Raised : Text.Normal
                            styleColor: root.clockStyle === "titan" ? "#55000000" : "transparent"
                            anchors.verticalCenter: parent.verticalCenter
                        }

                        Text {
                            text: root.minStr
                            font.pixelSize: root.clockStyle === "titan" ? 14 : 12
                            font.weight: root.clockStyle === "titan" ? Font.Black : Font.Bold
                            font.family: root.clockStyle === "titan" ? "Titan One" : "JetBrains Mono"
                            color: root.clockStyle === "titan" ? Theme.accent : Theme.fg
                            style: root.clockStyle === "titan" ? Text.Raised : Text.Normal
                            styleColor: root.clockStyle === "titan" ? "#55000000" : "transparent"
                            anchors.verticalCenter: parent.verticalCenter
                        }
                    }

                    /* Small Calendar Icon */
                    Item {
                        id: calBtn
                        width: 22
                        height: 22
                        anchors.verticalCenter: parent.verticalCenter
                        scale: calArea.pressed ? 0.92 : (calArea.containsMouse ? 1.08 : 1.0)
                        Behavior on scale { NumberAnimation { duration: 120 } }

                        // Ambient halo
                        MaterialShape {
                            anchors.centerIn: parent
                            width: parent.width + 4
                            height: parent.height + 4
                            shape: MaterialShape.Cookie4Sided
                            color: Qt.rgba(Theme.accent.r, Theme.accent.g, Theme.accent.b, 0.22)
                            scale: calArea.containsMouse ? 1.12 : 0.6
                            opacity: calArea.containsMouse ? 1.0 : 0.0
                            rotation: calArea.containsMouse ? 8 : 0
                            Behavior on opacity { NumberAnimation { duration: 180 } }
                            Behavior on scale { NumberAnimation { duration: 240; easing.type: Easing.OutBack } }
                            Behavior on rotation { NumberAnimation { duration: 260; easing.type: Easing.OutBack } }
                        }

                        // Tactile highlight chip
                        MaterialShape {
                            anchors.fill: parent
                            shape: calArea.containsMouse ? MaterialShape.Cookie4Sided : MaterialShape.Circle
                            animationDuration: 240
                            animationEasing: Easing.OutBack
                            color: calArea.containsMouse ? Qt.rgba(1, 1, 1, 0.14) : "transparent"
                            strokeColor: calArea.containsMouse ? Qt.rgba(Theme.accent.r, Theme.accent.g, Theme.accent.b, 0.40) : "transparent"
                            strokeWidth: 1.0
                            rotation: calArea.containsMouse ? 8 : 0
                            Behavior on color { ColorAnimation { duration: 120 } }
                            Behavior on strokeColor { ColorAnimation { duration: 120 } }
                            Behavior on rotation { NumberAnimation { duration: 240; easing.type: Easing.OutBack } }
                        }

                        Text {
                            anchors.centerIn: parent
                            text: "\uf073"
                            font.family: Theme.font
                            font.pixelSize: 11
                            color: calArea.containsMouse ? Theme.accent : Qt.rgba(Theme.fg.r, Theme.fg.g, Theme.fg.b, 0.7)
                        }

                        MouseArea {
                            id: calArea
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            z: 5
                            onEntered: root.requestHoverPopup("calendar")
                            onExited: root.cancelHoverPopup("calendar")
                            onClicked: root.clickPopup("calendar")
                            onWheel: wheel => root.handleWheel(wheel)
                        }
                    }
                }
            }

            /* ══════════════════════════════════════════════════════════════
             * PAGE 1: SOUND, BATTERY, AND NOTIFICATION
             * ══════════════════════════════════════════════════════════════ */
            Item {
                id: page1
                anchors.fill: parent
                visible: opacity > 0.001

                opacity: root.currentPage === 1 ? 1.0 : 0.0
                x: (1 - root.currentPage) * 24

                Behavior on opacity {
                    NumberAnimation { duration: 200; easing.type: Easing.OutCubic }
                }
                Behavior on x {
                    NumberAnimation { duration: 240; easing.type: Easing.OutCubic }
                }

                Row {
                    anchors.centerIn: parent
                    spacing: 10

                    /* ── 1. Sound / Volume Icon ── */
                    Item {
                        id: volPill
                        width: 24
                        height: 24
                        anchors.verticalCenter: parent.verticalCenter
                        scale: volArea.pressed ? 0.92 : (volArea.containsMouse ? 1.08 : 1.0)
                        Behavior on scale { NumberAnimation { duration: 120 } }

                        // Ambient blooming shape halo
                        MaterialShape {
                            anchors.centerIn: parent
                            width: parent.width + 4
                            height: parent.height + 4
                            shape: MaterialShape.Flower
                            color: Qt.rgba(Theme.accent.r, Theme.accent.g, Theme.accent.b, 0.22)
                            scale: volArea.containsMouse ? 1.12 : 0.6
                            opacity: volArea.containsMouse ? 1.0 : 0.0
                            rotation: volArea.containsMouse ? -8 : 0
                            Behavior on opacity { NumberAnimation { duration: 180 } }
                            Behavior on scale { NumberAnimation { duration: 240; easing.type: Easing.OutBack } }
                            Behavior on rotation { NumberAnimation { duration: 260; easing.type: Easing.OutBack } }
                        }

                        // Tactile highlight chip
                        MaterialShape {
                            anchors.fill: parent
                            shape: volArea.containsMouse ? MaterialShape.Flower : MaterialShape.Circle
                            animationDuration: 240
                            animationEasing: Easing.OutBack
                            color: volArea.containsMouse ? Qt.rgba(1, 1, 1, 0.14) : "transparent"
                            strokeColor: volArea.containsMouse ? Qt.rgba(Theme.accent.r, Theme.accent.g, Theme.accent.b, 0.40) : "transparent"
                            strokeWidth: 1.0
                            rotation: volArea.containsMouse ? -8 : 0
                            Behavior on color { ColorAnimation { duration: 120 } }
                            Behavior on strokeColor { ColorAnimation { duration: 120 } }
                            Behavior on rotation { NumberAnimation { duration: 240; easing.type: Easing.OutBack } }
                        }

                        Text {
                            anchors.centerIn: parent
                            text: root.volumeGlyph
                            font.family: Theme.font
                            font.pixelSize: 12
                            color: root.muted ? Theme.err : (volArea.containsMouse ? Theme.accent : Theme.fg)
                        }

                        MouseArea {
                            id: volArea
                            anchors.fill: parent
                            hoverEnabled: true
                            acceptedButtons: Qt.LeftButton | Qt.RightButton
                            cursorShape: Qt.PointingHandCursor
                            z: 5
                            onEntered: root.requestHoverPopup("mixer")
                            onExited: root.cancelHoverPopup("mixer")
                            onClicked: mouse => {
                                if (mouse.button === Qt.RightButton) {
                                    if (root.audioSink && root.audioSink.audio)
                                        root.audioSink.audio.muted = !root.audioSink.audio.muted
                                } else {
                                    root.clickPopup("mixer")
                                }
                            }
                            onWheel: wheel => {
                                if (root.audioSink && root.audioSink.audio) {
                                    const step = 0.05
                                    if (wheel.angleDelta.y > 0)
                                        root.audioSink.audio.volume = Math.min(1.0, root.audioSink.audio.volume + step)
                                    else
                                        root.audioSink.audio.volume = Math.max(0.0, root.audioSink.audio.volume - step)
                                }
                            }
                        }
                    }

                    /* ── 2. Brightness Icon ── */
                    Item {
                        id: brightPill
                        width: 24
                        height: 24
                        anchors.verticalCenter: parent.verticalCenter
                        scale: brightArea.pressed ? 0.92 : (brightArea.containsMouse ? 1.08 : 1.0)
                        Behavior on scale { NumberAnimation { duration: 120 } }

                        // Ambient blooming shape halo
                        MaterialShape {
                            anchors.centerIn: parent
                            width: parent.width + 4
                            height: parent.height + 4
                            shape: MaterialShape.Sunny
                            color: Qt.rgba(Theme.accent.r, Theme.accent.g, Theme.accent.b, 0.22)
                            scale: brightArea.containsMouse ? 1.12 : 0.6
                            opacity: brightArea.containsMouse ? 1.0 : 0.0
                            rotation: brightArea.containsMouse ? 15 : 0
                            Behavior on opacity { NumberAnimation { duration: 180 } }
                            Behavior on scale { NumberAnimation { duration: 240; easing.type: Easing.OutBack } }
                            Behavior on rotation { NumberAnimation { duration: 260; easing.type: Easing.OutBack } }
                        }

                        // Tactile highlight chip
                        MaterialShape {
                            anchors.fill: parent
                            shape: brightArea.containsMouse ? MaterialShape.Sunny : MaterialShape.Circle
                            animationDuration: 240
                            animationEasing: Easing.OutBack
                            color: brightArea.containsMouse ? Qt.rgba(1, 1, 1, 0.14) : "transparent"
                            strokeColor: brightArea.containsMouse ? Qt.rgba(Theme.accent.r, Theme.accent.g, Theme.accent.b, 0.40) : "transparent"
                            strokeWidth: 1.0
                            rotation: brightArea.containsMouse ? 15 : 0
                            Behavior on color { ColorAnimation { duration: 120 } }
                            Behavior on strokeColor { ColorAnimation { duration: 120 } }
                            Behavior on rotation { NumberAnimation { duration: 240; easing.type: Easing.OutBack } }
                        }

                        Text {
                            anchors.centerIn: parent
                            text: "\uf185"
                            font.family: Theme.font
                            font.pixelSize: 12
                            color: brightArea.containsMouse ? Theme.accentLit : Theme.fg
                        }

                        MouseArea {
                            id: brightArea
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            z: 5
                            onEntered: root.requestHoverPopup("brightness")
                            onExited: root.cancelHoverPopup("brightness")
                            onClicked: root.clickPopup("brightness")
                            onWheel: wheel => root.handleWheel(wheel)
                        }
                    }

                    /* ── 3. Battery Icon ── */
                    Item {
                        id: batPill
                        width: 24
                        height: 24
                        anchors.verticalCenter: parent.verticalCenter
                        scale: batArea.pressed ? 0.92 : (batArea.containsMouse ? 1.08 : 1.0)
                        Behavior on scale { NumberAnimation { duration: 120 } }

                        // Ambient blooming shape halo
                        MaterialShape {
                            anchors.centerIn: parent
                            width: parent.width + 4
                            height: parent.height + 4
                            shape: MaterialShape.Gem
                            color: Qt.rgba(Theme.accent.r, Theme.accent.g, Theme.accent.b, 0.22)
                            scale: batArea.containsMouse ? 1.12 : 0.6
                            opacity: batArea.containsMouse ? 1.0 : 0.0
                            rotation: batArea.containsMouse ? 10 : 0
                            Behavior on opacity { NumberAnimation { duration: 180 } }
                            Behavior on scale { NumberAnimation { duration: 240; easing.type: Easing.OutBack } }
                            Behavior on rotation { NumberAnimation { duration: 260; easing.type: Easing.OutBack } }
                        }

                        // Tactile highlight chip
                        MaterialShape {
                            anchors.fill: parent
                            shape: batArea.containsMouse ? MaterialShape.Gem : MaterialShape.Circle
                            animationDuration: 240
                            animationEasing: Easing.OutBack
                            color: batArea.containsMouse ? Qt.rgba(1, 1, 1, 0.14) : "transparent"
                            strokeColor: batArea.containsMouse ? Qt.rgba(Theme.accent.r, Theme.accent.g, Theme.accent.b, 0.40) : "transparent"
                            strokeWidth: 1.0
                            rotation: batArea.containsMouse ? 10 : 0
                            Behavior on color { ColorAnimation { duration: 120 } }
                            Behavior on strokeColor { ColorAnimation { duration: 120 } }
                            Behavior on rotation { NumberAnimation { duration: 240; easing.type: Easing.OutBack } }
                        }

                        Text {
                            anchors.centerIn: parent
                            text: root.batteryGlyph
                            font.family: Theme.font
                            font.pixelSize: 12
                            color: root.isCharging ? Theme.accentLit : (root.batteryPct < 0.2 ? Theme.err : (batArea.containsMouse ? Theme.accent : Theme.fg))
                        }

                        MouseArea {
                            id: batArea
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            z: 5
                            onEntered: root.requestHoverPopup("battery")
                            onExited: root.cancelHoverPopup("battery")
                            onClicked: root.clickPopup("battery")
                            onWheel: wheel => root.handleWheel(wheel)
                        }
                    }

                    /* ── 4. Wi-Fi Icon ── */
                    Item {
                        id: wifiPill
                        width: 24
                        height: 24
                        anchors.verticalCenter: parent.verticalCenter
                        scale: wifiArea.pressed ? 0.92 : (wifiArea.containsMouse ? 1.08 : 1.0)
                        Behavior on scale { NumberAnimation { duration: 120 } }

                        // Ambient blooming shape halo
                        MaterialShape {
                            anchors.centerIn: parent
                            width: parent.width + 4
                            height: parent.height + 4
                            shape: MaterialShape.SoftBurst
                            color: Qt.rgba(Theme.accent.r, Theme.accent.g, Theme.accent.b, 0.22)
                            scale: wifiArea.containsMouse ? 1.12 : 0.6
                            opacity: wifiArea.containsMouse ? 1.0 : 0.0
                            rotation: wifiArea.containsMouse ? -10 : 0
                            Behavior on opacity { NumberAnimation { duration: 180 } }
                            Behavior on scale { NumberAnimation { duration: 240; easing.type: Easing.OutBack } }
                            Behavior on rotation { NumberAnimation { duration: 260; easing.type: Easing.OutBack } }
                        }

                        // Tactile highlight chip
                        MaterialShape {
                            anchors.fill: parent
                            shape: wifiArea.containsMouse ? MaterialShape.SoftBurst : MaterialShape.Circle
                            animationDuration: 240
                            animationEasing: Easing.OutBack
                            color: wifiArea.containsMouse ? Qt.rgba(1, 1, 1, 0.14) : "transparent"
                            strokeColor: wifiArea.containsMouse ? Qt.rgba(Theme.accent.r, Theme.accent.g, Theme.accent.b, 0.40) : "transparent"
                            strokeWidth: 1.0
                            rotation: wifiArea.containsMouse ? -10 : 0
                            Behavior on color { ColorAnimation { duration: 120 } }
                            Behavior on strokeColor { ColorAnimation { duration: 120 } }
                            Behavior on rotation { NumberAnimation { duration: 240; easing.type: Easing.OutBack } }
                        }

                        Text {
                            anchors.centerIn: parent
                            text: "\uf1eb"
                            font.family: Theme.font
                            font.pixelSize: 12
                            color: wifiArea.containsMouse ? Theme.accent : Theme.fg
                        }

                        MouseArea {
                            id: wifiArea
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            z: 5
                            onEntered: root.requestHoverPopup("wifi")
                            onExited: root.cancelHoverPopup("wifi")
                            onClicked: root.clickPopup("wifi")
                            onWheel: wheel => root.handleWheel(wheel)
                        }
                    }

                    /* ── 5. Bluetooth Icon ── */
                    Item {
                        id: btPill
                        width: 24
                        height: 24
                        anchors.verticalCenter: parent.verticalCenter
                        scale: btArea.pressed ? 0.92 : (btArea.containsMouse ? 1.08 : 1.0)
                        Behavior on scale { NumberAnimation { duration: 120 } }

                        // Ambient blooming shape halo
                        MaterialShape {
                            anchors.centerIn: parent
                            width: parent.width + 4
                            height: parent.height + 4
                            shape: MaterialShape.Slanted
                            color: Qt.rgba(Theme.accent.r, Theme.accent.g, Theme.accent.b, 0.22)
                            scale: btArea.containsMouse ? 1.12 : 0.6
                            opacity: btArea.containsMouse ? 1.0 : 0.0
                            rotation: btArea.containsMouse ? 8 : 0
                            Behavior on opacity { NumberAnimation { duration: 180 } }
                            Behavior on scale { NumberAnimation { duration: 240; easing.type: Easing.OutBack } }
                            Behavior on rotation { NumberAnimation { duration: 260; easing.type: Easing.OutBack } }
                        }

                        // Tactile highlight chip
                        MaterialShape {
                            anchors.fill: parent
                            shape: btArea.containsMouse ? MaterialShape.Slanted : MaterialShape.Circle
                            animationDuration: 240
                            animationEasing: Easing.OutBack
                            color: btArea.containsMouse ? Qt.rgba(1, 1, 1, 0.14) : "transparent"
                            strokeColor: btArea.containsMouse ? Qt.rgba(Theme.accent.r, Theme.accent.g, Theme.accent.b, 0.40) : "transparent"
                            strokeWidth: 1.0
                            rotation: btArea.containsMouse ? 8 : 0
                            Behavior on color { ColorAnimation { duration: 120 } }
                            Behavior on strokeColor { ColorAnimation { duration: 120 } }
                            Behavior on rotation { NumberAnimation { duration: 240; easing.type: Easing.OutBack } }
                        }

                        Text {
                            anchors.centerIn: parent
                            text: "\uf294"
                            font.family: Theme.font
                            font.pixelSize: 12
                            color: btArea.containsMouse ? Theme.accent : Theme.fg
                        }

                        MouseArea {
                            id: btArea
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            z: 5
                            onEntered: root.requestHoverPopup("bt")
                            onExited: root.cancelHoverPopup("bt")
                            onClicked: root.clickPopup("bt")
                            onWheel: wheel => root.handleWheel(wheel)
                        }
                    }

                    /* ── 6. Night Light Toggle Icon (Highlighted circle when enabled) ── */
                    Item {
                        id: nightPill
                        width: 24
                        height: 24
                        anchors.verticalCenter: parent.verticalCenter
                        scale: nightArea.pressed ? 0.92 : (nightArea.containsMouse ? 1.08 : 1.0)
                        Behavior on scale { NumberAnimation { duration: 120 } }

                        // Ambient blooming shape halo
                        MaterialShape {
                            anchors.centerIn: parent
                            width: parent.width + 4
                            height: parent.height + 4
                            shape: MaterialShape.PuffyDiamond
                            color: Qt.rgba(Theme.accent.r, Theme.accent.g, Theme.accent.b, 0.25)
                            scale: (nightArea.containsMouse || root.nightLightOn) ? 1.12 : 0.6
                            opacity: (nightArea.containsMouse || root.nightLightOn) ? 1.0 : 0.0
                            rotation: nightArea.containsMouse ? -12 : 0
                            Behavior on opacity { NumberAnimation { duration: 180 } }
                            Behavior on scale { NumberAnimation { duration: 240; easing.type: Easing.OutBack } }
                            Behavior on rotation { NumberAnimation { duration: 260; easing.type: Easing.OutBack } }
                        }

                        // Tactile highlight chip
                        MaterialShape {
                            anchors.fill: parent
                            shape: (nightArea.containsMouse || root.nightLightOn) ? MaterialShape.PuffyDiamond : MaterialShape.Circle
                            animationDuration: 240
                            animationEasing: Easing.OutBack
                            color: root.nightLightOn ? Qt.rgba(Theme.accent.r, Theme.accent.g, Theme.accent.b, 0.28) : (nightArea.containsMouse ? Qt.rgba(1, 1, 1, 0.14) : "transparent")
                            strokeColor: root.nightLightOn ? Theme.accent : (nightArea.containsMouse ? Qt.rgba(Theme.accent.r, Theme.accent.g, Theme.accent.b, 0.40) : "transparent")
                            strokeWidth: root.nightLightOn ? 1.5 : 1.0
                            rotation: nightArea.containsMouse ? -12 : 0
                            Behavior on color { ColorAnimation { duration: 120 } }
                            Behavior on strokeColor { ColorAnimation { duration: 120 } }
                            Behavior on rotation { NumberAnimation { duration: 240; easing.type: Easing.OutBack } }
                        }

                        Text {
                            anchors.centerIn: parent
                            text: "\uf186"
                            font.family: Theme.font
                            font.pixelSize: 12
                            color: root.nightLightOn ? Theme.accent : (nightArea.containsMouse ? Theme.accent : Theme.fg)
                        }

                        MouseArea {
                            id: nightArea
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            z: 5
                            onClicked: root.toggleNightLight()
                            onWheel: wheel => root.handleWheel(wheel)
                        }
                    }

                    /* ── 7. Notification Bell Icon ── */
                    Item {
                        id: notifPill
                        width: 24
                        height: 24
                        anchors.verticalCenter: parent.verticalCenter
                        scale: notifArea.pressed ? 0.92 : (notifArea.containsMouse ? 1.08 : 1.0)
                        Behavior on scale { NumberAnimation { duration: 120 } }

                        // Ambient blooming shape halo
                        MaterialShape {
                            anchors.centerIn: parent
                            width: parent.width + 4
                            height: parent.height + 4
                            shape: MaterialShape.Clover4Leaf
                            color: Qt.rgba(Theme.accent.r, Theme.accent.g, Theme.accent.b, 0.22)
                            scale: notifArea.containsMouse ? 1.12 : 0.6
                            opacity: notifArea.containsMouse ? 1.0 : 0.0
                            rotation: notifArea.containsMouse ? 12 : 0
                            Behavior on opacity { NumberAnimation { duration: 180 } }
                            Behavior on scale { NumberAnimation { duration: 240; easing.type: Easing.OutBack } }
                            Behavior on rotation { NumberAnimation { duration: 260; easing.type: Easing.OutBack } }
                        }

                        // Tactile highlight chip
                        MaterialShape {
                            anchors.fill: parent
                            shape: notifArea.containsMouse ? MaterialShape.Clover4Leaf : MaterialShape.Circle
                            animationDuration: 240
                            animationEasing: Easing.OutBack
                            color: notifArea.containsMouse ? Qt.rgba(1, 1, 1, 0.14) : "transparent"
                            strokeColor: notifArea.containsMouse ? Qt.rgba(Theme.accent.r, Theme.accent.g, Theme.accent.b, 0.40) : "transparent"
                            strokeWidth: 1.0
                            rotation: notifArea.containsMouse ? 12 : 0
                            Behavior on color { ColorAnimation { duration: 120 } }
                            Behavior on strokeColor { ColorAnimation { duration: 120 } }
                            Behavior on rotation { NumberAnimation { duration: 240; easing.type: Easing.OutBack } }
                        }

                        Item {
                            anchors.centerIn: parent
                            width: 14
                            height: 14

                            Text {
                                anchors.centerIn: parent
                                text: "\uf0f3"
                                font.family: Theme.font
                                font.pixelSize: 12
                                color: Theme.dnd ? Theme.fgDim : (notifArea.containsMouse ? Theme.accent : (root.notifCount > 0 ? Theme.accent : Theme.fg))
                            }

                            /* Small indicator dot for unread notifications */
                            Rectangle {
                                visible: root.notifCount > 0 && !Theme.dnd
                                anchors.top: parent.top
                                anchors.right: parent.right
                                anchors.topMargin: -1
                                anchors.rightMargin: -1
                                width: 5
                                height: 5
                                radius: 2.5
                                color: Theme.accent
                            }

                            /* DND 'z' badge when Do Not Disturb is active */
                            Item {
                                visible: Theme.dnd
                                anchors.top: parent.top
                                anchors.right: parent.right
                                anchors.topMargin: -5
                                anchors.rightMargin: -6
                                width: 10
                                height: 10

                                Text {
                                    anchors.centerIn: parent
                                    text: "z"
                                    font.family: "Valley Sans"
                                    font.pixelSize: 9
                                    font.weight: Font.Black
                                    color: Theme.accent
                                }
                            }
                        }

                        MouseArea {
                            id: notifArea
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            z: 5
                            onEntered: root.requestHoverPopup("notif")
                            onExited: root.cancelHoverPopup("notif")
                            onClicked: root.clickPopup("notif")
                            onWheel: wheel => root.handleWheel(wheel)
                        }
                    }
                }
            }

            /* ══════════════════════════════════════════════════════════════
             * PAGE 2: MEDIA OPTION
             * ══════════════════════════════════════════════════════════════ */
            Item {
                id: page2
                anchors.fill: parent
                visible: opacity > 0.001

                opacity: root.currentPage === 2 ? 1.0 : 0.0
                x: (2 - root.currentPage) * 24

                Behavior on opacity {
                    NumberAnimation { duration: 200; easing.type: Easing.OutCubic }
                }
                Behavior on x {
                    NumberAnimation { duration: 240; easing.type: Easing.OutCubic }
                }

                Row {
                    anchors.centerIn: parent
                    spacing: 8


                    /* Interactive Music Pill (Album Art Circle + Track Title / Synced Lyrics) */
                    Item {
                        id: musicPill
                        height: 24
                        width: 20 + 8 + ((capsule.musicHovered && LyricsService.hasLyrics) ? 250 : (capsule.musicHovered ? 200 : (root.hasTrack ? 120 : 72)))
                        anchors.verticalCenter: parent.verticalCenter

                        Behavior on width {
                            NumberAnimation { duration: 220; easing.type: Easing.OutCubic }
                        }

                        Row {
                            anchors.fill: parent
                            spacing: 8

                            /* Album Cover Art / Music Circle (Non-rotating) */
                            Rectangle {
                                width: 20
                                height: 20
                                radius: 10
                                clip: true
                                color: Qt.rgba(0.12, 0.13, 0.18, 0.9)
                                border.color: root.isPlaying ? Theme.accent : Qt.rgba(Theme.fg.r, Theme.fg.g, Theme.fg.b, 0.2)
                                border.width: 1
                                anchors.verticalCenter: parent.verticalCenter
                                scale: musicPillArea.pressed ? 0.92 : (musicPillArea.containsMouse ? 1.08 : 1.0)
                                Behavior on scale { NumberAnimation { duration: 120 } }

                                Image {
                                    anchors.fill: parent
                                    source: LyricsService.artUrl
                                    fillMode: Image.PreserveAspectCrop
                                    visible: status === Image.Ready && source != ""
                                }

                                Text {
                                    anchors.centerIn: parent
                                    text: "\uf001"
                                    font.family: "Font Awesome 6 Free"
                                    font.weight: Font.Black
                                    font.pixelSize: 9
                                    color: root.isPlaying ? Theme.accent : Qt.rgba(Theme.fg.r, Theme.fg.g, Theme.fg.b, 0.6)
                                    visible: !LyricsService.artUrl || LyricsService.artUrl === ""
                                }
                            }

                            /* Track Title or Live Synced Lyrics (Expanded width) */
                            Text {
                                width: (capsule.musicHovered && LyricsService.hasLyrics) ? 250 : (capsule.musicHovered ? 200 : (root.hasTrack ? 120 : 72))
                                height: 24
                                verticalAlignment: Text.AlignVCenter
                                text: {
                                    if (!root.hasTrack) return "No Media"
                                    if (capsule.musicHovered && LyricsService.hasLyrics) {
                                        return LyricsService.currentLine.length > 0 
                                            ? "♪ " + LyricsService.currentLine + " ♪" 
                                            : "♪ " + (root.trackTitle || "...") + " ♪"
                                    }
                                    return (root.trackTitle.length > 0 ? root.trackTitle : "Playing") + (root.trackArtist ? " · " + root.trackArtist : "")
                                }
                                font.pixelSize: 11
                                font.bold: true
                                font.family: "Inter"
                                color: (capsule.musicHovered && LyricsService.hasLyrics) ? Theme.accent : (root.hasTrack ? Theme.fg : Qt.rgba(Theme.fg.r, Theme.fg.g, Theme.fg.b, 0.5))
                                elide: Text.ElideRight
                                anchors.verticalCenter: parent.verticalCenter

                                Behavior on width {
                                    NumberAnimation { duration: 220; easing.type: Easing.OutCubic }
                                }
                            }
                        }

                        MouseArea {
                            id: musicPillArea
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            z: 5
                            onEntered: {
                                capsule.musicHovered = true
                            }
                            onExited: {
                                capsule.musicHovered = false
                            }
                            onClicked: root.clickPopup("smallMusic")
                            onWheel: wheel => root.handleWheel(wheel)
                        }
                    }

                    /* Mini Cava Visualizer (At the very END of the row, always visible) */
                    Row {
                        id: endVisualizer
                        spacing: 2
                        anchors.verticalCenter: parent.verticalCenter
                        visible: root.hasTrack

                        Repeater {
                            model: 4
                            Rectangle {
                                width: 2
                                height: root.isPlaying ? (root.cavaBars[index] || 3) : 3
                                radius: 1
                                color: Theme.accent
                                anchors.verticalCenter: parent.verticalCenter

                                Behavior on height {
                                    NumberAnimation { duration: 75; easing.type: Easing.OutQuad }
                                }
                            }
                        }
                    }
                }
            }
        }

        /* ── Modern Pagination Dots (Smooth Morphing Indicator) ── */
        Row {
            anchors.bottom: parent.bottom
            anchors.bottomMargin: 2
            anchors.horizontalCenter: parent.horizontalCenter
            spacing: 4
            z: 10

            Repeater {
                model: 3
                Rectangle {
                    width: root.currentPage === index ? 12 : 3
                    height: 2.5
                    radius: 1.25
                    color: root.currentPage === index ? Theme.accent : Qt.rgba(1, 1, 1, 0.22)

                    Behavior on width {
                        NumberAnimation { duration: 200; easing.type: Easing.OutCubic }
                    }
                    Behavior on color {
                        ColorAnimation { duration: 180 }
                    }

                    MouseArea {
                        anchors.fill: parent
                        anchors.margins: -4
                        cursorShape: Qt.PointingHandCursor
                        onClicked: root.currentPage = index
                    }
                }
            }
        }
    }
}
