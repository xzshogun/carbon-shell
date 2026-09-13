import QtQuick
import QtQuick.Layouts
import QtQuick.Effects
import Quickshell
import Quickshell.Io
import "../components"
import "../Singletons"

/**
 * Dedicated display brightness popup card:
 *   - Sun glyph with live brightness percentage
 *   - Interactive smooth wavy level slider
 *   - Backed by brightnessctl (hardware backlight)
 */
Item {
    id: root

    property bool open: false
    property string barEdge: "top"
    property bool anyHover: false

    signal closeRequested()

    implicitWidth: 260
    implicitHeight: 72

    /* ============ Display brightness (via brightnessctl) ============ */
    property real brightRatio: 0
    property real brightMax: 1
    property real lastBrightWrite: 0

    Process {
        id: brightProbe
        command: ["sh", "-c", 'echo "a b c $(brightnessctl --class backlight get) $(brightnessctl --class backlight max)"']
        stdout: SplitParser {
            onRead: data => {
                const tokens = data.trim().split(/\s+/)
                if (tokens.length < 2) return
                const cur = parseFloat(tokens[tokens.length - 2])
                const mx = parseFloat(tokens[tokens.length - 1])
                if (isNaN(cur) || isNaN(mx) || mx <= 0) return
                root.brightMax = mx
                root.brightRatio = cur / mx
            }
        }
    }

    function refreshBrightness() {
        if (!brightProbe.running) brightProbe.running = true
    }

    function setBrightness(v) {
        root.brightRatio = v
        root.lastBrightWrite = Date.now()
        Quickshell.execDetached(["brightnessctl", "--class", "backlight", "s",
            String(Math.round(v * root.brightMax)), "--quiet"])
    }

    Timer {
        interval: 3000
        repeat: true
        running: root.open
        onTriggered: {
            if (Date.now() - root.lastBrightWrite > 1500)
                root.refreshBrightness()
        }
    }

    onOpenChanged: {
        if (root.open) root.refreshBrightness()
    }

    Rectangle {
        id: card
        width: parent.width
        height: parent.height
        radius: 16
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

        ColumnLayout {
            anchors.fill: parent
            anchors.margins: 12
            spacing: 6

            RowLayout {
                Layout.fillWidth: true
                spacing: 8
                opacity: root.open ? 1.0 : 0.0
                transform: Translate {
                    y: root.open ? 0 : 6
                    Behavior on y { NumberAnimation { duration: 250; easing.type: Easing.OutBack } }
                }
                Behavior on opacity { NumberAnimation { duration: 200 } }

                Text {
                    text: "\uf185"
                    font.family: Theme.font
                    font.pixelSize: 14
                    color: Theme.accentLit
                }

                Text {
                    text: "Brightness"
                    font.family: "Valley Sans"
                    font.pixelSize: 13
                    font.weight: Font.Bold
                    color: Theme.fg
                }

                Item { Layout.fillWidth: true }

                Text {
                    text: Math.round(root.brightRatio * 100) + "%"
                    font.family: "Valley Sans"
                    font.pixelSize: 13
                    font.weight: Font.DemiBold
                    color: Theme.fgDim
                }
            }

            VolSlider {
                Layout.fillWidth: true
                interactive: true
                active: root.open
                value: root.brightRatio
                fill: Theme.accent
                track: Theme.fgFaint
                knob: Theme.fg
                onChanged: (v) => root.setBrightness(v)
            }
        }
    }

    HoverHandler {
        id: hover
        onHoveredChanged: {
            root.anyHover = hover.hovered
        }
    }
}
