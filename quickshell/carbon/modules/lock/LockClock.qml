import QtQuick
import QtQuick.Effects
import Quickshell
import Quickshell.Io
import "../../Singletons"

/**
 * LockClock:
 * Sleek, animated clock with day and date displayed in the bottom-right corner of the lock screen.
 * Matches the styling of the former desktop clock:
 *   - Bold high-contrast time readout
 *   - Day of the week in cursive "Caveat" font
 *   - Clean date string with a sleek vertical divider
 *   - Soft drop shadow for legibility over blurred backgrounds
 *   - Smooth fluid sliding and fading entrance animation
 */
Item {
    id: root

    implicitWidth: clockCol.implicitWidth + 8
    implicitHeight: clockCol.implicitHeight + 8

    property string timeStr: Qt.formatTime(new Date(), "hh:mm")
    property string dayStr: Qt.formatDate(new Date(), "dddd")
    property string dateStr: Qt.formatDate(new Date(), "d MMMM")

    function refresh() {
        var d = new Date()
        root.timeStr = Qt.formatTime(d, "hh:mm")
        root.dayStr = Qt.formatDate(d, "dddd")
        root.dateStr = Qt.formatDate(d, "d MMMM")
    }

    Timer {
        interval: 1000
        running: true
        repeat: true
        triggeredOnStart: true
        onTriggered: root.refresh()
    }

    /* ── Read Lock Screen Configuration ───────────────────────────────────── */
    readonly property string configPath: "/home/shogun/.config/hypr/carbon-lockscreen.json"
    property bool enabledSetting: true

    FileView {
        id: cfgFile
        path: root.configPath
        onFileChanged: root.reloadConfig()
        onLoaded: root.reloadConfig()
    }

    function reloadConfig() {
        try {
            const txt = cfgFile.text().trim()
            if (txt.length > 0) {
                const parsed = JSON.parse(txt)
                if (parsed.clock !== undefined) {
                    root.enabledSetting = parsed.clock
                }
            }
        } catch (e) {}
    }

    Component.onCompleted: root.reloadConfig()

    /* ── Smooth Animated Visibility & Entrance ───────────────────────────── */
    property bool entered: false
    visible: opacity > 0.01
    opacity: (entered && enabledSetting) ? 1.0 : 0.0
    transform: Translate {
        id: transOffset
        y: root.entered ? 0 : 36
        x: root.entered ? 0 : 16

        Behavior on y {
            NumberAnimation {
                duration: 650
                easing.type: Easing.OutCubic
            }
        }
        Behavior on x {
            NumberAnimation {
                duration: 650
                easing.type: Easing.OutCubic
            }
        }
    }

    Behavior on opacity {
        NumberAnimation {
            duration: 520
            easing.type: Easing.OutQuad
        }
    }

    Timer {
        id: introDelay
        interval: 180
        running: true
        onTriggered: root.entered = true
    }

    /* ── Drop Shadow Component ───────────────────────────────────────────── */
    Component {
        id: shadowFx
        MultiEffect {
            shadowEnabled: true
            shadowColor: "#000000"
            shadowOpacity: 0.55
            shadowBlur: 0.65
        }
    }

    /* ── Clock Display ──────────────────────────────────────────────────── */
    Column {
        id: clockCol
        anchors.right: parent.right
        anchors.bottom: parent.bottom
        spacing: 2

        // Time Readout
        Text {
            id: timeText
            anchors.right: parent.right
            text: root.timeStr
            font.family: "Google Sans Flex"
            font.pixelSize: 68
            font.weight: Font.Bold
            color: "#FFFFFF"

            layer.enabled: true
            layer.effect: shadowFx
        }

        // Day and Date Row
        Row {
            anchors.right: parent.right
            spacing: 12

            // Day of the week in cursive Caveat
            Text {
                id: dayText
                anchors.verticalCenter: parent.verticalCenter
                text: root.dayStr
                font.family: "Caveat"
                font.pixelSize: 34
                font.weight: Font.Bold
                color: Theme.accentLit

                layer.enabled: true
                layer.effect: shadowFx
            }

            // Sleek Divider
            Rectangle {
                width: 1.5
                height: 20
                anchors.verticalCenter: parent.verticalCenter
                color: Qt.rgba(1, 1, 1, 0.25)
            }

            // Date string
            Text {
                id: dateText
                anchors.verticalCenter: parent.verticalCenter
                text: root.dateStr
                font.family: "Google Sans Flex"
                font.pixelSize: 16
                font.weight: Font.Medium
                color: "#CBD5E1"

                layer.enabled: true
                layer.effect: shadowFx
            }
        }
    }
}
