import QtQuick
import QtQuick.Layouts
import QtQuick.Effects
import Quickshell
import Quickshell.Io
import Quickshell.Services.UPower
import "../Singletons"
import "../components"

/**
 * Caelestia-Style Wavy Liquid Battery Popup
 * Vertical pill with animated sinusoidal waves across the liquid fill surface,
 * live percentage, charging animation, health metrics, and power profile selector.
 */
Item {
    id: root

    property bool open: false
    property string barEdge: "top"
    property bool hovered: false

    readonly property var battery: UPower.displayDevice
    readonly property bool hasBattery: battery ? battery.isPresent : false
    readonly property real batteryPct: battery ? battery.percentage : 1.0
    readonly property int batteryState: battery ? battery.state : UPowerDeviceState.FullyCharged
    readonly property bool isCharging: batteryState === UPowerDeviceState.Charging
    readonly property bool isFull: batteryState === UPowerDeviceState.FullyCharged || root.batteryPct >= 0.99

    /* Smooth battery percentage for fluid liquid level animation */
    property real animatedPct: root.batteryPct
    Behavior on animatedPct { NumberAnimation { duration: 600; easing.type: Easing.OutCubic } }

    /* Power profile state */
    property string activeProfile: "balanced"

    Process {
        id: profileGetProc
        command: ["powerprofilesctl", "get"]
        stdout: SplitParser {
            onRead: (line) => {
                const p = line.trim()
                if (p.length > 0) root.activeProfile = p
            }
        }
    }

    Timer {
        interval: 3000
        running: root.open
        repeat: true
        triggeredOnStart: true
        onTriggered: profileGetProc.running = true
    }

    function setProfile(p) {
        root.activeProfile = p
        Quickshell.execDetached(["powerprofilesctl", "set", p])
    }

    /* Formatted battery time */
    readonly property string timeEstimateStr: {
        if (root.isFull) return "Fully Charged"
        if (root.isCharging) {
            if (battery && battery.timeToFull > 0) {
                const hrs = Math.floor(battery.timeToFull / 3600)
                const mins = Math.floor((battery.timeToFull % 3600) / 60)
                return hrs > 0 ? (hrs + "h " + mins + "m until full") : (mins + "m until full")
            }
            return "Charging..."
        }
        if (battery && battery.timeToEmpty > 0) {
            const hrs = Math.floor(battery.timeToEmpty / 3600)
            const mins = Math.floor((battery.timeToEmpty % 3600) / 60)
            return hrs > 0 ? (hrs + "h " + mins + "m remaining") : (mins + "m remaining")
        }
        return "On Battery"
    }

    readonly property color statusColor: {
        if (root.isCharging) return Theme.accentLit
        if (root.batteryPct < 0.20) return Theme.err
        if (root.batteryPct < 0.40) return Theme.warn
        return Theme.accent
    }

    implicitWidth: 260
    implicitHeight: 220
    width: 260
    height: 220

    HoverHandler {
        id: hoverHandler
        onHoveredChanged: root.hovered = hoverHandler.hovered
    }

    Rectangle {
        id: card
        width: parent.width
        height: parent.height
        radius: 18
        color: Theme.bg
        border.color: root.open ? Qt.rgba(Theme.accentLit.r, Theme.accentLit.g, Theme.accentLit.b, 0.45) : Theme.outline
        border.width: 1

        opacity: root.open ? 1 : 0
        x: root.open ? 0 : (root.barEdge === "left" ? -28 : (root.barEdge === "right" ? 28 : 0))
        y: root.open ? 0 : (root.barEdge === "top" ? -20 : (root.barEdge === "bottom" ? 20 : 0))
        scale: root.open ? 1.0 : 0.88
        transformOrigin: root.barEdge === "left" ? Item.BottomLeft :
                         (root.barEdge === "right" ? Item.BottomRight :
                         (root.barEdge === "bottom" ? Item.BottomRight : Item.TopRight))

        Behavior on border.color { ColorAnimation { duration: 200 } }
        Behavior on opacity {
            NumberAnimation { duration: root.open ? 220 : 140; easing.type: Easing.OutCubic }
        }
        Behavior on x {
            NumberAnimation {
                duration: root.open ? 320 : 160
                easing.type: root.open ? Easing.OutBack : Easing.OutCubic
                easing.overshoot: 1.35
            }
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

        RowLayout {
            anchors.fill: parent
            anchors.margins: 12
            spacing: 12
            opacity: root.open ? 1.0 : 0.0
            y: root.open ? 0 : 8
            Behavior on opacity { NumberAnimation { duration: 220; easing.type: Easing.OutCubic } }
            Behavior on y { NumberAnimation { duration: 300; easing.type: Easing.OutBack; easing.overshoot: 1.2 } }

            /* ── Left: Caelestia Wavy Liquid Battery Card ───────────── */
            Rectangle {
                id: wavyCard
                Layout.preferredWidth: 94
                Layout.fillHeight: true
                radius: 16
                color: Qt.alpha(root.statusColor, 0.08)
                border.color: root.isCharging ? root.statusColor : Qt.alpha(root.statusColor, 0.25)
                border.width: root.isCharging ? 1.5 : 1
                clip: true

                Behavior on border.color { ColorAnimation { duration: 250 } }

                /* Wave animation phase state */
                property real wavePhase: 0.0

                Timer {
                    id: waveTimer
                    interval: 33 // ~30 FPS
                    repeat: true
                    running: root.open
                    onTriggered: {
                        wavyCard.wavePhase = (wavyCard.wavePhase + 0.04) % 1000.0
                        waveCanvas.requestPaint()
                    }
                }

                /* Animated Liquid Surface Canvas */
                Canvas {
                    id: waveCanvas
                    anchors.fill: parent

                    onPaint: {
                        const ctx = getContext("2d")
                        ctx.clearRect(0, 0, width, height)

                        const fillPct = Math.min(1.0, Math.max(0.0, root.animatedPct))
                        // Constrain liquid surface between 34px (below header at 100%) and (height - 8) at 0%
                        const minWaterY = 34
                        const maxWaterY = height - 8
                        const waterLevelY = maxWaterY - fillPct * (maxWaterY - minWaterY)
                        const amp = root.isCharging ? 4.5 : 3.2
                        const waveLength = width * 0.85
                        const phase = wavyCard.wavePhase

                        // 1. Secondary background wave (softer, offset)
                        ctx.save()
                        ctx.beginPath()
                        ctx.moveTo(0, height)
                        ctx.lineTo(0, waterLevelY)

                        for (let x = 0; x <= width; x += 2) {
                            const y = waterLevelY + (amp * 0.7) * Math.sin((x / waveLength + phase * 1.3 + 1.5) * Math.PI * 2)
                            ctx.lineTo(x, y)
                        }

                        ctx.lineTo(width, height)
                        ctx.closePath()
                        ctx.fillStyle = Qt.alpha(root.statusColor, 0.28)
                        ctx.fill()
                        ctx.restore()

                        // 2. Primary foreground wave
                        ctx.save()
                        ctx.beginPath()
                        ctx.moveTo(0, height)
                        ctx.lineTo(0, waterLevelY)

                        for (let x = 0; x <= width; x += 2) {
                            const y = waterLevelY + amp * Math.sin((x / waveLength + phase) * Math.PI * 2)
                            ctx.lineTo(x, y)
                        }

                        ctx.lineTo(width, height)
                        ctx.closePath()

                        // Gradient fill for lush liquid depth
                        const grad = ctx.createLinearGradient(0, waterLevelY, 0, height)
                        grad.addColorStop(0.0, Qt.alpha(root.statusColor, 0.6))
                        grad.addColorStop(1.0, Qt.alpha(root.statusColor, 0.9))
                        ctx.fillStyle = grad
                        ctx.fill()

                        // 3. Wavy crest highlight line
                        ctx.beginPath()
                        for (let x = 0; x <= width; x += 2) {
                            const y = waterLevelY + amp * Math.sin((x / waveLength + phase) * Math.PI * 2)
                            if (x === 0) ctx.moveTo(x, y)
                            else ctx.lineTo(x, y)
                        }
                        ctx.strokeStyle = Qt.alpha("#FFFFFF", 0.55)
                        ctx.lineWidth = 1.5
                        ctx.stroke()

                        ctx.restore()
                    }
                }

                /* Card Overlay: Top Icon & "Battery", Bottom Percentage & Status */
                Item {
                    anchors.fill: parent
                    anchors.margins: 10

                    /* Top: Battery icon & "Battery" label */
                    RowLayout {
                        anchors.top: parent.top
                        anchors.left: parent.left
                        anchors.right: parent.right
                        spacing: 5

                        Text {
                            text: root.isCharging ? "\uf0e7" : "\uf240"
                            font.family: Theme.font
                            font.pixelSize: 12
                            font.weight: Font.Bold
                            color: root.isCharging ? root.statusColor : Theme.fg
                        }

                        Text {
                            text: "Battery"
                            font.family: "Valley Sans"
                            font.pixelSize: 12
                            font.weight: Font.DemiBold
                            color: Theme.fg
                            elide: Text.ElideRight
                        }
                    }

                    /* Bottom: Big Percentage & Subtitle */
                    ColumnLayout {
                        anchors.bottom: parent.bottom
                        anchors.left: parent.left
                        anchors.right: parent.right
                        spacing: 1

                        Text {
                            text: Math.round(root.batteryPct * 100) + "%"
                            font.family: "Valley Sans"
                            font.pixelSize: 22
                            font.weight: Font.Bold
                            color: Theme.fg
                        }

                        Text {
                            text: root.isCharging ? "Charging" : (root.isFull ? "Full" : "Discharging")
                            font.family: "Valley Sans"
                            font.pixelSize: 10
                            font.weight: Font.Medium
                            color: Theme.fgDim
                        }
                    }
                }
            }

            /* ── Right: Stats & Power Profiles ──────────────────────── */
            ColumnLayout {
                Layout.fillWidth: true
                Layout.fillHeight: true
                spacing: 8

                /* Header: Status badge */
                RowLayout {
                    Layout.fillWidth: true
                    Item { Layout.fillWidth: true }
                    Rectangle {
                        height: 18
                        width: stateLabel.implicitWidth + 12
                        radius: 9
                        color: Qt.alpha(root.statusColor, 0.18)

                        Text {
                            id: stateLabel
                            anchors.centerIn: parent
                            text: root.isCharging ? "CHARGING" : (root.isFull ? "FULL" : "ON BATTERY")
                            font.family: "Valley Sans"
                            font.pixelSize: 8
                            font.weight: Font.Bold
                            color: root.statusColor
                        }
                    }
                }

                /* Time Remaining & Health */
                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 2

                    Text {
                        text: root.timeEstimateStr
                        font.family: "Valley Sans"
                        font.pixelSize: 11
                        font.weight: Font.DemiBold
                        color: Theme.fg
                        elide: Text.ElideRight
                        Layout.fillWidth: true
                    }

                    Text {
                        text: (battery && battery.energyRate > 0)
                            ? ("Draw: " + battery.energyRate.toFixed(2) + " W")
                            : "Health: 100%"
                        font.family: "Valley Sans"
                        font.pixelSize: 9
                        color: Theme.fgDim
                    }

                    Text {
                        text: (battery && battery.voltage > 0)
                            ? ("Voltage: " + battery.voltage.toFixed(2) + " V")
                            : "DELL CYMGM8A"
                        font.family: "Valley Sans"
                        font.pixelSize: 9
                        color: Theme.fgFaint
                    }
                }

                Rectangle {
                    Layout.fillWidth: true
                    height: 1
                    color: Theme.outline
                }

                /* Power Profiles selector */
                Text {
                    text: "Power Profile"
                    font.family: "Valley Sans"
                    font.pixelSize: 9
                    font.weight: Font.Bold
                    color: Theme.fgDim
                }

                RowLayout {
                    Layout.fillWidth: true
                    spacing: 4

                    Repeater {
                        model: [
                            { id: "power-saver", label: "Quiet", icon: "\uf06c" },
                            { id: "balanced",    label: "Balanced", icon: "\uf24e" },
                            { id: "performance", label: "Max",   icon: "\uf0e7" }
                        ]

                        delegate: Rectangle {
                            id: profBtn
                            required property var modelData
                            required property int index

                            Layout.fillWidth: true
                            Layout.preferredHeight: 26
                            radius: 6

                            readonly property bool isSelected: root.activeProfile === modelData.id
                            color: isSelected ? Theme.accent : (pHov.containsMouse ? Theme.bgHover : "#18FFFFFF")
                            border.color: isSelected ? Theme.accentLit : "transparent"
                            border.width: 1

                            Behavior on color { ColorAnimation { duration: 120 } }

                            Text {
                                anchors.centerIn: parent
                                text: profBtn.modelData.icon
                                font.family: Theme.font
                                font.pixelSize: 12
                                color: profBtn.isSelected ? "#111111" : Theme.fg
                            }

                            MouseArea {
                                id: pHov
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: root.setProfile(profBtn.modelData.id)
                            }
                        }
                    }
                }

                Item { Layout.fillHeight: true }

                Text {
                    text: "Li-ion Battery"
                    font.family: "Valley Sans"
                    font.pixelSize: 8
                    color: Theme.fgFaint
                    Layout.alignment: Qt.AlignRight
                }
            }
        }
    }
}
