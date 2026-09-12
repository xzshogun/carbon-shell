import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import Quickshell.Services.Mpris
import "../Singletons"
import "../components"

/**
 * SmallMusicOverlay: Minimalist floating music card with album art, track info,
 * full transport buttons (Previous, Play/Pause, Next), and interactive progress/seek bar.
 */
Item {
    id: root

    implicitWidth: 320
    implicitHeight: 128
    width: 320
    height: 128

    signal closeRequested()

    readonly property var activePlayer: LyricsService.activePlayer
    readonly property bool isPlaying: LyricsService.isPlaying
    readonly property bool hasTrack: LyricsService.hasTrack
    readonly property real currentPosition: LyricsService.currentPosition
    readonly property real totalLength: LyricsService.totalLength
    readonly property real progress: totalLength > 0 ? Math.max(0, Math.min(1.0, currentPosition / totalLength)) : 0.0

    property bool isDragging: false
    property real dragProgress: 0.0
    readonly property real displayProgress: root.isDragging ? root.dragProgress : root.progress
    property bool open: true
    property bool attachedBottom: false
    readonly property bool animatingOut: !root.open && bgCard.opacity > 0.001

    Rectangle {
        id: bgCard
        anchors.fill: parent
        radius: 16
        color: Qt.rgba(0.08, 0.09, 0.12, 0.97)
        border.color: root.open ? Theme.accentLit : Qt.rgba(Theme.accent.r, Theme.accent.g, Theme.accent.b, 0.35)
        border.width: 1
        Behavior on border.color { ColorAnimation { duration: root.open ? 350 : 150; easing.type: Easing.OutQuad } }

        transformOrigin: !root.attachedBottom ? Item.Top : Item.Bottom
        transform: Translate {
            y: root.open ? 0 : (!root.attachedBottom ? -18 : 18)
            Behavior on y {
                NumberAnimation {
                    duration: root.open ? 280 : 150
                    easing.type: root.open ? Easing.OutExpo : Easing.InQuad
                }
            }
        }
        scale: root.open ? 1.0 : 0.90
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

        /* Ambient accent glow border */
        Rectangle {
            anchors.fill: parent
            radius: 16
            color: "transparent"
            border.color: Qt.rgba(1, 1, 1, 0.06)
            border.width: 1
        }

        Column {
            anchors.fill: parent
            anchors.margins: 10
            spacing: 6

            /* ── Top Row: Album Art + Track Info + Close Button ── */
            Row {
                width: parent.width
                spacing: 10

                /* Album Art / Vinyl Placeholder */
                Rectangle {
                    width: 38
                    height: 38
                    radius: 8
                    color: Qt.rgba(0.12, 0.14, 0.18, 0.9)
                    border.color: Qt.rgba(Theme.accent.r, Theme.accent.g, Theme.accent.b, 0.3)
                    border.width: 1
                    clip: true
                    anchors.verticalCenter: parent.verticalCenter

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
                        font.pixelSize: 14
                        color: root.isPlaying ? Theme.accent : Qt.rgba(Theme.fg.r, Theme.fg.g, Theme.fg.b, 0.5)
                        visible: !LyricsService.artUrl || LyricsService.artUrl === ""
                    }
                }

                /* Track Title & Artist */
                Column {
                    width: parent.width - 38 - 20 - 20
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: 2

                    Text {
                        width: parent.width
                        text: root.hasTrack ? LyricsService.trackTitle : "No Media Playing"
                        font.pixelSize: 11
                        font.bold: true
                        font.family: "Inter"
                        color: Theme.fg
                        elide: Text.ElideRight
                    }

                    Text {
                        width: parent.width
                        text: root.hasTrack ? (LyricsService.trackArtist || "Unknown Artist") : "Waiting for playback..."
                        font.pixelSize: 9
                        font.family: "Inter"
                        color: Theme.accent
                        elide: Text.ElideRight
                    }
                }

                /* Close Button */
                Rectangle {
                    width: 20
                    height: 20
                    radius: 10
                    color: closeArea.containsMouse ? Qt.rgba(1, 0.3, 0.3, 0.28) : Qt.rgba(1, 1, 1, 0.08)
                    anchors.verticalCenter: parent.verticalCenter

                    Text {
                        anchors.centerIn: parent
                        text: "\uf00d"
                        font.family: "Font Awesome 6 Free"
                        font.weight: Font.Black
                        font.pixelSize: 8
                        color: closeArea.containsMouse ? "#ff5555" : Qt.rgba(Theme.fg.r, Theme.fg.g, Theme.fg.b, 0.7)
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

            /* ── Middle Row: Playback Control Buttons (Prev, Play/Pause, Next) ── */
            Row {
                anchors.horizontalCenter: parent.horizontalCenter
                spacing: 16

                /* Previous */
                Rectangle {
                    width: 28
                    height: 28
                    radius: 14
                    color: prevHov.containsMouse ? Qt.rgba(1, 1, 1, 0.14) : "transparent"
                    anchors.verticalCenter: parent.verticalCenter

                    Text {
                        anchors.centerIn: parent
                        text: "\uf048"
                        font.family: "Font Awesome 6 Free"
                        font.weight: Font.Black
                        font.pixelSize: 11
                        color: prevHov.containsMouse ? Theme.accent : Theme.fg
                    }

                    MouseArea {
                        id: prevHov
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: LyricsService.skipPrevious()
                    }
                }

                /* Play / Pause */
                Rectangle {
                    width: 32
                    height: 32
                    radius: 16
                    color: playHov.containsMouse ? Theme.accentLit : Theme.accent
                    anchors.verticalCenter: parent.verticalCenter

                    Text {
                        anchors.centerIn: parent
                        text: root.isPlaying ? "\uf04c" : "\uf04b"
                        font.family: "Font Awesome 6 Free"
                        font.weight: Font.Black
                        font.pixelSize: 12
                        color: Theme.bg
                    }

                    MouseArea {
                        id: playHov
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: LyricsService.togglePlaying()
                    }
                }

                /* Next */
                Rectangle {
                    width: 28
                    height: 28
                    radius: 14
                    color: nextHov.containsMouse ? Qt.rgba(1, 1, 1, 0.14) : "transparent"
                    anchors.verticalCenter: parent.verticalCenter

                    Text {
                        anchors.centerIn: parent
                        text: "\uf051"
                        font.family: "Font Awesome 6 Free"
                        font.weight: Font.Black
                        font.pixelSize: 11
                        color: nextHov.containsMouse ? Theme.accent : Theme.fg
                    }

                    MouseArea {
                        id: nextHov
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: LyricsService.skipNext()
                    }
                }
            }

            /* ── Bottom Row: Draggable Wavy Progress Bar & Live Time Labels ── */
            Column {
                width: parent.width
                spacing: 2

                /* Scrubber Track */
                Item {
                    id: scrubArea
                    width: parent.width
                    height: 16

                    /* Unfilled Track Background */
                    Rectangle {
                        anchors.left: knob.right
                        anchors.leftMargin: 2
                        anchors.right: parent.right
                        anchors.verticalCenter: parent.verticalCenter
                        height: 2
                        radius: 1
                        color: Qt.rgba(1, 1, 1, 0.14)
                        visible: root.totalLength > 0 && root.displayProgress < 0.99
                    }

                    /* Interactive Wavy Fill */
                    WavyLine {
                        anchors.left: parent.left
                        anchors.right: knob.left
                        anchors.rightMargin: 1
                        anchors.verticalCenter: parent.verticalCenter
                        height: 12
                        visible: root.totalLength > 0 && root.displayProgress > 0.005
                        color: Theme.accent
                        lineWidth: 2
                        amplitudeMultiplier: 0.8 + 0.8 * root.displayProgress
                        frequency: 3 + 6 * root.displayProgress
                        fullLength: Math.max(1, parent.width)
                        running: root.isPlaying || root.isDragging
                    }

                    /* Scrubber Knob */
                    Rectangle {
                        id: knob
                        width: 8
                        height: 8
                        radius: 4
                        color: scrubMouse.containsMouse || root.isDragging ? "#ffffff" : Theme.accent
                        border.color: Theme.accent
                        border.width: 1
                        anchors.verticalCenter: parent.verticalCenter
                        visible: root.totalLength > 0
                        x: Math.max(0, Math.min(parent.width - width, root.displayProgress * (parent.width - width)))
                        scale: root.isDragging ? 1.4 : (scrubMouse.containsMouse ? 1.2 : 1.0)
                        Behavior on scale { NumberAnimation { duration: 100 } }
                    }

                    /* Draggable Mouse Area */
                    MouseArea {
                        id: scrubMouse
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        preventStealing: true

                        onPressed: mouse => {
                            root.isDragging = true
                            seekFromMouse(mouse.x)
                        }

                        onPositionChanged: mouse => {
                            if (pressed) {
                                seekFromMouse(mouse.x)
                            }
                        }

                        onReleased: mouse => {
                            seekFromMouse(mouse.x)
                            root.isDragging = false
                        }

                        onCanceled: {
                            root.isDragging = false
                        }

                        function seekFromMouse(mouseX) {
                            if (root.totalLength > 0) {
                                const ratio = Math.max(0.0, Math.min(1.0, mouseX / width))
                                root.dragProgress = ratio
                                const targetSec = Math.floor(ratio * root.totalLength)
                                try {
                                    if (root.activePlayer && root.activePlayer.positionSupported) {
                                        root.activePlayer.position = targetSec
                                    }
                                } catch (e) {}
                                Quickshell.execDetached(["playerctl", "position", String(targetSec)])
                                if (root.activePlayer && root.activePlayer.positionSupported)
                                    root.activePlayer.positionChanged()
                            }
                        }
                    }
                }

                /* Time Labels */
                Item {
                    width: parent.width
                    height: 10

                    Text {
                        anchors.left: parent.left
                        anchors.verticalCenter: parent.verticalCenter
                        text: {
                            const cur = root.isDragging ? (root.dragProgress * root.totalLength) : root.currentPosition
                            return LyricsService.formatTime(cur)
                        }
                        font.pixelSize: 8
                        font.family: "JetBrains Mono"
                        color: Qt.rgba(Theme.fg.r, Theme.fg.g, Theme.fg.b, 0.6)
                    }

                    Text {
                        anchors.right: parent.right
                        anchors.verticalCenter: parent.verticalCenter
                        text: LyricsService.formatTime(root.totalLength)
                        font.pixelSize: 8
                        font.family: "JetBrains Mono"
                        color: Qt.rgba(Theme.fg.r, Theme.fg.g, Theme.fg.b, 0.6)
                    }
                }
            }
        }
    }
}
