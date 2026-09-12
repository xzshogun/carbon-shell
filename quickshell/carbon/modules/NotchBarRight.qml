import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import Quickshell.Services.Pipewire
import Quickshell.Services.UPower
import Quickshell.Services.SystemTray
import M3Shapes
import "../Singletons"
import "../components"

/**
 * NotchBarRight: Top-attached curved notch for Right side
 *   - Control/Mixer button
 *   - Distro/VC status badge
 *   - Weather badge (cloud icon + temp)
 *   - Volume badge (speaker icon + %)
 *   - Wi-Fi and Bluetooth status indicators
 *   - Notification Bell with unread badge counter
 *   - Battery icon with hover trigger for Caelestia wavy popup
 *   - Power menu button
 */
NotchContainer {
    id: root

    implicitHeight: 34
    earWidth: 20
    contentSpacing: 7

    property int notifCount: 0

    signal openMixer()
    signal closeMixer()
    signal toggleMixer()
    signal openBrightness()
    signal closeBrightness()
    signal toggleBrightness()
    signal openBattery()
    signal closeBattery()
    signal toggleBattery()
    signal openNotif()
    signal closeNotif()
    signal toggleNotif()
    signal openPower()

    /* ── Audio Sink State ────────────────────────────────────────────── */
    readonly property var audioSink: Pipewire.defaultAudioSink
    readonly property real volume: audioSink && audioSink.audio ? audioSink.audio.volume : 0.0
    readonly property bool muted: audioSink && audioSink.audio ? audioSink.audio.muted : false
    readonly property int volumePct: Math.round(root.volume * 100)

    readonly property string volumeGlyph: {
        if (root.muted) return "\uf6a9"
        if (root.volume > 0.5) return "\uf028"
        if (root.volume > 0.0) return "\uf027"
        return "\uf026"
    }

    /* ── Battery State ───────────────────────────────────────────────── */
    readonly property var battery: UPower.displayDevice
    readonly property bool hasBattery: battery ? battery.isPresent : false
    readonly property real batteryPct: battery ? battery.percentage : 1.0
    readonly property bool isCharging: battery ? battery.state === UPowerDeviceState.Charging : false

    readonly property string batteryGlyph: {
        if (root.isCharging) return "\uf0e7"
        if (root.batteryPct > 0.8) return "\uf240"
        if (root.batteryPct > 0.5) return "\uf241"
        if (root.batteryPct > 0.2) return "\uf242"
        return "\uf243"
    }

    /* ── System Tray for Background App Mini Icons ──────────────────── */
    readonly property var trayItems: SystemTray.items.values.filter(function (it) {
        var key = ((it.id || "") + " " + (it.title || "") + " " + (it.tooltipTitle || "")).toLowerCase()
        return !/(nm[ _-]?applet|blueman)/.test(key)
    })

    /* ── Content Inside Notch ────────────────────────────────────────── */
    content: [
        /* 0. System Tray: Mini Icons of Running Background Apps */
        Row {
            anchors.verticalCenter: parent.verticalCenter
            spacing: 5
            visible: root.trayItems.length > 0

            Repeater {
                model: root.trayItems
                delegate: Item {
                    id: slot
                    required property var modelData
                    required property int index

                    width: 18
                    height: 18

                    Rectangle {
                        anchors.fill: parent
                        radius: 4
                        color: trayHov.containsMouse ? Theme.bgHover : "transparent"
                    }

                    Image {
                        anchors.centerIn: parent
                        source: slot.modelData.icon
                        sourceSize: Qt.size(16, 16)
                        width: 16
                        height: 16
                        fillMode: Image.PreserveAspectFit
                    }

                    MouseArea {
                        id: trayHov
                        anchors.fill: parent
                        hoverEnabled: true
                        acceptedButtons: Qt.LeftButton | Qt.RightButton
                        cursorShape: Qt.PointingHandCursor
                        onClicked: function (mouse) {
                            if (mouse.button === Qt.RightButton) {
                                if (slot.modelData.hasMenu)
                                    slot.modelData.openMenu(mouse.x, mouse.y)
                                else
                                    slot.modelData.secondaryActivate()
                            } else {
                                slot.modelData.activate()
                            }
                        }
                    }
                }
            }
        },

        /* Divider after tray if tray has items */
        Rectangle {
            width: 1
            height: 14
            anchors.verticalCenter: parent.verticalCenter
            color: Qt.alpha(Theme.fg, 0.15)
            visible: root.trayItems.length > 0
        },

        /* 1. Volume (Speaker glyph) */
        Item {
            id: volBadge
            width: 22
            height: 22
            anchors.verticalCenter: parent.verticalCenter
            readonly property bool isHovered: volMouse.containsMouse

            scale: isHovered ? 1.18 : 1.0
            y: isHovered ? -2 : 0
            Behavior on scale { NumberAnimation { duration: 240; easing.type: Easing.OutBack; easing.overshoot: 1.4 } }
            Behavior on y { NumberAnimation { duration: 240; easing.type: Easing.OutBack; easing.overshoot: 1.4 } }

            // Ambient glowing halo morphing into unique Flower shape
            MaterialShape {
                anchors.centerIn: parent
                width: parent.width + 8
                height: parent.height + 8
                shape: volBadge.isHovered ? MaterialShape.Flower : MaterialShape.Circle
                animationDuration: 260
                animationEasing: Easing.OutBack
                color: volBadge.isHovered ? (root.muted ? Qt.rgba(Theme.err.r, Theme.err.g, Theme.err.b, 0.25) : Qt.rgba(Theme.accent.r, Theme.accent.g, Theme.accent.b, 0.25)) : "transparent"
                scale: volBadge.isHovered ? 1.12 : 0.6
                opacity: volBadge.isHovered ? 1.0 : 0.0
                rotation: volBadge.isHovered ? -4 : 0
                Behavior on opacity { NumberAnimation { duration: 180 } }
                Behavior on scale { NumberAnimation { duration: 240; easing.type: Easing.OutBack } }
                Behavior on rotation { NumberAnimation { duration: 260; easing.type: Easing.OutBack } }
            }

            // Tactile highlight chip morphing into unique Flower shape
            MaterialShape {
                anchors.fill: parent
                shape: volBadge.isHovered ? MaterialShape.Flower : MaterialShape.Circle
                animationDuration: 260
                animationEasing: Easing.OutBack
                color: volBadge.isHovered ? Theme.bgHover : "transparent"
                strokeColor: volBadge.isHovered ? (root.muted ? Qt.rgba(Theme.err.r, Theme.err.g, Theme.err.b, 0.45) : Qt.rgba(Theme.accent.r, Theme.accent.g, Theme.accent.b, 0.35)) : "transparent"
                strokeWidth: 1.2
                rotation: volBadge.isHovered ? -4 : 0
                Behavior on color { ColorAnimation { duration: 120 } }
                Behavior on strokeColor { ColorAnimation { duration: 120 } }
                Behavior on rotation { NumberAnimation { duration: 260; easing.type: Easing.OutBack } }
            }

            Text {
                anchors.centerIn: parent
                text: root.volumeGlyph
                font.family: Theme.font
                font.pixelSize: 12
                color: root.muted ? Theme.err : (volBadge.isHovered ? Theme.accent : Theme.fg)
                scale: volBadge.isHovered ? 1.12 : 1.0
                Behavior on scale { NumberAnimation { duration: 180; easing.type: Easing.OutBack } }
            }

            MouseArea {
                id: volMouse
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onEntered: root.openMixer()
                onExited: root.closeMixer()
                onClicked: root.toggleMixer()
            }
        },

        /* 2. Display Brightness Icon (Sun glyph, hover/click to open brightness) */
        Item {
            id: brightBadge
            width: 22
            height: 22
            anchors.verticalCenter: parent.verticalCenter
            readonly property bool isHovered: brightMouse.containsMouse

            scale: isHovered ? 1.18 : 1.0
            y: isHovered ? -2 : 0
            Behavior on scale { NumberAnimation { duration: 240; easing.type: Easing.OutBack; easing.overshoot: 1.4 } }
            Behavior on y { NumberAnimation { duration: 240; easing.type: Easing.OutBack; easing.overshoot: 1.4 } }

            // Ambient glowing halo morphing into unique Sunny shape
            MaterialShape {
                anchors.centerIn: parent
                width: parent.width + 8
                height: parent.height + 8
                shape: brightBadge.isHovered ? MaterialShape.Sunny : MaterialShape.Circle
                animationDuration: 260
                animationEasing: Easing.OutBack
                color: brightBadge.isHovered ? Qt.rgba(Theme.accentLit.r, Theme.accentLit.g, Theme.accentLit.b, 0.25) : "transparent"
                scale: brightBadge.isHovered ? 1.12 : 0.6
                opacity: brightBadge.isHovered ? 1.0 : 0.0
                rotation: brightBadge.isHovered ? 15 : 0
                Behavior on opacity { NumberAnimation { duration: 180 } }
                Behavior on scale { NumberAnimation { duration: 240; easing.type: Easing.OutBack } }
                Behavior on rotation { NumberAnimation { duration: 260; easing.type: Easing.OutBack } }
            }

            // Tactile highlight chip morphing into unique Sunny shape
            MaterialShape {
                anchors.fill: parent
                shape: brightBadge.isHovered ? MaterialShape.Sunny : MaterialShape.Circle
                animationDuration: 260
                animationEasing: Easing.OutBack
                color: brightBadge.isHovered ? Theme.bgHover : "transparent"
                strokeColor: brightBadge.isHovered ? Qt.rgba(Theme.accentLit.r, Theme.accentLit.g, Theme.accentLit.b, 0.45) : "transparent"
                strokeWidth: 1.2
                rotation: brightBadge.isHovered ? 15 : 0
                Behavior on color { ColorAnimation { duration: 120 } }
                Behavior on strokeColor { ColorAnimation { duration: 120 } }
                Behavior on rotation { NumberAnimation { duration: 260; easing.type: Easing.OutBack } }
            }

            Text {
                anchors.centerIn: parent
                text: "\uf185" // Sun glyph
                font.family: Theme.font
                font.pixelSize: 12
                color: brightBadge.isHovered ? Theme.accentLit : Theme.fg
                scale: brightBadge.isHovered ? 1.12 : 1.0
                rotation: brightBadge.isHovered ? 25 : 0
                Behavior on scale { NumberAnimation { duration: 180; easing.type: Easing.OutBack } }
                Behavior on rotation { NumberAnimation { duration: 300; easing.type: Easing.OutBack } }
            }

            MouseArea {
                id: brightMouse
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onEntered: root.openBrightness()
                onExited: root.closeBrightness()
                onClicked: root.toggleBrightness()
            }
        },


        /* 7. Notification Bell with Unread Dot & DND 'z' Indicator */
        Item {
            id: notifBadge
            width: 22
            height: 22
            anchors.verticalCenter: parent.verticalCenter
            readonly property bool isHovered: notifMouse.containsMouse

            scale: isHovered ? 1.18 : 1.0
            y: isHovered ? -2 : 0
            Behavior on scale { NumberAnimation { duration: 240; easing.type: Easing.OutBack; easing.overshoot: 1.4 } }
            Behavior on y { NumberAnimation { duration: 240; easing.type: Easing.OutBack; easing.overshoot: 1.4 } }

            // Ambient glowing halo morphing into unique Clover4Leaf shape
            MaterialShape {
                anchors.centerIn: parent
                width: parent.width + 8
                height: parent.height + 8
                shape: notifBadge.isHovered ? MaterialShape.Clover4Leaf : MaterialShape.Circle
                animationDuration: 260
                animationEasing: Easing.OutBack
                color: notifBadge.isHovered ? Qt.rgba(Theme.accent.r, Theme.accent.g, Theme.accent.b, 0.25) : "transparent"
                scale: notifBadge.isHovered ? 1.12 : 0.6
                opacity: notifBadge.isHovered ? 1.0 : 0.0
                rotation: notifBadge.isHovered ? -10 : 0
                Behavior on opacity { NumberAnimation { duration: 180 } }
                Behavior on scale { NumberAnimation { duration: 240; easing.type: Easing.OutBack } }
                Behavior on rotation { NumberAnimation { duration: 260; easing.type: Easing.OutBack } }
            }

            // Tactile highlight chip morphing into unique Clover4Leaf shape
            MaterialShape {
                anchors.fill: parent
                shape: notifBadge.isHovered ? MaterialShape.Clover4Leaf : MaterialShape.Circle
                animationDuration: 260
                animationEasing: Easing.OutBack
                color: notifBadge.isHovered ? Theme.bgHover : "transparent"
                strokeColor: notifBadge.isHovered ? Qt.rgba(Theme.accent.r, Theme.accent.g, Theme.accent.b, 0.40) : "transparent"
                strokeWidth: 1.2
                rotation: notifBadge.isHovered ? -10 : 0
                Behavior on color { ColorAnimation { duration: 120 } }
                Behavior on strokeColor { ColorAnimation { duration: 120 } }
                Behavior on rotation { NumberAnimation { duration: 260; easing.type: Easing.OutBack } }
            }

            Item {
                id: notifIconBox
                anchors.centerIn: parent
                width: 14
                height: 14
                rotation: notifBadge.isHovered ? -12 : 0
                scale: notifBadge.isHovered ? 1.12 : 1.0
                Behavior on rotation { NumberAnimation { duration: 240; easing.type: Easing.OutBack; easing.overshoot: 1.8 } }
                Behavior on scale { NumberAnimation { duration: 180; easing.type: Easing.OutBack } }

                Text {
                    anchors.centerIn: parent
                    text: "\uf0f3"
                    font.family: Theme.font
                    font.pixelSize: 12
                    color: Theme.dnd ? Theme.fgDim : (notifBadge.isHovered ? Theme.accent : (root.notifCount > 0 ? Theme.accent : Theme.fg))
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
                id: notifMouse
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onEntered: root.openNotif()
                onExited: root.closeNotif()
                onClicked: root.toggleNotif()
            }
        },

        /* 8. Battery Pill Icon */
        Item {
            id: batBadge
            width: 24
            height: 20
            anchors.verticalCenter: parent.verticalCenter
            visible: root.hasBattery
            readonly property bool isHovered: batMouse.containsMouse

            scale: isHovered ? 1.18 : 1.0
            y: isHovered ? -2 : 0
            Behavior on scale { NumberAnimation { duration: 240; easing.type: Easing.OutBack; easing.overshoot: 1.4 } }
            Behavior on y { NumberAnimation { duration: 240; easing.type: Easing.OutBack; easing.overshoot: 1.4 } }

            // Ambient glowing halo morphing into unique Gem shape
            MaterialShape {
                anchors.centerIn: parent
                width: parent.width + 8
                height: parent.height + 8
                shape: batBadge.isHovered ? MaterialShape.Gem : MaterialShape.Circle
                animationDuration: 260
                animationEasing: Easing.OutBack
                color: batBadge.isHovered ? (root.isCharging ? Qt.rgba(Theme.accentLit.r, Theme.accentLit.g, Theme.accentLit.b, 0.25) : Qt.rgba(Theme.accent.r, Theme.accent.g, Theme.accent.b, 0.25)) : "transparent"
                scale: batBadge.isHovered ? 1.12 : 0.6
                opacity: batBadge.isHovered ? 1.0 : 0.0
                rotation: batBadge.isHovered ? 8 : 0
                Behavior on opacity { NumberAnimation { duration: 180 } }
                Behavior on scale { NumberAnimation { duration: 240; easing.type: Easing.OutBack } }
                Behavior on rotation { NumberAnimation { duration: 260; easing.type: Easing.OutBack } }
            }

            // Tactile highlight chip morphing into unique Gem shape
            MaterialShape {
                anchors.fill: parent
                shape: batBadge.isHovered ? MaterialShape.Gem : MaterialShape.Circle
                animationDuration: 260
                animationEasing: Easing.OutBack
                color: batBadge.isHovered ? Theme.bgHover : "transparent"
                strokeColor: batBadge.isHovered ? (root.isCharging ? Qt.rgba(Theme.accentLit.r, Theme.accentLit.g, Theme.accentLit.b, 0.45) : Qt.rgba(Theme.accent.r, Theme.accent.g, Theme.accent.b, 0.40)) : "transparent"
                strokeWidth: 1.2
                rotation: batBadge.isHovered ? 8 : 0
                Behavior on color { ColorAnimation { duration: 120 } }
                Behavior on strokeColor { ColorAnimation { duration: 120 } }
                Behavior on rotation { NumberAnimation { duration: 260; easing.type: Easing.OutBack } }
            }

            Text {
                anchors.centerIn: parent
                text: root.batteryGlyph
                font.family: Theme.font
                font.pixelSize: 12
                color: root.isCharging ? Theme.accentLit : (root.batteryPct < 0.2 ? Theme.err : (batBadge.isHovered ? Theme.accent : Theme.fg))
                scale: batBadge.isHovered ? 1.12 : 1.0
                Behavior on scale { NumberAnimation { duration: 180; easing.type: Easing.OutBack } }
            }

            MouseArea {
                id: batMouse
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onEntered: root.openBattery()
                onExited: root.closeBattery()
                onClicked: root.toggleBattery()
            }
        },

        /* 9. Power Menu Button */
        Item {
            id: pwrBadge
            width: 24
            height: 24
            anchors.verticalCenter: parent.verticalCenter
            readonly property bool isHovered: pwrMouse.containsMouse

            scale: isHovered ? 1.18 : 1.0
            y: isHovered ? -2 : 0
            Behavior on scale { NumberAnimation { duration: 240; easing.type: Easing.OutBack; easing.overshoot: 1.4 } }
            Behavior on y { NumberAnimation { duration: 240; easing.type: Easing.OutBack; easing.overshoot: 1.4 } }

            // Ambient glowing halo morphing into unique Heart shape
            MaterialShape {
                anchors.centerIn: parent
                width: parent.width + 8
                height: parent.height + 8
                shape: pwrBadge.isHovered ? MaterialShape.Heart : MaterialShape.Circle
                animationDuration: 260
                animationEasing: Easing.OutBack
                color: pwrBadge.isHovered ? Qt.rgba(Theme.err.r, Theme.err.g, Theme.err.b, 0.28) : "transparent"
                scale: pwrBadge.isHovered ? 1.12 : 0.6
                opacity: pwrBadge.isHovered ? 1.0 : 0.0
                rotation: pwrBadge.isHovered ? 8 : 0
                Behavior on opacity { NumberAnimation { duration: 180 } }
                Behavior on scale { NumberAnimation { duration: 240; easing.type: Easing.OutBack } }
                Behavior on rotation { NumberAnimation { duration: 260; easing.type: Easing.OutBack } }
            }

            // Tactile highlight chip morphing into unique Heart shape
            MaterialShape {
                anchors.fill: parent
                shape: pwrBadge.isHovered ? MaterialShape.Heart : MaterialShape.Circle
                animationDuration: 260
                animationEasing: Easing.OutBack
                color: pwrBadge.isHovered ? Qt.alpha(Theme.err, 0.22) : "transparent"
                strokeColor: pwrBadge.isHovered ? Qt.rgba(Theme.err.r, Theme.err.g, Theme.err.b, 0.45) : "transparent"
                strokeWidth: 1.2
                rotation: pwrBadge.isHovered ? 8 : 0
                Behavior on color { ColorAnimation { duration: 120 } }
                Behavior on strokeColor { ColorAnimation { duration: 120 } }
                Behavior on rotation { NumberAnimation { duration: 260; easing.type: Easing.OutBack } }
            }

            Text {
                anchors.centerIn: parent
                text: "\uf011"
                font.family: Theme.font
                font.pixelSize: 11
                color: pwrBadge.isHovered ? Theme.err : Theme.fgDim
                scale: pwrBadge.isHovered ? 1.12 : 1.0
                Behavior on scale { NumberAnimation { duration: 180; easing.type: Easing.OutBack } }
            }

            MouseArea {
                id: pwrMouse
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: root.openPower()
            }
        }
    ]
}
