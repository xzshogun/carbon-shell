import QtQuick
import QtQuick.Layouts
import "../Singletons"

/**
 * Carbon pomodoro / stopwatch pane.
 * Scaled down to fit comfortably inside the compact 264×296px panel.
 */
Item {
    id: root

    property string mode: "pomo"          // "pomo" | "stop"
    property bool running: false
    property bool onBreak: false
    property bool longBreak: false        // break kind: long vs short
    property int cycles: 0                // completed focus sessions

    property int workSec: 25 * 60
    property int breakSec: 5 * 60
    property int longBreakSec: 15 * 60
    property int remaining: root.workSec  // pomodoro countdown
    property int elapsed: 0               // stopwatch count-up

    implicitWidth: 264
    implicitHeight: 296

    function fmt(s) {
        const m = Math.floor(s / 60)
        const ss = s % 60
        if (m >= 60) return String(Math.floor(m / 60)).padStart(2, "0") + ":" + String(m % 60).padStart(2, "0") + ":" + String(ss).padStart(2, "0")
        return String(m).padStart(2, "0") + ":" + String(ss).padStart(2, "0")
    }

    function tick() {
        if (root.mode === "pomo") {
            root.remaining--
            if (root.remaining <= 0) {
                if (root.onBreak) {
                    root.onBreak = false
                    root.longBreak = false
                    root.remaining = root.workSec
                } else {
                    root.cycles++
                    root.longBreak = root.cycles % 4 === 0
                    root.onBreak = true
                    root.remaining = root.longBreak ? root.longBreakSec : root.breakSec
                }
            }
        } else {
            root.elapsed++
        }
    }

    function startPause() {
        root.running = !root.running
    }
    function reset() {
        root.running = false
        if (root.mode === "pomo") {
            root.onBreak = false
            root.longBreak = false
            root.remaining = root.workSec
        } else {
            root.elapsed = 0
        }
    }
    function setMode(m) {
        if (root.mode === m) return
        root.mode = m
        root.running = false
        root.reset()
    }
    function clamp(v, lo, hi) {
        return Math.max(lo, Math.min(hi, v))
    }
    function setWork(m) {
        root.workSec = clamp(m, 1, 180) * 60
        if (!root.running && !root.onBreak) root.remaining = root.workSec
    }
    function setBreak(m) {
        root.breakSec = clamp(m, 1, 60) * 60
    }
    function setLong(m) {
        root.longBreakSec = clamp(m, 5, 90) * 60
    }

    Timer {
        interval: 1000
        repeat: true
        running: root.running
        onTriggered: root.tick()
    }

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: 6
        spacing: 5

        /* Mode selector */
        Row {
            Layout.fillWidth: true
            Layout.alignment: Qt.AlignHCenter
            spacing: 6

            Rectangle {
                width: 86
                height: 24
                radius: 12
                color: root.mode === "pomo" ? Theme.accent : (pHov.hovered ? Theme.bgHover : "transparent")
                Text {
                    anchors.centerIn: parent
                    text: "Pomodoro"
                    font.family: "Valley Sans"
                    font.pixelSize: 11
                    font.weight: Font.Bold
                    color: root.mode === "pomo" ? "#0e0e12" : Theme.fgDim
                }
                MouseArea {
                    id: pHov
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: root.setMode("pomo")
                }
            }

            Rectangle {
                width: 86
                height: 24
                radius: 12
                color: root.mode === "stop" ? Theme.accent : (sHov.hovered ? Theme.bgHover : "transparent")
                Text {
                    anchors.centerIn: parent
                    text: "Stopwatch"
                    font.family: "Valley Sans"
                    font.pixelSize: 11
                    font.weight: Font.Bold
                    color: root.mode === "stop" ? "#0e0e12" : Theme.fgDim
                }
                MouseArea {
                    id: sHov
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: root.setMode("stop")
                }
            }
        }

        /* Status + big time */
        Text {
            Layout.fillWidth: true
            Layout.alignment: Qt.AlignHCenter
            text: {
                if (root.mode === "stop") return "STOPWATCH"
                if (root.onBreak) return root.longBreak ? "LONG BREAK" : "SHORT BREAK"
                return root.cycles === 0 ? "FOCUS" : "FOCUS " + ((root.cycles % 4) || 4)
            }
            font.family: Theme.font
            font.pixelSize: 8
            font.letterSpacing: 2
            color: root.onBreak ? Theme.accentLit : Theme.fgFaint
            horizontalAlignment: Text.AlignHCenter
        }

        Text {
            Layout.fillWidth: true
            Layout.alignment: Qt.AlignHCenter
            text: root.mode === "pomo" ? root.fmt(root.remaining) : root.fmt(root.elapsed)
            font.family: "Valley Sans"
            font.pixelSize: 32
            font.weight: Font.Bold
            color: root.running ? Theme.accentLit : Theme.fg
            horizontalAlignment: Text.AlignHCenter
        }

        /* Session dots + counter (pomodoro only) */
        Column {
            Layout.fillWidth: true
            Layout.alignment: Qt.AlignHCenter
            spacing: 2
            visible: root.mode === "pomo"

            Row {
                anchors.horizontalCenter: parent.horizontalCenter
                spacing: 5
                Repeater {
                    model: 4
                    delegate: Rectangle {
                        required property int index
                        width: 6
                        height: 6
                        radius: 3
                        color: index < (root.cycles % 4) ? Theme.accent : Theme.fgFaint
                    }
                }
            }

            Text {
                anchors.horizontalCenter: parent.horizontalCenter
                text: "session " + ((root.cycles % 4) || 4) + " of 4"
                font.family: "Valley Sans"
                font.pixelSize: 9
                color: Theme.fgFaint
            }
        }

        Rectangle {
            Layout.fillWidth: true
            height: 1
            color: Theme.outline
            visible: root.mode === "pomo"
        }

        /* Break-length configuration */
        Row {
            Layout.fillWidth: true
            Layout.alignment: Qt.AlignHCenter
            spacing: 4
            visible: root.mode === "pomo"

            Stepper {
                label: "FOCUS"
                minutes: Math.round(root.workSec / 60)
                disabled: root.running
                onChanged: root.setWork(root.workSec / 60 + delta)
            }
            Stepper {
                label: "SHORT"
                minutes: Math.round(root.breakSec / 60)
                disabled: root.running
                onChanged: root.setBreak(root.breakSec / 60 + delta)
            }
            Stepper {
                label: "LONG"
                minutes: Math.round(root.longBreakSec / 60)
                disabled: root.running
                onChanged: root.setLong(root.longBreakSec / 60 + delta)
            }
        }

        /* Controls */
        Row {
            Layout.fillWidth: true
            Layout.alignment: Qt.AlignHCenter
            spacing: 8

            Rectangle {
                width: 80
                height: 28
                radius: 14
                color: rHov.hovered ? Theme.bgHover : "transparent"
                border.width: 1
                border.color: Theme.outline
                Text {
                    anchors.centerIn: parent
                    text: "RESET"
                    font.family: "Valley Sans"
                    font.pixelSize: 11
                    font.weight: Font.Bold
                    color: Theme.fgDim
                }
                MouseArea {
                    id: rHov
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: root.reset()
                }
            }

            Rectangle {
                width: 100
                height: 28
                radius: 14
                color: root.running ? Theme.bgHover : Theme.accent
                Text {
                    anchors.centerIn: parent
                    text: root.running ? "PAUSE" : "START"
                    font.family: "Valley Sans"
                    font.pixelSize: 11
                    font.weight: Font.Bold
                    color: root.running ? Theme.fg : "#0e0e12"
                }
                MouseArea {
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: root.startPause()
                }
            }
        }
    }
}