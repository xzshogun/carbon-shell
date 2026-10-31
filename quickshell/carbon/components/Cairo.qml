import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import Quickshell.Services.Mpris
import "../Singletons"

/**
 * Cairo.qml:
 * High-performance Hybrid Kinetic Lyric Engine for Carbon Shell.
 * Powered by the Rust cairo-engine backend (dual LRCLIB/Netease waterfall),
 * native hardware MPRIS clock sync, and buttery fluid scrolling physics.
 */
Item {
    id: root

    property bool isSynced: false

    // Native MPRIS Player Resolution
    readonly property var playersList: (Mpris.players && Mpris.players.values !== undefined) ? Mpris.players.values : (Mpris.players || [])
    readonly property var primaryPlayer: (playersList && playersList.length > 0) ? playersList[0] : null

    // Native MPRIS Clock Binding in milliseconds (Hardware-accurate, zero timer drift)
    property int currentAudioMs: {
        if (!primaryPlayer || primaryPlayer.position === undefined) return 0
        var pos = primaryPlayer.position
        if (pos > 100000) return Math.floor(pos / 1000)
        if (pos > 5000) return Math.floor(pos)
        return Math.floor(pos * 1000)
    }

    // ── 1. The Rust Engine Pipe ─────────────────────────────────────────────
    ListModel {
        id: cairoModel
    }

    Process {
        id: cairoEngineProc
        command: [
            "sh", "-c",
            "if command -v cairo-engine >/dev/null 2>&1; then exec cairo-engine; elif [ -x \"$HOME/.local/bin/cairo-engine\" ]; then exec \"$HOME/.local/bin/cairo-engine\"; elif [ -x \"$HOME/.cargo/bin/cairo-engine\" ]; then exec \"$HOME/.cargo/bin/cairo-engine\"; else exec cairo-engine; fi"
        ]
        running: true

        stdout: SplitParser {
            splitMarker: "\n"
            onRead: function(line) {
                var raw = (line || "").trim()
                if (!raw) return
                try {
                    var msg = JSON.parse(raw)
                    if (!msg) return
                    root.isSynced = Boolean(msg.synced)
                    cairoModel.clear()
                    if (Array.isArray(msg.lines)) {
                        for (var i = 0; i < msg.lines.length; i++) {
                            var item = msg.lines[i]
                            cairoModel.append({
                                time: Number(item.time) || 0,
                                text: String(item.text || "")
                            })
                        }
                    }
                    lyricList.updateIndexFromClock()
                } catch (e) {
                    console.warn("[Cairo.qml] Error parsing cairo-engine JSON output:", e)
                }
            }
        }

        stderr: SplitParser {
            splitMarker: "\n"
            onRead: function(errLine) {
                console.warn("[cairo-engine stderr]", errLine)
            }
        }
    }

    // ── 2. The Fluid ListView: Buttery Physics & Hardware Sync ──────────────
    ListView {
        id: lyricList
        anchors.fill: parent
        clip: true
        model: cairoModel
        spacing: Theme.px(16)
        interactive: true
        boundsBehavior: Flickable.StopAtBounds

        // Buttery "up and down" scrolling: lock active item to vertical center
        preferredHighlightBegin: height / 2 - Theme.px(30)
        preferredHighlightEnd: height / 2 + Theme.px(30)
        highlightRangeMode: root.isSynced ? ListView.StrictlyEnforceRange : ListView.NoHighlightRange
        highlightMoveDuration: 450 // Smooth vertical glide

        // Dynamically update currentIndex based on hardware clock
        property int currentAudioMs: root.currentAudioMs
        onCurrentAudioMsChanged: updateIndexFromClock()
        onCountChanged: updateIndexFromClock()

        function updateIndexFromClock() {
            if (!root.isSynced || count === 0) return
            var target = -1
            for (let i = count - 1; i >= 0; i--) {
                var item = model.get(i)
                if (item && root.currentAudioMs >= item.time) {
                    target = i
                    break
                }
            }
            if (target >= 0) {
                if (currentIndex !== target) currentIndex = target
            } else {
                if (currentIndex !== 0) currentIndex = 0
            }
        }

        Connections {
            target: root
            function onIsSyncedChanged() {
                if (root.isSynced) {
                    lyricList.updateIndexFromClock()
                }
            }
        }

        delegate: Item {
            id: lineDelegate
            required property int index
            required property var model

            width: lyricList.width
            height: lyricText.implicitHeight + Theme.px(24)
            property bool isActive: ListView.isCurrentItem && root.isSynced && (root.currentAudioMs >= model.time)

            // The Highlight Pill Background
            Rectangle {
                id: highlightPill
                anchors.centerIn: lyricText
                readonly property real textWidth: Math.min(lyricText.implicitWidth, lineDelegate.width - Theme.px(48))
                width: lineDelegate.isActive ? (textWidth + Theme.px(32)) : textWidth
                height: lyricText.implicitHeight + Theme.px(16)
                radius: Theme.tokens.rounding.medium
                color: Theme.accent
                opacity: lineDelegate.isActive ? 1.0 : 0.0
                scale: lineDelegate.isActive ? 1.0 : 0.9

                Behavior on width {
                    NumberAnimation {
                        duration: 350
                        easing.type: Easing.OutBack
                        easing.overshoot: 1.2
                    }
                }
                Behavior on opacity {
                    NumberAnimation {
                        duration: 250
                    }
                }
                Behavior on scale {
                    NumberAnimation {
                        duration: 350
                        easing.type: Easing.OutBack
                    }
                }
            }

            // The Lyric Text
            Text {
                id: lyricText
                anchors.centerIn: parent
                text: lineDelegate.model.text
                font.family: Theme.font
                font.pixelSize: lineDelegate.isActive ? Theme.fontPx(36) : (root.isSynced ? Theme.fontPx(28) : Theme.fontPx(24))
                font.weight: lineDelegate.isActive ? Font.Bold : Font.Medium
                color: lineDelegate.isActive
                       ? (Theme.m3onPrimaryContainer || Theme.accentContrast || Theme.fg)
                       : (root.isSynced ? Qt.rgba(Theme.fg.r, Theme.fg.g, Theme.fg.b, 0.50) : Qt.rgba(Theme.fg.r, Theme.fg.g, Theme.fg.b, 0.85))
                horizontalAlignment: Text.AlignHCenter
                wrapMode: Text.WordWrap
                width: Math.min(implicitWidth, lineDelegate.width - Theme.px(48))

                Behavior on font.pixelSize {
                    NumberAnimation {
                        duration: 300
                        easing.type: Easing.OutCubic
                    }
                }
                Behavior on color {
                    ColorAnimation {
                        duration: 250
                    }
                }
            }
        }

        // Empty State Placeholder (when no track or lyrics loaded)
        Rectangle {
            anchors.centerIn: parent
            width: Theme.px(240)
            height: Theme.px(80)
            radius: Theme.tokens.rounding.medium
            color: Qt.rgba(Theme.m3surfaceContainerLowest.r, Theme.m3surfaceContainerLowest.g, Theme.m3surfaceContainerLowest.b, 0.40)
            border.color: Theme.outline
            border.width: Theme.px(1)
            visible: cairoModel.count === 0

            ColumnLayout {
                anchors.centerIn: parent
                spacing: Theme.px(6)
                Text {
                    text: "󰎈"
                    font.family: Theme.fontMono
                    font.pixelSize: Theme.fontPx(22)
                    color: Qt.rgba(Theme.primary.r, Theme.primary.g, Theme.primary.b, 0.50)
                    Layout.alignment: Qt.AlignHCenter
                }
                Text {
                    text: "Waiting for playback..."
                    font.family: Theme.font
                    font.pixelSize: Theme.fontPx(12)
                    color: Theme.fgDim
                    Layout.alignment: Qt.AlignHCenter
                }
            }
        }
    }
}
