import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import Quickshell.Services.Mpris
import Quickshell.Services.Pipewire
import "../Singletons"
import "../components"

/**
 * SmallMusicOverlay: Modern OneUI / Android 13/14 styled floating media overlay.
 * Features:
 *  - Output device badge / Spotify header
 *  - Album art background blur + rounded album thumbnail
 *  - Track title & artist typography
 *  - Animated wavy visualizer & interactive progress scrubber
 *  - 5-button transport controls (Shuffle, Prev, Play/Pause, Next, Loop)
 */
Item {
    id: root

    implicitWidth: 340
    implicitHeight: 180
    width: 340
    height: 180

    signal closeRequested()

    readonly property var activePlayer: LyricsService.activePlayer
    readonly property bool isPlaying: LyricsService.isPlaying
    readonly property bool hasTrack: LyricsService.hasTrack
    readonly property real currentPosition: LyricsService.currentPosition
    readonly property real totalLength: LyricsService.totalLength

    property bool open: true
    property bool attachedBottom: false
    readonly property bool animatingOut: !root.open && bgCard.opacity > 0.001

    readonly property string deviceName: {
        if (Pipewire.defaultAudioSink && Pipewire.defaultAudioSink.description && Pipewire.defaultAudioSink.description.length > 0) {
            return Pipewire.defaultAudioSink.description
        }
        if (activePlayer && activePlayer.identity && activePlayer.identity.length > 0) {
            return activePlayer.identity
        }
        return "Audio Output"
    }

    readonly property bool isSpotify: activePlayer && activePlayer.identity && activePlayer.identity.toLowerCase().includes("spotify")

    Rectangle {
        id: bgCard
        anchors.fill: parent
        radius: 18
        color: Qt.rgba(0.08, 0.09, 0.12, 0.95)
        border.color: root.open ? Qt.rgba(Theme.accentLit.r, Theme.accentLit.g, Theme.accentLit.b, 0.35) : Qt.rgba(1, 1, 1, 0.08)
        border.width: 1
        clip: true

        Behavior on border.color {
            ColorAnimation { duration: root.open ? 300 : 150; easing.type: Easing.OutQuad }
        }

        transformOrigin: !root.attachedBottom ? Item.Top : Item.Bottom
        transform: Translate {
            y: root.open ? 0 : (!root.attachedBottom ? -16 : 16)
            Behavior on y {
                NumberAnimation {
                    duration: root.open ? 280 : 150
                    easing.type: root.open ? Easing.OutExpo : Easing.InQuad
                }
            }
        }
        scale: root.open ? 1.0 : 0.92
        opacity: root.open ? 1.0 : 0.0
        Behavior on scale {
            NumberAnimation {
                duration: root.open ? 280 : 150
                easing.type: root.open ? Easing.OutExpo : Easing.InQuad
            }
        }
        Behavior on opacity {
            NumberAnimation {
                duration: root.open ? 200 : 130
                easing.type: root.open ? Easing.OutCubic : Easing.InQuad
            }
        }

        /* ── Subtle blurred/dimmed album art ambient background ───────── */
        Image {
            anchors.fill: parent
            source: LyricsService.artUrl
            fillMode: Image.PreserveAspectCrop
            opacity: 0.14
            visible: status === Image.Ready && source != ""
        }

        /* ── Ambient Inner Border Highlight ───────────────────────────── */
        Rectangle {
            anchors.fill: parent
            radius: 18
            color: "transparent"
            border.color: Qt.rgba(1, 1, 1, 0.06)
            border.width: 1
        }

        ColumnLayout {
            anchors.fill: parent
            anchors.margins: 12
            spacing: 6

            /* ── 1. Top Header Row: Device / App Badge + Close Button ── */
            RowLayout {
                Layout.fillWidth: true
                spacing: 6

                RowLayout {
                    Layout.fillWidth: true
                    spacing: 6

                    // App / Device Icon
                    Text {
                        text: "music_note"
                        font.family: Theme.fontIcon
                        font.pixelSize: 14
                        color: Theme.accentLit
                    }

                    // Device Name (e.g. boAt Rockerz 400 / Galaxy Buds2 Pro)
                    Text {
                        Layout.fillWidth: true
                        text: root.deviceName
                        font.family: "Inter"
                        font.pixelSize: 10
                        font.weight: Font.DemiBold
                        color: Qt.rgba(Theme.fg.r, Theme.fg.g, Theme.fg.b, 0.78)
                        elide: Text.ElideRight
                    }
                }

                // Close Button
                Rectangle {
                    Layout.preferredWidth: 20
                    Layout.preferredHeight: 20
                    radius: 10
                    color: closeArea.containsMouse ? Qt.rgba(1, 0.3, 0.3, 0.28) : Qt.rgba(1, 1, 1, 0.08)

                    Text {
                        anchors.centerIn: parent
                        text: "close"
                        font.family: Theme.fontIcon
                        font.pixelSize: 14
                        color: closeArea.containsMouse ? "#ff5555" : Qt.rgba(Theme.fg.r, Theme.fg.g, Theme.fg.b, 0.65)
                    }

                    MouseArea {
                        id: closeArea
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: root.closeRequested()
                    }
                }
            }

            /* ── 2. Middle Row: Track Title & Artist + Album Art Thumbnail ── */
            RowLayout {
                Layout.fillWidth: true
                spacing: 10

                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 2

                    Text {
                        Layout.fillWidth: true
                        text: root.hasTrack ? LyricsService.trackTitle : "No Media Playing"
                        font.family: "Inter"
                        font.pixelSize: 13
                        font.weight: Font.Bold
                        color: Theme.fg
                        elide: Text.ElideRight
                    }

                    Text {
                        Layout.fillWidth: true
                        text: root.hasTrack ? (LyricsService.trackArtist || "Unknown Artist") : "Waiting for playback..."
                        font.family: "Inter"
                        font.pixelSize: 10
                        font.weight: Font.Normal
                        color: Theme.accent
                        elide: Text.ElideRight
                    }
                }

                // Album Art Thumbnail
                Rectangle {
                    Layout.preferredWidth: 42
                    Layout.preferredHeight: 42
                    radius: 9
                    color: Qt.rgba(0.12, 0.14, 0.18, 0.9)
                    border.color: Qt.rgba(Theme.accentLit.r, Theme.accentLit.g, Theme.accentLit.b, 0.35)
                    border.width: 1
                    clip: true

                    Image {
                        anchors.fill: parent
                        source: LyricsService.artUrl
                        fillMode: Image.PreserveAspectCrop
                        visible: status === Image.Ready && source != ""
                    }

                    Text {
                        anchors.centerIn: parent
                        text: "music_note"
                        font.family: Theme.fontIcon
                        font.pixelSize: 18
                        color: root.isPlaying ? Theme.accentLit : Qt.rgba(Theme.fg.r, Theme.fg.g, Theme.fg.b, 0.45)
                        visible: !LyricsService.artUrl || LyricsService.artUrl === ""
                    }
                }
            }

            /* ── 3. Animated Wavy Visualizer & Interactive Progress Bar ─ */
            WavySeekBar {
                Layout.fillWidth: true
                waveHeight: 16
                barHeight: 8
                timeLabelSize: 8
                accentColor: Theme.accent
                accentLitColor: Theme.accentLit
            }

            /* ── 4. Transport Controls Row (Shuffle, Prev, Play/Pause, Next, Loop) ── */
            RowLayout {
                Layout.fillWidth: true
                Layout.alignment: Qt.AlignHCenter

                Item { Layout.fillWidth: true }

                // Shuffle
                Rectangle {
                    Layout.preferredWidth: 26
                    Layout.preferredHeight: 26
                    radius: 13
                    color: shufArea.containsMouse ? Qt.rgba(1, 1, 1, 0.12) : "transparent"

                    Text {
                        anchors.centerIn: parent
                        text: "shuffle"
                        font.family: Theme.fontIcon
                        font.pixelSize: 14
                        color: shufArea.containsMouse ? Theme.accentLit : Qt.rgba(Theme.fg.r, Theme.fg.g, Theme.fg.b, 0.65)
                    }

                    MouseArea {
                        id: shufArea
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: Quickshell.execDetached(["playerctl", "shuffle", "Toggle"])
                    }
                }

                Item { Layout.preferredWidth: 8 }

                // Previous
                Rectangle {
                    Layout.preferredWidth: 28
                    Layout.preferredHeight: 28
                    radius: 14
                    color: prevArea.containsMouse ? Qt.rgba(1, 1, 1, 0.12) : "transparent"

                    Text {
                        anchors.centerIn: parent
                        text: "skip_previous"
                        font.family: Theme.fontIcon
                        font.pixelSize: 18
                        color: prevArea.containsMouse ? Theme.accentLit : Theme.fg
                    }

                    MouseArea {
                        id: prevArea
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: LyricsService.skipPrevious()
                    }
                }

                Item { Layout.preferredWidth: 8 }

                // Play / Pause (Accent filled circle)
                Rectangle {
                    Layout.preferredWidth: 34
                    Layout.preferredHeight: 34
                    radius: 17
                    color: playArea.containsMouse ? Theme.accentLit : Theme.accent
                    border.color: Theme.accentLit
                    border.width: 1

                    Text {
                        anchors.centerIn: parent
                        text: root.isPlaying ? "pause" : "play_arrow"
                        font.family: Theme.fontIcon
                        font.pixelSize: 18
                        color: Theme.isDark ? "#121118" : "#ffffff"
                    }

                    MouseArea {
                        id: playArea
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: LyricsService.togglePlaying()
                    }
                }

                Item { Layout.preferredWidth: 8 }

                // Next
                Rectangle {
                    Layout.preferredWidth: 28
                    Layout.preferredHeight: 28
                    radius: 14
                    color: nextArea.containsMouse ? Qt.rgba(1, 1, 1, 0.12) : "transparent"

                    Text {
                        anchors.centerIn: parent
                        text: "skip_next"
                        font.family: Theme.fontIcon
                        font.pixelSize: 18
                        color: nextArea.containsMouse ? Theme.accentLit : Theme.fg
                    }

                    MouseArea {
                        id: nextArea
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: LyricsService.skipNext()
                    }
                }

                Item { Layout.preferredWidth: 8 }

                // Loop / Repeat
                Rectangle {
                    Layout.preferredWidth: 26
                    Layout.preferredHeight: 26
                    radius: 13
                    color: loopArea.containsMouse ? Qt.rgba(1, 1, 1, 0.12) : "transparent"

                    Text {
                        anchors.centerIn: parent
                        text: "repeat"
                        font.family: Theme.fontIcon
                        font.pixelSize: 14
                        color: loopArea.containsMouse ? Theme.accentLit : Qt.rgba(Theme.fg.r, Theme.fg.g, Theme.fg.b, 0.65)
                    }

                    MouseArea {
                        id: loopArea
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: Quickshell.execDetached(["playerctl", "loop", "Track"])
                    }
                }

                Item { Layout.fillWidth: true }
            }
        }
    }
}
