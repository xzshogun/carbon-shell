import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import Quickshell.Hyprland
import Quickshell.Services.Mpris
import Quickshell.Services.Pipewire
import "../Singletons"

Item {
    id: root

    implicitWidth: 104
    implicitHeight: 104

    signal toggleCenterDashboard()
    signal openLauncher()
    signal toggleMixer()

    property alias hitBox: orbBody

    /* ── Date / Time Logic ── */
    property var currentTime: new Date()
    Timer {
        interval: 1000
        repeat: true
        running: true
        onTriggered: root.currentTime = new Date()
    }

    readonly property string timeStr: {
        var h = root.currentTime.getHours()
        var m = root.currentTime.getMinutes()
        return (h < 10 ? "0" + h : h) + ":" + (m < 10 ? "0" + m : m)
    }
    readonly property string secStr: {
        var s = root.currentTime.getSeconds()
        return (s < 10 ? "0" + s : s)
    }

    /* ── System Telemetry (Excitation Level) ── */
    property int cpuUsage: 0
    property real lastCpuTotal: 0
    property real lastCpuIdle: 0

    Process {
        id: sysProbe
        command: ["awk", "/^cpu / {print $2+$3+$4+$5+$6+$7+$8, $5+$6} END {}", "/proc/stat"]
        running: false
        stdout: StdioCollector {
            id: sysOut
            waitForEnd: true
        }
        onExited: {
            var raw = sysOut.text.trim().split("\n")
            if (raw.length >= 2) {
                var cpuParts = raw[0].trim().split(/\s+/)
                if (cpuParts.length >= 2) {
                    var total = parseFloat(cpuParts[0])
                    var idle = parseFloat(cpuParts[1])
                    if (root.lastCpuTotal > 0 && total > root.lastCpuTotal) {
                        var dTotal = total - root.lastCpuTotal
                        var dIdle = idle - root.lastCpuIdle
                        root.cpuUsage = Math.max(0, Math.min(100, Math.round((1.0 - (dIdle / dTotal)) * 100)))
                    }
                    root.lastCpuTotal = total
                    root.lastCpuIdle = idle
                }
            }
        }
    }

    Timer {
        interval: 2500
        repeat: true
        running: true
        triggeredOnStart: true
        onTriggered: sysProbe.running = true
    }

    /* ── Audio Pipewire ── */
    readonly property var audioSink: Pipewire.defaultAudioSink
    readonly property real volume: audioSink && audioSink.audio ? audioSink.audio.volume : 0.0

    function stepVolume(delta) {
        if (audioSink && audioSink.audio) {
            audioSink.audio.volume = Math.max(0.0, Math.min(1.0, audioSink.audio.volume + delta))
        }
    }

    /* ── MPRIS Control ── */
    readonly property var mprisPlayer: Mpris.players.values.length > 0 ? Mpris.players.values[0] : null
    readonly property bool mprisPlaying: mprisPlayer && mprisPlayer.playbackState === MprisPlaybackState.Playing

    function togglePlayPause() {
        if (mprisPlayer && mprisPlayer.canControl) {
            mprisPlayer.playPause()
        }
    }

    /* ── Quantum Orbital Mechanics ── */
    property real orbitPhase: 0.0
    property real nucleonPhase: 0.0

    Timer {
        interval: 20
        repeat: true
        running: true
        onTriggered: {
            var speedMul = (orbMouse.containsMouse ? 2.2 : 1.0) + (root.cpuUsage / 100.0)
            root.orbitPhase = (root.orbitPhase + 0.035 * speedMul) % (Math.PI * 2)
            root.nucleonPhase = (root.nucleonPhase + 0.02 * speedMul) % (Math.PI * 2)
            quantumCanvas.requestPaint()
        }
    }

    /* ── Main Interactive Orb Body ── */
    Item {
        id: orbBody
        anchors.centerIn: parent
        width: 96
        height: 96

        scale: orbMouse.containsMouse ? 1.08 : 1.0
        Behavior on scale {
            NumberAnimation { duration: 250; easing.type: Easing.OutBack; easing.overshoot: 1.4 }
        }

        // Ambient glow halo
        Rectangle {
            anchors.centerIn: parent
            width: 94
            height: 94
            radius: 47
            color: "transparent"
            border.color: Theme.accent
            border.width: orbMouse.containsMouse ? 2 : 1
            opacity: orbMouse.containsMouse ? 0.45 : (0.15 + (root.cpuUsage / 200.0))

            Behavior on opacity {
                NumberAnimation { duration: 200 }
            }
        }

        // Outer Canvas: Orbital Track & Revolving Electrons/Quanta
        Canvas {
            id: quantumCanvas
            anchors.fill: parent

            onPaint: {
                var ctx = getContext("2d")
                ctx.clearRect(0, 0, width, height)

                var cx = width / 2
                var cy = height / 2
                var rOuter = 44

                // 1. Dotted orbital track
                ctx.beginPath()
                ctx.arc(cx, cy, rOuter, 0, Math.PI * 2)
                ctx.strokeStyle = Theme.isDark ? "rgba(255, 255, 255, 0.15)" : "rgba(0, 0, 0, 0.15)"
                ctx.lineWidth = 1.2
                ctx.setLineDash([3, 4])
                ctx.stroke()
                ctx.setLineDash([])

                // 2. Revolving valence electrons
                var numElectrons = 2
                for (var i = 0; i < numElectrons; i++) {
                    var angle = root.orbitPhase + (i * Math.PI)
                    var ex = cx + rOuter * Math.cos(angle)
                    var ey = cy + rOuter * Math.sin(angle)

                    // Glow halo around electron
                    ctx.beginPath()
                    ctx.arc(ex, ey, 3.8, 0, Math.PI * 2)
                    ctx.fillStyle = Theme.accent
                    ctx.globalAlpha = 0.35
                    ctx.fill()

                    // Core electron bead
                    ctx.beginPath()
                    ctx.arc(ex, ey, 2.0, 0, Math.PI * 2)
                    ctx.fillStyle = Theme.accent
                    ctx.globalAlpha = 0.95
                    ctx.fill()
                }

                // 3. Nucleon particle cloud
                var numNucleons = 12
                var coreR = 26
                ctx.globalAlpha = 0.4
                for (var j = 0; j < numNucleons; j++) {
                    var nAngle = root.nucleonPhase * 0.7 + (j * (Math.PI * 2 / numNucleons))
                    var jitter = Math.sin(root.nucleonPhase * 2 + j) * 3
                    var dist = coreR - 2 + jitter
                    var nx = cx + dist * Math.cos(nAngle)
                    var ny = cy + dist * Math.sin(nAngle)

                    ctx.beginPath()
                    ctx.arc(nx, ny, 1.3, 0, Math.PI * 2)
                    ctx.fillStyle = (j % 2 === 0) ? Theme.accent : Theme.fgDim
                    ctx.fill()
                }
                ctx.globalAlpha = 1.0
            }
        }

        // Central Carbon Nucleus Solid Core
        Rectangle {
            id: nucleusCenter
            anchors.centerIn: parent
            width: 72
            height: 72
            radius: 36
            color: Theme.isDark ? "#101216" : "#f4f6fa"
            border.color: orbMouse.containsMouse ? Theme.accent : Theme.outline
            border.width: orbMouse.containsMouse ? 1.6 : 1.2

            Behavior on border.color {
                ColorAnimation { duration: 180 }
            }

            Rectangle {
                anchors.fill: parent
                radius: parent.radius
                color: Theme.accent
                opacity: orbMouse.containsMouse ? 0.12 : 0.05

                Behavior on opacity {
                    NumberAnimation { duration: 180 }
                }
            }

            Column {
                anchors.centerIn: parent
                spacing: 1

                Row {
                    anchors.horizontalCenter: parent.horizontalCenter
                    spacing: 1

                    Text {
                        text: root.timeStr
                        font.family: "JetBrainsMono Nerd Font"
                        font.pixelSize: 13
                        font.weight: Font.Bold
                        color: Theme.fg
                    }

                    Text {
                        text: ":" + root.secStr
                        font.family: "JetBrainsMono Nerd Font"
                        font.pixelSize: 8
                        font.weight: Font.Bold
                        color: Theme.accent
                        anchors.baseline: parent.children[0].baseline
                    }
                }

                Text {
                    anchors.horizontalCenter: parent.horizontalCenter
                    text: root.mprisPlaying ? "♫ ACTIVE" : "¹²C · Z=6"
                    font.family: "JetBrainsMono Nerd Font"
                    font.pixelSize: 7
                    font.weight: Font.Bold
                    color: root.mprisPlaying ? Theme.accent : Theme.fgDim
                }
            }
        }

        MouseArea {
            id: orbMouse
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            acceptedButtons: Qt.LeftButton | Qt.RightButton | Qt.MiddleButton

            onClicked: (mouse) => {
                if (mouse.button === Qt.RightButton) {
                    root.togglePlayPause()
                } else if (mouse.button === Qt.MiddleButton) {
                    root.openLauncher()
                } else {
                    root.toggleCenterDashboard()
                }
            }

            onWheel: (wheel) => {
                if (wheel.angleDelta.y > 0) {
                    root.stepVolume(0.04)
                } else if (wheel.angleDelta.y < 0) {
                    root.stepVolume(-0.04)
                }
            }
        }
    }
}
