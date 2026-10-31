import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import Quickshell.Services.Mpris
import "../Singletons"

/**
 * Cairo.qml:
 * High-performance Hybrid Kinetic Lyric Engine for Carbon Shell.
 * Powered by the Rust cairo-engine backend (dual LRCLIB/Netease waterfall)
 * and native hardware MPRIS clock sync. Zero manual timer drift.
 */
Item {
    id: root

    property bool isSynced: false

    // Native MPRIS Player Resolution (Mpris.players[0] with fallback to values[0])
    readonly property var playersList: (Mpris.players && Mpris.players.values !== undefined) ? Mpris.players.values : (Mpris.players || [])
    readonly property var primaryPlayer: (playersList && playersList.length > 0) ? playersList[0] : null

    // Native MPRIS Clock Binding in milliseconds (Hardware-accurate, zero timer drift)
    property int currentAudioMs: {
        if (!primaryPlayer || primaryPlayer.position === undefined) return 0
        var pos = primaryPlayer.position
        // MPRIS position is reported in microseconds; divide by 1000 to obtain milliseconds
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

    // ── 2. Visual Stage & ListView ──────────────────────────────────────────
    MouseArea {
        id: listMouse
        anchors.fill: parent
        hoverEnabled: true
        acceptedButtons: Qt.NoButton
    }

    ListView {
        id: lyricList
        anchors.fill: parent
        clip: true
        model: cairoModel
        spacing: Theme.px(12)
        interactive: !root.isSynced || listMouse.containsMouse
        boundsBehavior: Flickable.StopAtBounds

        preferredHighlightBegin: height * 0.40
        preferredHighlightEnd: height * 0.60
        highlightRangeMode: root.isSynced ? ListView.ApplyRange : ListView.NoHighlightRange
        highlightMoveDuration: 220

        delegate: Item {
            id: lineDelegate
            required property int index
            required property var model

            width: lyricList.width
            height: lineLayout.implicitHeight + Theme.px(14)

            // Pure native hardware clock evaluation (no timers!):
            // A line is active if song is past this line's timestamp, but hasn't reached the next line's timestamp yet.
            property bool isActive: root.isSynced
                                    ? (root.currentAudioMs >= model.time &&
                                       (index === lyricList.count - 1 || root.currentAudioMs < lyricList.model.get(index + 1).time))
                                    : false

            onIsActiveChanged: {
                if (isActive && root.isSynced) {
                    lyricList.positionViewAtIndex(index, ListView.Center)
                }
            }

            // Signature Cairo Translucent Glass Tape Block
            Rectangle {
                id: highlightTape
                anchors.centerIn: parent
                width: lineText.implicitWidth + Theme.px(36)
                height: lineText.implicitHeight + Theme.px(12)
                radius: Theme.tokens.rounding.small
                color: Qt.rgba(Theme.primary.r, Theme.primary.g, Theme.primary.b, 0.35)
                border.color: Theme.primary
                border.width: Theme.px(1.5)
                opacity: (lineDelegate.isActive && root.isSynced) ? 1.0 : 0.0
                visible: opacity > 0.01

                Behavior on opacity {
                    NumberAnimation { duration: 180; easing.type: Easing.OutQuad }
                }
            }

            RowLayout {
                id: lineLayout
                anchors.centerIn: parent
                spacing: Theme.px(8)

                Text {
                    id: lineText
                    text: lineDelegate.model.text
                    font.family: Theme.font
                    font.weight: lineDelegate.isActive ? Font.Bold : Font.Normal
                    font.pixelSize: lineDelegate.isActive ? Theme.fontPx(18) : Theme.fontPx(15)
                    horizontalAlignment: Text.AlignHCenter
                    wrapMode: Text.WordWrap
                    Layout.maximumWidth: lineDelegate.width - Theme.px(48)
                    color: lineDelegate.isActive
                           ? Theme.m3onPrimaryContainer
                           : (root.isSynced ? Qt.rgba(Theme.fg.r, Theme.fg.g, Theme.fg.b, 0.40) : Theme.fg)
                    scale: lineDelegate.isActive ? 1.04 : 0.96
                    opacity: root.isSynced ? (lineDelegate.isActive ? 1.0 : 0.40) : 1.0

                    // Preserved Cairo Animation Physics
                    Behavior on opacity {
                        NumberAnimation { duration: 200; easing.type: Easing.OutQuad }
                    }
                    Behavior on scale {
                        NumberAnimation { duration: 220; easing.type: Easing.OutBack }
                    }
                    Behavior on color {
                        ColorAnimation { duration: 150; easing.type: Easing.OutQuad }
                    }
                }
            }
        }

        // Empty State Placeholder
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
