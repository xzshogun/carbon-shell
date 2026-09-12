import QtQuick

/**
 * Carbon volume/level slider in "wavy line" style:
 *   · the filled portion (0..value) is a smooth, continuously-rippling sine
 *     wave whose amplitude & frequency grow with the value (silent/lower =
 *     flatter line, louder/higher = bigger swell),
 *   · the remainder is a faint static track line,
 *   · a thin drag handle marks the current value.
 * `changed(value)` fires live while dragging so the caller can push the value
 * straight into the sink clamp.
 */
Item {
    id: root

    property real value: 0
    property real minValue: 0
    property real maxValue: 1
    property color fill: "#EDFF33"
    property color track: "#40FFFFFF"
    property color knob: "#F6F4F4"
    property bool interactive: true
    property real handleWidth: 4
    property real handleHeight: 18

    signal changed(real value)

    readonly property bool isPressed: area.pressed
    property real dragValue: 0
    readonly property real effectiveValue: isPressed ? dragValue : value

    /* Live-bound: recomputes as `effectiveValue` moves without breaking bindings. */
    property real ratio: (root.effectiveValue - root.minValue) / Math.max(0.0001, root.maxValue - root.minValue)

    implicitHeight: 24
    implicitWidth: 160

    /* Waviness grows with the value — Ambxst-style mapping. */
    readonly property real wavyAmp: 1.5 * root.ratio
    readonly property real wavyFreq: 8 * root.ratio

    function setFromMouse(mx) {
        var w = Math.max(1, root.width)
        var r = Math.max(0, Math.min(1, mx / w))
        var v = root.minValue + r * (root.maxValue - root.minValue)
        root.dragValue = v
        root.changed(v)
    }

    /* Remaining (unfilled) track: static faint line. */
    Rectangle {
        anchors.left: knob.right
        anchors.leftMargin: 3
        anchors.right: parent.right
        anchors.verticalCenter: parent.verticalCenter
        height: 2
        radius: 1
        color: root.track
        visible: root.ratio < 0.99
    }

    /* Filled portion: the animated wavy line, up to the handle. */
    WavyLine {
        id: waveFill
        anchors.left: parent.left
        anchors.right: knob.left
        anchors.rightMargin: 3
        anchors.verticalCenter: parent.verticalCenter
        height: 16
        visible: root.ratio > 0.004
        color: root.fill
        lineWidth: 3
        amplitudeMultiplier: root.wavyAmp
        frequency: root.wavyFreq
        fullLength: Math.max(1, root.width)
    }

    /* Drag handle marking the current level. */
    Rectangle {
        id: knob
        width: root.handleWidth
        height: root.handleHeight
        radius: root.handleWidth / 2
        anchors.verticalCenter: parent.verticalCenter
        color: root.knob
        x: Math.max(0, Math.min(parent.width - width, root.ratio * (parent.width - width)))
    }

    MouseArea {
        id: area
        anchors.fill: parent
        enabled: root.interactive
        cursorShape: Qt.PointingHandCursor
        onPressed: (m) => root.setFromMouse(m.x)
        onPositionChanged: (m) => { if (area.pressed) root.setFromMouse(m.x) }
        onWheel: (w) => {
            if (w.angleDelta.y > 0)
                root.setFromMouse(Math.min(root.width, root.width * (root.ratio + 0.05)))
            else
                root.setFromMouse(Math.max(0, root.width * (root.ratio - 0.05)))
        }
    }
}