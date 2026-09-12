import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import Quickshell.Services.Mpris
import "../Singletons"
import "../components"

/**
 * NotchBarCenter: Top-attached curved notch for Center (Clock & Music)
 *   - Bold two-tone Titan clock (10:19)
 *   - Vertical separator (|)
 *   - Animated spinning vinyl disc / album art
 *   - Two-line track title & artist (Do I Wanna Know? / Arctic Monkeys)
 */
NotchContainer {
    id: root

    implicitHeight: 34
    earWidth: 20
    contentSpacing: 8

    signal openMusicHover()
    signal closeMusicHover()
    signal toggleMusic()
    signal openMusic()

    mouseArea.hoverEnabled: true
    mouseArea.cursorShape: Qt.PointingHandCursor
    mouseArea.acceptedButtons: Qt.LeftButton | Qt.RightButton
    mouseArea.onEntered: root.openMusicHover()
    mouseArea.onExited: root.closeMusicHover()
    mouseArea.onClicked: (mouse) => {
        if (mouse.button === Qt.RightButton) {
            root.togglePlayPause()
        } else {
            root.toggleMusic()
        }
    }

    /* ── Live Clock State ────────────────────────────────────────────── */
    property var currentTime: new Date()
    property int currentHourRaw: currentTime.getHours()
    property int currentHour12: {
        let h = root.currentHourRaw % 12
        return h === 0 ? 12 : h
    }
    property string hourStr: (root.currentHour12 < 10 ? "0" : "") + root.currentHour12
    property string minStr: {
        let m = root.currentTime.getMinutes()
        return (m < 10 ? "0" : "") + m
    }

    Timer {
        interval: 1000
        repeat: true
        running: true
        onTriggered: root.currentTime = new Date()
    }

    /* ── MPRIS State ─────────────────────────────────────────────────── */
    readonly property var players: Mpris.players.values !== undefined ? Mpris.players.values : Mpris.players
    property var activePlayer: null

    function resolveActivePlayer() {
        if (!root.players || root.players.length === 0) return null
        for (let i = 0; i < root.players.length; i++) {
            if (root.players[i].playbackState === MprisPlaybackState.Playing)
                return root.players[i]
        }
        for (let i = 0; i < root.players.length; i++) {
            if (root.players[i].playbackState === MprisPlaybackState.Paused
                && (root.players[i].trackTitle || "").length > 0)
                return root.players[i]
        }
        return root.players[0]
    }

    Timer {
        interval: 1000
        repeat: true
        running: true
        triggeredOnStart: true
        onTriggered: root.activePlayer = root.resolveActivePlayer()
    }

    readonly property string trackTitle: activePlayer ? (activePlayer.trackTitle || "") : ""
    readonly property string trackArtist: activePlayer ? (activePlayer.trackArtist || "") : ""
    readonly property string artUrl: activePlayer ? (activePlayer.trackArtUrl || "") : ""
    readonly property bool isPlaying: activePlayer && activePlayer.playbackState === MprisPlaybackState.Playing
    readonly property bool hasTrack: root.activePlayer !== null && root.trackTitle.trim().length > 0

    function togglePlayPause() {
        if (root.activePlayer) root.activePlayer.togglePlaying()
    }

    property string barContent: "both"

    /* ── Content Inside Notch ────────────────────────────────────────── */
    content: [
        /* 1. Center Island Clock (Dynamic Design) */
        CenterClock {
            anchors.verticalCenter: parent.verticalCenter
            visible: root.barContent !== "music"
        },

        /* 2. Vertical Divider */
        Rectangle {
            width: 1
            height: 16
            color: Qt.alpha(Theme.fg, 0.22)
            anchors.verticalCenter: parent.verticalCenter
            visible: root.barContent === "both"
        },

        /* 3. Music Section (Disc + Track Info) */
        Item {
            anchors.verticalCenter: parent.verticalCenter
            implicitHeight: 26
            implicitWidth: musicRow.implicitWidth
            visible: root.barContent !== "clock"

            Row {
                id: musicRow
                spacing: 8
                anchors.verticalCenter: parent.verticalCenter

                /* Spinning Vinyl Disc / Album art */
                Rectangle {
                    id: discContainer
                    width: 22
                    height: 22
                    radius: 11
                    color: Theme.bgAlt
                    border.color: Theme.accent
                    border.width: 1.5
                    anchors.verticalCenter: parent.verticalCenter
                    clip: true

                    MouseArea {
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: root.togglePlayPause()
                    }

                    Image {
                        id: albumArtImg
                        anchors.fill: parent
                        source: root.artUrl
                        visible: root.hasTrack && root.artUrl.length > 0
                        fillMode: Image.PreserveAspectCrop
                    }

                    Item {
                        id: vinylDisc
                        anchors.fill: parent
                        visible: !root.hasTrack || root.artUrl.length === 0

                        Text {
                            anchors.centerIn: parent
                            text: "\uf51f" // Vinyl record icon
                            font.family: Theme.font
                            font.pixelSize: 12
                            color: Theme.accent
                        }

                        // Subtle inner core
                        Rectangle {
                            anchors.centerIn: parent
                            width: 6
                            height: 6
                            radius: 3
                            color: Theme.bg
                            border.color: Theme.accentLit
                            border.width: 1
                        }

                        // Smooth continuous rotation animation when music is playing
                        NumberAnimation on rotation {
                            from: 0
                            to: 360
                            duration: 4000
                            loops: Animation.Infinite
                            running: root.isPlaying
                        }
                    }
                }

                /* Song & Artist Info (Two lines) */
                Column {
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: 0

                    Text {
                        text: root.hasTrack ? root.trackTitle : "Nothing Playing"
                        font.family: "Valley Sans"
                        font.pixelSize: 10
                        font.weight: Font.Bold
                        color: root.hasTrack ? Theme.fg : Theme.fgDim
                        elide: Text.ElideRight
                        width: Math.min(implicitWidth, 140)
                    }

                    Text {
                        text: root.hasTrack ? root.trackArtist : ""
                        font.family: "Valley Sans"
                        font.pixelSize: 8
                        font.weight: Font.Medium
                        color: Theme.fgDim
                        elide: Text.ElideRight
                        width: Math.min(implicitWidth, 140)
                        visible: text.length > 0
                    }
                }
            }
        }
    ]
}
