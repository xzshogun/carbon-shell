import QtQuick
import QtQuick.Layouts
import QtQuick.Shapes
import QtQuick.Effects
import Quickshell
import Quickshell.Io
import Quickshell.Hyprland
import Quickshell.Services.Mpris
import Quickshell.Services.Pipewire
import Quickshell.Services.UPower
import Quickshell.Services.Notifications
import "../Singletons"

/**
 * NucleusHub — Barless sp3 Radial Desktop Environment
 *
 * Concepts:
 * 1. Resting state: tiny 14px nucleus dot at screen center with 2 faint concentric orbit rings
 *    and 6 carbon electrons (2 inner, 4 outer) rotating quietly.
 * 2. Opening: ripple ring expands from center, central nucleus grows to 38px circle displaying HH:mm,
 *    calendar ticks ring around it (today's tick elongated & accent colored), weekday & date caption below.
 * 3. Phase 2: 4 sp3 hybrid orbital teardrops (QtQuick Shapes ShapePath cubic bezier curves)
 *    blossom at angles -65°, 25°, 135°, 205° with uneven organic scales (1.0, 0.88, 1.05, 0.9).
 * 4. Phase 3: Focus & 4 round satellites per lobe (CONNECT, LAUNCH, SPACES, ALERTS).
 * 5. Phase 4: Wallpapers mode collapses lobes into nucleus, revealing 16 circular thumbnail orbs
 *    (6 inner ring, 10 outer ring) connected to Wallhaven.
 */
Item {
    id: root

    /* ── Signals ── */
    signal openLauncher()
    signal openWallpapers()
    signal closeRequested()

    /* ── Properties & State ── */
    property bool hubOpen: false
    property string activeMode: "hub" // "hub" | "wallpapers" | "appsearch"
    property string focusedLobe: ""    // "" | "connect" | "launch" | "spaces" | "alerts"
    property bool showRestingDot: true
    property bool idleBreathing: false

    /* External IPC Triggers */
    function toggle() {
        if (root.hubOpen) {
            close()
        } else {
            open()
        }
    }

    Component.onCompleted: {
        root.randomizeOrbitalPositions()
    }

    onHubOpenChanged: {
        if (root.hubOpen) {
            root.randomizeOrbitalPositions()
        }
    }

    function open() {
        root.randomizeOrbitalPositions()
        root.hubOpen = true
        root.activeMode = "hub"
        root.focusedLobe = ""
    }

    Timer {
        id: closeFinishTimer
        interval: 380
        onTriggered: root.closeRequested()
    }

    function close() {
        root.hubOpen = false
        root.activeMode = "hub"
        root.focusedLobe = ""
        closeFinishTimer.restart()
    }

    function focusLobe(name) {
        if (!root.hubOpen) root.open()
        root.activeMode = "hub"
        root.focusedLobe = (root.focusedLobe === name) ? "" : name
    }

    function openWallpaperMode() {
        if (!root.hubOpen) root.open()
        root.activeMode = "wallpapers"
        root.focusedLobe = ""
        wpSearchInput.text = ""
        fetchWallpapers()
    }

    function openLauncherMode() {
        if (!root.hubOpen) root.open()
        root.activeMode = "appsearch"
        root.focusedLobe = "launch"
        appSearchInput.text = ""
        appSearchInput.forceActiveFocus()
        refreshAppList()
    }

    /* ── Randomize Orbital Positions & Distances on Each Open ── */
    function randomizeOrbitalPositions() {
        if (!lobeConnect || !lobeLaunch || !lobeSpaces || !lobeAlerts) return

        // 4 deliberate asymmetric sectors spanning the upper dome (175° .. 365° / 5°)
        // Completely leaves the bottom 170° clear — orbs never enter the music overlay/controls region!
        var sectors = [
            { min: 175.0, max: 210.0 }, // Sector 1: Left flank (max y <= +14px)
            { min: 220.0, max: 255.0 }, // Sector 2: Upper-Left (y <= -90px)
            { min: 285.0, max: 320.0 }, // Sector 3: Upper-Right (y <= -90px)
            { min: 330.0, max: 365.0 }  // Sector 4: Right flank (max y <= +14px)
        ]

        // Shuffle sector assignments randomly so any orb can appear in any sector
        var order = [0, 1, 2, 3]
        for (var i = order.length - 1; i > 0; i--) {
            var j = Math.floor(Math.random() * (i + 1))
            var temp = order[i]
            order[i] = order[j]
            order[j] = temp
        }

        var lobes = [lobeConnect, lobeLaunch, lobeSpaces, lobeAlerts]
        for (var k = 0; k < 4; k++) {
            var lobe = lobes[k]
            if (!lobe) continue
            var sec = sectors[order[k]]
            // Random angle within assigned sector
            var angle = sec.min + (Math.random() * (sec.max - sec.min))
            if (angle >= 360.0) angle -= 360.0

            // Random orbital radius between 118px and 152px
            var dist = Math.round(118.0 + Math.random() * 34.0)

            lobe.targetAngle = angle
            lobe.orbitalRadius = dist
        }
    }

    /* ── Colors / Theme Tokens ── */
    readonly property color colTeal: Theme.accent || "#00F0FF"
    readonly property color colPurple: Theme.m3tertiary || "#c084fc"
    readonly property color colCoral: Theme.err || "#f87171"
    readonly property color colAmber: Theme.warn || "#fbbf24"
    readonly property color colBgDark: Theme.bg || "#0e0e14"
    readonly property color colFg: Theme.fg || "#e6e4f0"
    readonly property color colFgDim: Theme.fgDim || "#94a3b8"

    /* ── Time & Date ── */
    property var currentTime: new Date()
    Timer {
        interval: 1000
        repeat: true
        running: true
        onTriggered: root.currentTime = new Date()
    }

    readonly property string hourStr: {
        var h = root.currentTime.getHours()
        return h < 10 ? "0" + h : String(h)
    }
    readonly property string minStr: {
        var m = root.currentTime.getMinutes()
        return m < 10 ? "0" + m : String(m)
    }
    readonly property string timeStr: hourStr + ":" + minStr

    readonly property string dateCaptionStr: {
        var days = ["Sun", "Mon", "Tue", "Wed", "Thu", "Fri", "Sat"]
        var months = ["Jan", "Feb", "Mar", "Apr", "May", "Jun", "Jul", "Aug", "Sep", "Oct", "Nov", "Dec"]
        return days[root.currentTime.getDay()] + " " + root.currentTime.getDate() + " " + months[root.currentTime.getMonth()]
    }

    readonly property int currentDay: root.currentTime.getDate()
    readonly property int daysInMonth: new Date(root.currentTime.getFullYear(), root.currentTime.getMonth() + 1, 0).getDate()

    /* ── Services Integration ── */
    // 1. Audio Sink
    readonly property var audioSink: Pipewire.defaultAudioSink
    readonly property int audioVol: (audioSink && audioSink.audio) ? Math.round(audioSink.audio.volume * 100) : 50
    function stepVolume(delta) {
        if (audioSink && audioSink.audio) {
            audioSink.audio.volume = Math.max(0.0, Math.min(1.0, audioSink.audio.volume + delta))
        }
    }

    // 2. Battery
    readonly property var batteryDev: UPower.displayDevice
    readonly property int batteryPct: batteryDev ? Math.round(batteryDev.percentage * 100) : 100
    readonly property bool isCharging: batteryDev ? (batteryDev.state === 1 || batteryDev.state === 4) : false

    // 3. Workspaces (Hyprland)
    property int activeWs: 1
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
            const n = event.name
            if (n === "workspace" || n === "workspacev2") {
                const id = parseInt(event.data, 10)
                if (!isNaN(id) && id > 0) root.activeWs = id
            }
        }
    }
    function switchWorkspace(id) {
        root.activeWs = id
        Quickshell.execDetached(["hyprctl", "dispatch", "workspace", String(id)])
    }

    // 4. Notifications
    property int unreadNotifCount: 0
    Connections {
        target: NotificationServer
        function onNotification(notif) {
            root.unreadNotifCount += 1
        }
    }

    /* ── Animation Progress Constants ── */
    property real hubProgress: root.hubOpen ? 1.0 : 0.0
    Behavior on hubProgress {
        NumberAnimation {
            duration: 380
            easing.type: Easing.OutCubic
        }
    }

    /* ── Dim Scrim Background ── */
    Rectangle {
        anchors.fill: parent
        color: "#000000"
        opacity: root.hubProgress * 0.42
        visible: opacity > 0.005

        MouseArea {
            anchors.fill: parent
            onClicked: root.close()
        }
    }

    /* ── Keyboard Handling (Escape to close or back) ── */
    Item {
        focus: root.hubOpen
        Keys.onEscapePressed: {
            if (root.activeMode === "wallpapers" || root.activeMode === "appsearch") {
                root.activeMode = "hub"
            } else if (root.focusedLobe !== "") {
                root.focusedLobe = ""
            } else {
                root.close()
            }
        }
    }

    /* ══════════════════════════════════════════════════════════════════════════
       PHASE 1: Resting Carbon Dot & Expanding Ripple + Nucleus
       ══════════════════════════════════════════════════════════════════════════ */

    // Full Hub Arena Centered
    Item {
        id: hubCenter
        anchors.centerIn: parent
        width: 1
        height: 1



        /* ══════════════════════════════════════════════════════════════════════
           PHASE 2: The Four sp3 Hybrid Orbital Lobes
           Teardrop Bezier Curves: M0,0 C22,-36 80,-38 100,0 C80,38 22,36 0,0
           ══════════════════════════════════════════════════════════════════════ */
        Item {
            id: lobesLayer
            anchors.centerIn: parent
            visible: root.hubProgress > 0.05 && root.activeMode !== "wallpapers"
            opacity: (root.activeMode === "wallpapers") ? 0.0 : root.hubProgress
            Behavior on opacity { NumberAnimation { duration: 240; easing.type: Easing.OutCubic } }

            // Lobe template component
            component OrbitalLobe: Item {
                id: lobeItem
                property string lobeId: ""
                property real targetAngle: 0
                property real orbitalRadius: 155
                property real baseScale: 1.0
                property color lobeColor: root.colTeal
                property string iconGlyph: ""
                property string lobeTitle: ""
                property int staggerDelay: 0

                Behavior on orbitalRadius { NumberAnimation { duration: 320; easing.type: Easing.OutCubic } }
                Behavior on targetAngle { NumberAnimation { duration: 340; easing.type: Easing.OutCubic } }

                // Gentle organic quantum idle float ("moving just a bit")
                property int idleDuration: 5400
                property int idlePhaseDelay: 0
                property real idleAngleOffset: 0.0
                property real idleDistOffset: 0.0

                SequentialAnimation {
                    running: root.hubOpen && !lobeItem.isThisFocused
                    loops: Animation.Infinite
                    PauseAnimation { duration: lobeItem.idlePhaseDelay }
                    ParallelAnimation {
                        NumberAnimation {
                            target: lobeItem
                            property: "idleAngleOffset"
                            from: -1.6
                            to: 1.6
                            duration: lobeItem.idleDuration / 2
                            easing.type: Easing.InOutSine
                        }
                        NumberAnimation {
                            target: lobeItem
                            property: "idleDistOffset"
                            from: -3.0
                            to: 3.0
                            duration: lobeItem.idleDuration / 2
                            easing.type: Easing.InOutSine
                        }
                    }
                    ParallelAnimation {
                        NumberAnimation {
                            target: lobeItem
                            property: "idleAngleOffset"
                            from: 1.6
                            to: -1.6
                            duration: lobeItem.idleDuration / 2
                            easing.type: Easing.InOutSine
                        }
                        NumberAnimation {
                            target: lobeItem
                            property: "idleDistOffset"
                            from: 3.0
                            to: -3.0
                            duration: lobeItem.idleDuration / 2
                            easing.type: Easing.InOutSine
                        }
                    }
                }

                // Origin is at center of hub, with gentle radial displacement
                readonly property real idleRad: targetAngle * (Math.PI / 180.0)
                x: isThisFocused ? 0 : (idleDistOffset * Math.cos(idleRad))
                y: isThisFocused ? 0 : (idleDistOffset * Math.sin(idleRad))
                width: 1
                height: 1
                transformOrigin: Item.TopLeft

                // Geometry
                readonly property bool isThisFocused: root.focusedLobe === lobeItem.lobeId
                readonly property bool isAnyFocused: root.focusedLobe !== ""

                // Dynamic Scale & Opacity per specifications:
                // Focused lobe scale 0.92, others shrink to 0.45 and dim to 35%
                readonly property real targetScale: isThisFocused ? 0.92 : (isAnyFocused ? (baseScale * 0.45) : baseScale)
                readonly property real targetAlpha: isThisFocused ? 1.0 : (isAnyFocused ? 0.35 : 1.0)

                property real bloomAnim: 0.0

                SequentialAnimation {
                    id: lobeBloomSeq
                    running: root.hubOpen && root.activeMode !== "wallpapers"
                    PauseAnimation { duration: lobeItem.staggerDelay }
                    NumberAnimation {
                        target: lobeItem
                        property: "bloomAnim"
                        from: 0.0
                        to: 1.0
                        duration: 340
                        easing.type: Easing.OutCubic
                    }
                }

                rotation: targetAngle + (isThisFocused ? 0.0 : idleAngleOffset)
                scale: targetScale * bloomAnim
                opacity: targetAlpha * bloomAnim
                Behavior on scale { NumberAnimation { duration: 280; easing.type: Easing.OutCubic } }
                Behavior on opacity { NumberAnimation { duration: 240; easing.type: Easing.OutCubic } }

                // ── 48px Standalone Round Icon Button at dynamic orbitalRadius ──
                Item {
                    id: lobeTipButton
                    x: lobeItem.orbitalRadius - 24
                    y: -24
                    width: 48
                    height: 48

                    Rectangle {
                        anchors.fill: parent
                        radius: width / 2
                        color: lobeMouse.containsMouse 
                               ? Qt.rgba(lobeItem.lobeColor.r, lobeItem.lobeColor.g, lobeItem.lobeColor.b, 0.40) 
                               : (lobeItem.isThisFocused 
                                  ? Qt.rgba(lobeItem.lobeColor.r, lobeItem.lobeColor.g, lobeItem.lobeColor.b, 0.30)
                                  : Qt.rgba(root.colBgDark.r, root.colBgDark.g, root.colBgDark.b, 0.92))
                        border.color: lobeItem.lobeColor
                        border.width: 2.0
                        scale: lobeMouse.containsMouse ? 1.15 : 1.0
                        Behavior on scale { NumberAnimation { duration: 160; easing.type: Easing.OutCubic } }

                        Text {
                            anchors.centerIn: parent
                            text: lobeItem.iconGlyph
                            font.family: Theme.fontIcon
                            font.pixelSize: 22
                            color: lobeItem.lobeColor
                            rotation: -lobeItem.rotation
                        }
                    }

                    MouseArea {
                        id: lobeMouse
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            root.focusLobe(lobeItem.lobeId)
                        }
                    }
                }

                /* ══════════════════════════════════════════════════════════════
                   PHASE 3: Satellites around tip when focused
                   Smooth blooming OutBack spring blossom animation
                   ══════════════════════════════════════════════════════════════ */
                Item {
                    id: satellitesContainer
                    x: lobeItem.orbitalRadius
                    y: 0
                    visible: opacity > 0.005
                    opacity: lobeItem.isThisFocused ? 1.0 : 0.0
                    Behavior on opacity { NumberAnimation { duration: 220; easing.type: Easing.OutCubic } }

                    Repeater {
                        model: lobeItem.satelliteModel
                        delegate: Item {
                            id: satDelegateItem
                            required property int index
                            required property var modelData

                            // Angles -72°, -24°, 24°, 72° relative to lobe ray
                            readonly property var satAngles: [-72, -24, 24, 72]
                            readonly property real relDeg: satAngles[index]
                            readonly property real relRad: relDeg * (Math.PI / 180.0)
                            readonly property real satRadius: 66

                            property real satPop: 0.0

                            Connections {
                                target: lobeItem
                                function onIsThisFocusedChanged() {
                                    if (!lobeItem.isThisFocused) {
                                        satPop = 0.0
                                    }
                                }
                            }

                            SequentialAnimation {
                                running: lobeItem.isThisFocused
                                PauseAnimation { duration: index * 42 }
                                NumberAnimation {
                                    target: satDelegateItem
                                    property: "satPop"
                                    from: 0.0
                                    to: 1.0
                                    duration: 380
                                    easing.type: Easing.OutBack
                                    easing.overshoot: 1.18
                                }
                            }

                            // Radial position smoothly blooms outward with fluid spring
                            x: (satRadius * Math.cos(relRad) * satPop) - width / 2
                            y: (satRadius * Math.sin(relRad) * satPop) - height / 2
                            width: 40
                            height: 40
                            scale: 0.35 + 0.65 * satPop
                            opacity: Math.min(1.0, satPop * 1.5)

                            // Circular Satellite Button
                            Rectangle {
                                anchors.fill: parent
                                radius: width / 2
                                color: modelData.isActive 
                                       ? Qt.rgba(lobeItem.lobeColor.r, lobeItem.lobeColor.g, lobeItem.lobeColor.b, 0.36)
                                       : (satMouse.containsMouse 
                                          ? Qt.rgba(lobeItem.lobeColor.r, lobeItem.lobeColor.g, lobeItem.lobeColor.b, 0.24)
                                          : Qt.rgba(root.colBgDark.r, root.colBgDark.g, root.colBgDark.b, 0.95))
                                border.color: lobeItem.lobeColor
                                border.width: 1.8
                                scale: satMouse.containsMouse ? 1.14 : 1.0
                                Behavior on scale { NumberAnimation { duration: 150; easing.type: Easing.OutCubic } }

                                Text {
                                    anchors.centerIn: parent
                                    text: modelData.icon
                                    font.family: modelData.isFontIcon ? Theme.fontIcon : "Valley Sans"
                                    font.pixelSize: modelData.isFontIcon ? 18 : 14
                                    font.bold: true
                                    color: lobeItem.lobeColor
                                    rotation: -lobeItem.rotation
                                }

                                // Badge for notifications (Unread count)
                                Rectangle {
                                    visible: modelData.badgeCount !== undefined && modelData.badgeCount > 0
                                    anchors.top: parent.top
                                    anchors.right: parent.right
                                    anchors.topMargin: -4
                                    anchors.rightMargin: -4
                                    width: 16; height: 16; radius: 8
                                    color: root.colCoral
                                    Text {
                                        anchors.centerIn: parent
                                        text: String(modelData.badgeCount || "")
                                        font.family: "Valley Sans"
                                        font.pixelSize: 9
                                        font.bold: true
                                        color: "#ffffff"
                                    }
                                }

                                MouseArea {
                                    id: satMouse
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: {
                                        modelData.action()
                                    }
                                }
                            }
                        }
                    }
                }

                // Placeholder property overridden per lobe instance
                property var satelliteModel: []
            }

            // ── 1. CONNECT (Angle: -65°, Scale: 1.0, Color: Teal) ──────────
            OrbitalLobe {
                id: lobeConnect
                lobeId: "connect"
                targetAngle: 195
                baseScale: 1.00
                staggerDelay: 0
                idleDuration: 5200
                idlePhaseDelay: 0
                lobeColor: root.colTeal
                iconGlyph: "wifi"
                lobeTitle: "Connect"

                satelliteModel: [
                    {
                        icon: "wifi",
                        isFontIcon: true,
                        isActive: true,
                        action: function() {
                            Quickshell.execDetached(["sh", "-c", "nm-connection-editor || true"])
                        }
                    },
                    {
                        icon: "bluetooth",
                        isFontIcon: true,
                        isActive: true,
                        action: function() {
                            Quickshell.execDetached(["sh", "-c", "blueman-manager || true"])
                        }
                    },
                    {
                        icon: "volume_up",
                        isFontIcon: true,
                        isActive: false,
                        action: function() {
                            Quickshell.execDetached(["pavucontrol"])
                        }
                    },
                    {
                        icon: "light_mode",
                        isFontIcon: true,
                        isActive: false,
                        action: function() {
                            Quickshell.execDetached(["brightnessctl", "set", "+10%"])
                        }
                    }
                ]
            }

            // ── 2. LAUNCH (Angle: 25°, Scale: 0.88, Color: Coral/Purple) ────
            OrbitalLobe {
                id: lobeLaunch
                lobeId: "launch"
                targetAngle: 240
                baseScale: 0.88
                staggerDelay: 90
                idleDuration: 6200
                idlePhaseDelay: 1200
                lobeColor: root.colPurple
                iconGlyph: "apps"
                lobeTitle: "Launch"

                satelliteModel: [
                    {
                        icon: "search",
                        isFontIcon: true,
                        isActive: root.activeMode === "appsearch",
                        action: function() {
                            root.openLauncherMode()
                        }
                    },
                    {
                        icon: "language",
                        isFontIcon: true,
                        isActive: false,
                        action: function() {
                            Quickshell.execDetached(["xdg-open", "https://google.com"])
                        }
                    },
                    {
                        icon: "folder",
                        isFontIcon: true,
                        isActive: false,
                        action: function() {
                            Quickshell.execDetached(["xdg-open", Quickshell.env("HOME") || "/home/shogun"])
                        }
                    },
                    {
                        icon: "wallpaper",
                        isFontIcon: true,
                        isActive: root.activeMode === "wallpapers",
                        action: function() {
                            root.openWallpaperMode()
                        }
                    }
                ]
            }

            // ── 3. SPACES (Angle: 135°, Scale: 1.05, Color: Coral) ──────────
            OrbitalLobe {
                id: lobeSpaces
                lobeId: "spaces"
                targetAngle: 300
                baseScale: 1.05
                staggerDelay: 180
                idleDuration: 5600
                idlePhaseDelay: 2400
                lobeColor: root.colCoral
                iconGlyph: "dashboard"
                lobeTitle: "Spaces"

                satelliteModel: [
                    {
                        icon: "1",
                        isFontIcon: false,
                        isActive: root.activeWs === 1,
                        action: function() { root.switchWorkspace(1) }
                    },
                    {
                        icon: "2",
                        isFontIcon: false,
                        isActive: root.activeWs === 2,
                        action: function() { root.switchWorkspace(2) }
                    },
                    {
                        icon: "3",
                        isFontIcon: false,
                        isActive: root.activeWs === 3,
                        action: function() { root.switchWorkspace(3) }
                    },
                    {
                        icon: "4",
                        isFontIcon: false,
                        isActive: root.activeWs === 4,
                        action: function() { root.switchWorkspace(4) }
                    }
                ]
            }

            // ── 4. ALERTS (Angle: 205°, Scale: 0.90, Color: Amber) ──────────
            OrbitalLobe {
                id: lobeAlerts
                lobeId: "alerts"
                targetAngle: 345
                baseScale: 0.90
                staggerDelay: 270
                idleDuration: 6800
                idlePhaseDelay: 3600
                lobeColor: root.colAmber
                iconGlyph: "notifications"
                lobeTitle: "Alerts"

                satelliteModel: [
                    {
                        icon: "notifications",
                        isFontIcon: true,
                        isActive: false,
                        badgeCount: root.unreadNotifCount,
                        action: function() {
                            root.unreadNotifCount = 0
                        }
                    },
                    {
                        icon: "calendar_month",
                        isFontIcon: true,
                        isActive: false,
                        action: function() {}
                    },
                    {
                        icon: "bedtime",
                        isFontIcon: true,
                        isActive: Theme.dnd,
                        action: function() {
                            Theme.dnd = !Theme.dnd
                        }
                    },
                    {
                        icon: "content_paste",
                        isFontIcon: true,
                        isActive: false,
                        action: function() {
                            Quickshell.execDetached(["sh", "-c", "cliphist list | fuzzel -d | cliphist decode | wl-copy || true"])
                        }
                    }
                ]
            }
        }

        /* ══════════════════════════════════════════════════════════════════════
           CENTER NUCLEUS ORB (Lockscreen ValenceDot Bohr Atom Styling)
           - Glowing outer neon halo matching lockscreen dots
           - Vibrant crisp core disc (White with neon accent border)
           - Inner bright dot when resting; clear bold time display when open
           ══════════════════════════════════════════════════════════════════════ */
        Item {
            id: nucleusCore
            anchors.centerIn: parent
            width: root.hubOpen ? 58 : 16
            height: width
            Behavior on width { NumberAnimation { duration: 320; easing.type: Easing.OutCubic } }

            // Glowing Outer Halo (matches lockscreen ValenceDot halo)
            Rectangle {
                id: nucleusHalo
                anchors.centerIn: parent
                width: nucleusCore.width + (root.hubOpen ? 24 : 10)
                height: width
                radius: width / 2
                color: Qt.rgba(root.colTeal.r, root.colTeal.g, root.colTeal.b, 0.42)
                opacity: root.hubOpen ? 0.70 : 0.45
                Behavior on opacity { NumberAnimation { duration: 280; easing.type: Easing.OutCubic } }
                Behavior on width { NumberAnimation { duration: 320; easing.type: Easing.OutCubic } }
            }

            // Vibrant Core Disc (White with neon border, matching lockscreen ValenceDot)
            Rectangle {
                id: nucleusCoreDisc
                anchors.fill: parent
                radius: width / 2
                color: "#FFFFFF"
                border.color: root.colTeal
                border.width: root.hubOpen ? 2.4 : 1.5


                // Time readout inside disc when open
                Text {
                    anchors.centerIn: parent
                    visible: root.hubOpen
                    opacity: root.hubProgress
                    text: root.timeStr
                    font.family: "Valley Sans"
                    font.pixelSize: 13
                    font.bold: true
                    color: "#0b0e14"
                }

                MouseArea {
                    anchors.fill: parent
                    cursorShape: Qt.PointingHandCursor
                    onClicked: {
                        if (root.activeMode === "wallpapers") {
                            root.shuffleWallpaperQuery()
                        } else {
                            root.toggle()
                        }
                    }
                }
            }
        }

        /* ══════════════════════════════════════════════════════════════════════
           CIRCULAR ORBITAL PROGRESS RING (Encircles Center Nucleus Orb)
           ══════════════════════════════════════════════════════════════════════ */
        Item {
            id: musicProgressRing
            anchors.centerIn: parent
            width: 116
            height: 116
            visible: root.hubOpen && LyricsService.hasTrack && root.activeMode === "hub"
            opacity: (root.hubProgress > 0.35 && LyricsService.hasTrack && root.activeMode === "hub") ? 1.0 : 0.0
            scale: 0.7 + (0.3 * root.hubProgress)
            Behavior on opacity { NumberAnimation { duration: 240; easing.type: Easing.OutCubic } }
            Behavior on scale { NumberAnimation { duration: 320; easing.type: Easing.OutCubic } }

            readonly property real rawProgress: (LyricsService.totalLength > 0)
                ? Math.max(0.0, Math.min(1.0, LyricsService.currentPosition / LyricsService.totalLength)) : 0.0

            property real animProgress: rawProgress
            Behavior on animProgress {
                NumberAnimation { duration: 150; easing.type: Easing.Linear }
            }

            readonly property real trackRadius: 50
            readonly property real currentAngleRad: -Math.PI / 2 + (2 * Math.PI * animProgress)

            Shape {
                id: progressShape
                anchors.fill: parent
                layer.enabled: true
                layer.samples: 4

                // 1. Faint Orbital Guide Ring
                ShapePath {
                    strokeWidth: 2.0
                    strokeColor: Qt.rgba(1, 1, 1, 0.14)
                    fillColor: "transparent"
                    capStyle: ShapePath.RoundCap
                    PathAngleArc {
                        centerX: 58
                        centerY: 58
                        radiusX: 50
                        radiusY: 50
                        startAngle: 0
                        sweepAngle: 360
                    }
                }

                // 2. Neon Accent Progress Arc
                ShapePath {
                    strokeWidth: 2.6
                    strokeColor: root.colTeal
                    fillColor: "transparent"
                    capStyle: ShapePath.RoundCap
                    PathAngleArc {
                        centerX: 58
                        centerY: 58
                        radiusX: 50
                        radiusY: 50
                        startAngle: -90
                        sweepAngle: Math.max(0.1, Math.min(359.9, musicProgressRing.animProgress * 360.0))
                    }
                }
            }

            // Leading Specular Glowing Dot at progress head
            Rectangle {
                id: progressDot
                visible: musicProgressRing.animProgress > 0.005
                width: 6
                height: 6
                radius: 3
                color: "#FFFFFF"
                x: 58 + musicProgressRing.trackRadius * Math.cos(musicProgressRing.currentAngleRad) - 3
                y: 58 + musicProgressRing.trackRadius * Math.sin(musicProgressRing.currentAngleRad) - 3

                Rectangle {
                    anchors.centerIn: parent
                    width: 12
                    height: 12
                    radius: 6
                    color: Qt.rgba(root.colTeal.r, root.colTeal.g, root.colTeal.b, 0.5)
                    z: -1
                }
            }

            // Interactive Click & Drag to Seek
            MouseArea {
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor

                function seekFromMouse(mouse) {
                    const dx = mouse.x - width / 2;
                    const dy = mouse.y - height / 2;
                    const dist = Math.sqrt(dx * dx + dy * dy);
                    if (dist >= 36 && dist <= 66) {
                        let angle = Math.atan2(dy, dx);
                        let frac = (angle + Math.PI / 2) / (2 * Math.PI);
                        if (frac < 0) frac += 1.0;
                        LyricsService.seekFraction(frac);
                    }
                }

                onClicked: (mouse) => seekFromMouse(mouse)
                onPositionChanged: (mouse) => {
                    if (pressed) seekFromMouse(mouse);
                }
            }
        }

        /* ══════════════════════════════════════════════════════════════════════
           ORGANIC MUSIC & SYNCED LYRICS OVERLAY (Barless, pure circular geometry)
           ══════════════════════════════════════════════════════════════════════ */
        Item {
            id: nucleusMusicOverlay
            anchors.horizontalCenter: parent.horizontalCenter
            anchors.top: parent.bottom
            anchors.topMargin: 56
            width: 320
            height: 84
            visible: root.hubOpen && LyricsService.hasTrack && root.activeMode === "hub"
            opacity: (root.hubProgress > 0.25 && LyricsService.hasTrack && root.activeMode === "hub") ? 1.0 : 0.0
            Behavior on opacity { NumberAnimation { duration: 250; easing.type: Easing.OutCubic } }

            property bool forceMetadata: false
            readonly property bool showingLyrics: !forceMetadata && LyricsService.hasLyrics && (LyricsService.currentLine.trim().length > 0)

            ColumnLayout {
                anchors.fill: parent
                spacing: 5

                // ── 1. Track / Lyrics Display ──
                Item {
                    Layout.fillWidth: true
                    Layout.preferredHeight: 38

                    // A. Synced Lyrics View (Centered, poetic typography)
                    ColumnLayout {
                        anchors.fill: parent
                        visible: nucleusMusicOverlay.showingLyrics
                        spacing: 2

                        Text {
                            id: lyricMainText
                            Layout.fillWidth: true
                            horizontalAlignment: Text.AlignHCenter
                            text: LyricsService.currentLine
                            font.family: "Valley Sans"
                            font.pixelSize: 13
                            font.bold: true
                            color: root.colTeal
                            elide: Text.ElideRight
                            maximumLineCount: 1

                            Behavior on color { ColorAnimation { duration: 200 } }
                        }

                        Text {
                            Layout.fillWidth: true
                            horizontalAlignment: Text.AlignHCenter
                            text: LyricsService.nextLine.length > 0 ? ("› " + LyricsService.nextLine) : ""
                            font.family: "Valley Sans"
                            font.pixelSize: 10
                            color: Qt.rgba(root.colFgDim.r, root.colFgDim.g, root.colFgDim.b, 0.65)
                            elide: Text.ElideRight
                            maximumLineCount: 1
                            visible: text.length > 0
                        }
                    }

                    // B. Track Info View (Album art micro-orb + centered info)
                    RowLayout {
                        anchors.centerIn: parent
                        visible: !nucleusMusicOverlay.showingLyrics
                        spacing: 8

                        // Circular Album Art Micro-Orb
                        Rectangle {
                            Layout.preferredWidth: 26
                            Layout.preferredHeight: 26
                            radius: 13
                            color: "#181B22"
                            border.color: Qt.rgba(root.colTeal.r, root.colTeal.g, root.colTeal.b, 0.5)
                            border.width: 1.2
                            clip: true

                            Image {
                                anchors.fill: parent
                                source: LyricsService.artUrl
                                fillMode: Image.PreserveAspectCrop
                                visible: status === Image.Ready && source !== ""
                            }

                            Text {
                                anchors.centerIn: parent
                                text: "music_note"
                                font.family: Theme.fontIcon
                                font.pixelSize: 14
                                color: root.colTeal
                                visible: !LyricsService.artUrl || LyricsService.artUrl === ""
                            }
                        }

                        ColumnLayout {
                            spacing: 1

                            Text {
                                text: LyricsService.trackTitle || "Playing Track"
                                font.family: "Valley Sans"
                                font.pixelSize: 12
                                font.bold: true
                                color: "#FFFFFF"
                                elide: Text.ElideRight
                                maximumLineCount: 1
                                Layout.maximumWidth: 250
                            }

                            Text {
                                text: LyricsService.trackArtist || "Unknown Artist"
                                font.family: "Valley Sans"
                                font.pixelSize: 10
                                color: root.colFgDim
                                elide: Text.ElideRight
                                maximumLineCount: 1
                                Layout.maximumWidth: 250
                            }
                        }
                    }

                    // Click text area to toggle between lyrics and track metadata if both exist
                    MouseArea {
                        anchors.fill: parent
                        cursorShape: LyricsService.hasLyrics ? Qt.PointingHandCursor : Qt.ArrowCursor
                        onClicked: {
                            if (LyricsService.hasLyrics) {
                                nucleusMusicOverlay.forceMetadata = !nucleusMusicOverlay.forceMetadata
                            }
                        }
                    }
                }

                // ── 2. ValenceDot Circular Transport Controls Row ──
                RowLayout {
                    Layout.alignment: Qt.AlignHCenter
                    spacing: 12

                    // Elapsed Time Readout
                    Text {
                        text: LyricsService.formatTime(LyricsService.currentPosition)
                        font.family: "JetBrainsMono Nerd Font"
                        font.pixelSize: 9
                        color: root.colFgDim
                    }

                    // Skip Previous Button (26px circle)
                    Rectangle {
                        Layout.preferredWidth: 26
                        Layout.preferredHeight: 26
                        radius: 13
                        color: prevMouse.containsMouse ? Qt.rgba(1, 1, 1, 0.16) : Qt.rgba(0.08, 0.10, 0.14, 0.75)
                        border.color: prevMouse.containsMouse ? root.colTeal : Qt.rgba(1, 1, 1, 0.14)
                        border.width: 1.2
                        scale: prevMouse.containsMouse ? 1.14 : 1.0
                        Behavior on scale { NumberAnimation { duration: 150; easing.type: Easing.OutCubic } }

                        Text {
                            anchors.centerIn: parent
                            text: "skip_previous"
                            font.family: Theme.fontIcon
                            font.pixelSize: 15
                            color: prevMouse.containsMouse ? root.colTeal : "#D0D6E0"
                        }

                        MouseArea {
                            id: prevMouse
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: LyricsService.skipPrevious()
                        }
                    }

                    // Play / Pause Button (32px ValenceDot circle with halo)
                    Item {
                        Layout.preferredWidth: 32
                        Layout.preferredHeight: 32

                        Rectangle {
                            anchors.centerIn: parent
                            width: parent.width + 10
                            height: width
                            radius: width / 2
                            color: Qt.rgba(root.colTeal.r, root.colTeal.g, root.colTeal.b, 0.35)
                            visible: playMouse.containsMouse || LyricsService.isPlaying
                            opacity: playMouse.containsMouse ? 0.75 : 0.40
                            Behavior on opacity { NumberAnimation { duration: 180 } }
                        }

                        Rectangle {
                            anchors.fill: parent
                            radius: width / 2
                            color: LyricsService.isPlaying ? root.colTeal : "#FFFFFF"
                            border.color: root.colTeal
                            border.width: 1.8
                            scale: playMouse.containsMouse ? 1.12 : 1.0
                            Behavior on scale { NumberAnimation { duration: 150; easing.type: Easing.OutCubic } }

                            Text {
                                anchors.centerIn: parent
                                text: LyricsService.isPlaying ? "pause" : "play_arrow"
                                font.family: Theme.fontIcon
                                font.pixelSize: 18
                                color: LyricsService.isPlaying ? "#0b0e14" : root.colTeal
                            }

                            MouseArea {
                                id: playMouse
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: LyricsService.togglePlaying()
                            }
                        }
                    }

                    // Skip Next Button (26px circle)
                    Rectangle {
                        Layout.preferredWidth: 26
                        Layout.preferredHeight: 26
                        radius: 13
                        color: nextMouse.containsMouse ? Qt.rgba(1, 1, 1, 0.16) : Qt.rgba(0.08, 0.10, 0.14, 0.75)
                        border.color: nextMouse.containsMouse ? root.colTeal : Qt.rgba(1, 1, 1, 0.14)
                        border.width: 1.2
                        scale: nextMouse.containsMouse ? 1.14 : 1.0
                        Behavior on scale { NumberAnimation { duration: 150; easing.type: Easing.OutCubic } }

                        Text {
                            anchors.centerIn: parent
                            text: "skip_next"
                            font.family: Theme.fontIcon
                            font.pixelSize: 15
                            color: nextMouse.containsMouse ? root.colTeal : "#D0D6E0"
                        }

                        MouseArea {
                            id: nextMouse
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: LyricsService.skipNext()
                        }
                    }

                    // Total Duration Readout
                    Text {
                        text: (LyricsService.totalLength > 0) ? LyricsService.formatTime(LyricsService.totalLength) : "--:--"
                        font.family: "JetBrainsMono Nerd Font"
                        font.pixelSize: 9
                        color: root.colFgDim
                    }
                }
            }
        }

        // Caption: Date & Weekday below the nucleus
        Text {
            anchors.horizontalCenter: parent.horizontalCenter
            anchors.top: parent.bottom
            anchors.topMargin: (LyricsService.hasTrack && root.activeMode === "hub") ? 148 : 82
            Behavior on anchors.topMargin { NumberAnimation { duration: 280; easing.type: Easing.OutCubic } }
            visible: root.hubProgress > 0.1 && root.activeMode !== "wallpapers"
            opacity: root.hubProgress
            text: root.dateCaptionStr
            font.family: "Valley Sans"
            font.pixelSize: 12
            font.bold: true
            color: root.colFgDim
        }

        /* ══════════════════════════════════════════════════════════════════════
           PHASE 3: Keyboard-First App Search (Inside Launch Lobe space)
           ══════════════════════════════════════════════════════════════════════ */
        Item {
            id: appSearchContainer
            anchors.centerIn: parent
            visible: root.activeMode === "appsearch"
            width: 320
            height: 280

            ColumnLayout {
                anchors.centerIn: parent
                spacing: 8

                // Search field pill
                Rectangle {
                    Layout.alignment: Qt.AlignHCenter
                    width: 220
                    height: 32
                    radius: 16
                    color: Qt.rgba(root.colBgDark.r, root.colBgDark.g, root.colBgDark.b, 0.90)
                    border.color: root.colPurple
                    border.width: 1.5

                    RowLayout {
                        anchors.fill: parent
                        anchors.leftMargin: 10
                        anchors.rightMargin: 10
                        spacing: 6

                        Text {
                            text: "search"
                            font.family: Theme.fontIcon
                            font.pixelSize: 14
                            color: root.colPurple
                        }

                        TextInput {
                            id: appSearchInput
                            Layout.fillWidth: true
                            font.family: "Valley Sans"
                            font.pixelSize: 12
                            color: "#ffffff"
                            clip: true
                            onTextChanged: root.filterApps(text)
                            Keys.onReturnPressed: {
                                if (appMatches.count > 0) {
                                    root.launchApp(appMatches.get(0).entry)
                                }
                            }
                        }
                    }
                }

                // Circular app result chips arranged in an organic arc around lobe
                ListView {
                    id: appListView
                    Layout.alignment: Qt.AlignHCenter
                    width: 240
                    height: 140
                    clip: true
                    model: ListModel { id: appMatches }
                    delegate: Rectangle {
                        width: 240
                        height: 28
                        radius: 14
                        color: index === 0 ? Qt.rgba(root.colPurple.r, root.colPurple.g, root.colPurple.b, 0.3) : "transparent"
                        border.color: index === 0 ? root.colPurple : "transparent"
                        border.width: 1

                        RowLayout {
                            anchors.fill: parent
                            anchors.leftMargin: 12
                            anchors.rightMargin: 12
                            spacing: 8

                            Text {
                                text: model.name
                                font.family: "Valley Sans"
                                font.pixelSize: 11
                                font.bold: true
                                color: "#ffffff"
                            }
                        }

                        MouseArea {
                            anchors.fill: parent
                            cursorShape: Qt.PointingHandCursor
                            onClicked: root.launchApp(model.entry)
                        }
                    }
                }
            }
        }

        /* ══════════════════════════════════════════════════════════════════════
           PHASE 4: Special Wallhaven Circular Wallpaper Picker
           16 circular thumbnail orbs: 6 inner (radius 62), 10 outer (radius 108, offset 18°)
           ══════════════════════════════════════════════════════════════════════ */
        Item {
            id: wallpaperRingSystem
            anchors.centerIn: parent
            visible: root.activeMode === "wallpapers"
            opacity: root.activeMode === "wallpapers" ? 1.0 : 0.0
            Behavior on opacity { NumberAnimation { duration: 280; easing.type: Easing.OutCubic } }

            // Ring rotation angles with inertia
            property real innerRingAngle: 0.0
            property real outerRingAngle: 18.0

            // Inner Ring Guides
            Rectangle {
                anchors.centerIn: parent
                width: 184; height: 184; radius: 92
                color: "transparent"
                border.color: Qt.rgba(root.colTeal.r, root.colTeal.g, root.colTeal.b, 0.15)
                border.width: 1
            }

            // Outer Ring Guides
            Rectangle {
                anchors.centerIn: parent
                width: 324; height: 324; radius: 162
                color: "transparent"
                border.color: Qt.rgba(root.colTeal.r, root.colTeal.g, root.colTeal.b, 0.12)
                border.width: 1
            }

            // Drag MouseArea for horizontal inertia rotation
            MouseArea {
                anchors.centerIn: parent
                width: 440
                height: 440
                hoverEnabled: true
                property real lastX: 0
                onPressed: mouse => lastX = mouse.x
                onPositionChanged: mouse => {
                    if (pressed) {
                        var dx = mouse.x - lastX
                        lastX = mouse.x
                        wallpaperRingSystem.innerRingAngle += dx * 0.4
                        wallpaperRingSystem.outerRingAngle -= dx * 0.28
                    }
                }
            }

            // ── Inner Ring: 6 Thumbnail Orbs (Radius 92) ──
            Repeater {
                model: 6
                delegate: Item {
                    required property int index
                    readonly property real baseDeg: index * 60.0
                    readonly property real curDeg: baseDeg + wallpaperRingSystem.innerRingAngle
                    readonly property real rad: curDeg * (Math.PI / 180.0)
                    readonly property var wpData: root.wallpapersList[index]

                    x: 92 * Math.cos(rad) - width / 2
                    y: 92 * Math.sin(rad) - height / 2
                    width: 52
                    height: 52

                    Rectangle {
                        anchors.fill: parent
                        radius: width / 2
                        color: root.colBgDark
                        border.color: root.colTeal
                        border.width: 1.8
                        clip: true

                        Image {
                            anchors.fill: parent
                            source: wpData ? wpData.thumb : ""
                            fillMode: Image.PreserveAspectCrop
                            asynchronous: true
                            sourceSize.width: 104
                            sourceSize.height: 104
                        }

                        MouseArea {
                            anchors.fill: parent
                            cursorShape: Qt.PointingHandCursor
                            onClicked: {
                                if (wpData) root.applyWallpaper(wpData)
                            }
                        }
                    }
                }
            }

            // ── Outer Ring: 10 Thumbnail Orbs (Radius 162, offset 18°) ──
            Repeater {
                model: 10
                delegate: Item {
                    required property int index
                    readonly property real baseDeg: 18.0 + (index * 36.0)
                    readonly property real curDeg: baseDeg + wallpaperRingSystem.outerRingAngle
                    readonly property real rad: curDeg * (Math.PI / 180.0)
                    readonly property var wpData: root.wallpapersList[6 + index]

                    x: 162 * Math.cos(rad) - width / 2
                    y: 162 * Math.sin(rad) - height / 2
                    width: 58
                    height: 58

                    Rectangle {
                        anchors.fill: parent
                        radius: width / 2
                        color: root.colBgDark
                        border.color: root.colTeal
                        border.width: 1.8
                        clip: true

                        Image {
                            anchors.fill: parent
                            source: wpData ? wpData.thumb : ""
                            fillMode: Image.PreserveAspectCrop
                            asynchronous: true
                            sourceSize.width: 116
                            sourceSize.height: 116
                        }

                        MouseArea {
                            anchors.fill: parent
                            cursorShape: Qt.PointingHandCursor
                            onClicked: {
                                if (wpData) root.applyWallpaper(wpData)
                            }
                        }
                    }
                }
            }

            // Bottom Search Field Pill
            Rectangle {
                anchors.horizontalCenter: parent.horizontalCenter
                y: 205
                width: 280
                height: 36
                radius: 18
                color: Qt.rgba(root.colBgDark.r, root.colBgDark.g, root.colBgDark.b, 0.92)
                border.color: root.colTeal
                border.width: 1.5

                RowLayout {
                    anchors.fill: parent
                    anchors.leftMargin: 12
                    anchors.rightMargin: 12
                    spacing: 6

                    Text {
                        text: "search"
                        font.family: Theme.fontIcon
                        font.pixelSize: 13
                        color: root.colTeal
                    }

                    TextInput {
                        id: wpSearchInput
                        Layout.fillWidth: true
                        font.family: "Valley Sans"
                        font.pixelSize: 11
                        color: "#ffffff"
                        clip: true
                        onTextChanged: wpDebounce.restart()
                        Keys.onReturnPressed: root.fetchWallpapers(text)
                    }
                }
            }
        }
    }

    /* ── Wallpaper Backend Processes (Reusing Wallhaven.py) ── */
    property var wallpapersList: []
    readonly property string wallhavenScript: (Quickshell.env("HOME") || "") + "/.config/hypr/scripts/wallhaven.py"

    Timer {
        id: wpDebounce
        interval: 700
        onTriggered: root.fetchWallpapers(wpSearchInput.text)
    }

    function fetchWallpapers(query) {
        var args = [root.wallhavenScript, "search", "--sort", "toplist", "--page", "1"]
        if (query && query.trim().length > 0) {
            args.push("--query", query.trim())
        }
        wpSearchProc.command = args
        wpSearchProc.running = true
    }

    function shuffleWallpaperQuery() {
        var queries = ["cyberpunk", "minimalism", "space", "anime", "nature", "neon", "abstract"]
        var q = queries[Math.floor(Math.random() * queries.length)]
        wpSearchInput.text = q
        fetchWallpapers(q)
    }

    Process {
        id: wpSearchProc
        property string buffer: ""
        onRunningChanged: {
            if (running) {
                buffer = ""
            } else if (buffer.trim().length > 0) {
                try {
                    var res = JSON.parse(buffer)
                    if (res && res.success && Array.isArray(res.data)) {
                        root.wallpapersList = res.data
                    }
                } catch (e) {}
            }
        }
        stdout: SplitParser {
            onRead: chunk => wpSearchProc.buffer += chunk + "\n"
        }
    }

    function applyWallpaper(item) {
        if (!item) return
        if (item.is_local) {
            wpApplyProc.command = [root.wallhavenScript, "apply", item.path]
            wpApplyProc.running = true
        } else {
            wpDownloadProc.command = [root.wallhavenScript, "download", item.url, item.filename]
            wpDownloadProc.running = true
        }
        root.close()
    }

    Process {
        id: wpApplyProc
        command: []
    }
    Process {
        id: wpDownloadProc
        command: []
    }

    /* ── App Scanning & Filtering Logic (Reusing DesktopEntries) ── */
    property var allAppsList: []
    function refreshAppList() {
        const values = DesktopEntries.applications.values || []
        const list = []
        for (let i = 0; i < values.length; i++) {
            const e = values[i]
            if (e.noDisplay || !e.name || !e.command || e.command.length === 0) continue
            list.push(e)
        }
        list.sort((a, b) => a.name.localeCompare(b.name))
        root.allAppsList = list
        filterApps("")
    }

    function filterApps(needle) {
        appMatches.clear()
        const n = (needle || "").trim().toLowerCase()
        let count = 0
        for (let i = 0; i < root.allAppsList.length && count < 8; i++) {
            const a = root.allAppsList[i]
            if (n.length === 0 || a.name.toLowerCase().includes(n)) {
                appMatches.append({ name: a.name, entry: a })
                count++
            }
        }
    }

    function launchApp(entry) {
        if (!entry) return
        if (entry.runInTerminal) {
            Quickshell.execDetached(["kitty", "-e", "sh", "-c", entry.command.join(" ")])
        } else {
            entry.execute()
        }
        root.close()
    }
}
